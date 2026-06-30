import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/calendar_date.dart';
import '../data/repositories.dart';
import '../domain/entities/bible.dart';
import '../domain/entities/group.dart';
import '../domain/entities/plan.dart';
import '../domain/services/group_stage_calculator.dart';
import '../domain/services/sequential_plan_engine.dart';
import 'auth_controller.dart';
import 'providers.dart';
import 'queries.dart';

const _engine = SequentialPlanEngine();
const _stage = GroupStageCalculator();

CalendarDate _today(Ref ref) =>
    CalendarDate.fromLocal(ref.watch(clockProvider).nowLocal());

/// The active group, from the local mirror (works offline once joined).
final activeGroupProvider = FutureProvider<Group?>(
    (ref) => ref.watch(groupRepositoryProvider).activeGroup());

/// Today's deterministic day index for the active group's shared plan.
final groupScheduledDayProvider = FutureProvider<int?>((ref) async {
  final g = await ref.watch(activeGroupProvider.future);
  if (g == null) return null;
  return _engine.dayIndexFor(g.startDate, _today(ref));
});

/// Each member's computed position in the shared plan, leader first. Built
/// entirely on-device from the local mirror.
final groupStagesProvider = FutureProvider<List<MemberStage>>((ref) async {
  ref.watch(groupMirrorRevisionProvider); // recompute on each live mirror apply
  final g = await ref.watch(activeGroupProvider.future);
  if (g == null) return const [];
  final scheduled = _engine.dayIndexFor(g.startDate, _today(ref));
  final repo = ref.watch(groupRepositoryProvider);
  final myId = ref.watch(authProvider).userId;

  final members = await repo.members(g.id);
  final stages = <MemberStage>[];
  for (final m in members) {
    final days = await repo.memberDayIndices(g.id, m.userId);
    stages.add(_stage.stageFor(m, days, scheduled, isMe: m.userId == myId));
  }
  stages.sort((a, b) {
    if (a.highWater != b.highWater) return b.highWater.compareTo(a.highWater);
    return a.member.displayName.compareTo(b.member.displayName);
  });
  return stages;
});

// ----------------------------------------------------------------- mutations

void _invalidateGroup(WidgetRef ref) {
  ref.invalidate(activeGroupProvider);
  ref.invalidate(groupScheduledDayProvider);
  ref.invalidate(groupStagesProvider);
}

void _invalidatePlan(WidgetRef ref) {
  ref.invalidate(activePlanProvider);
  ref.invalidate(todaysReadingProvider);
  ref.invalidate(todayDayIndexProvider);
  ref.invalidate(isTodayDoneProvider);
}

/// Create a group on the server, adopt its plan locally, then pull the mirror.
Future<Group> createGroupAction(
  WidgetRef ref, {
  required String name,
  required BibleRef start,
  required BibleRef end,
  required int chaptersPerDay,
}) async {
  final svc = ref.read(groupServiceProvider);
  if (svc == null) throw StateError('Akun belum aktif.');
  final group = await svc.create(
    name: name,
    start: start,
    end: end,
    chaptersPerDay: chaptersPerDay,
    // default startDate=today so nobody joins "behind"
    startDate: CalendarDate.fromLocal(ref.read(clockProvider).nowLocal()),
  );
  await _adopt(ref, group);
  return group;
}

/// Join by code, adopt the group's shared plan locally, then pull the mirror.
Future<Group> joinGroupAction(WidgetRef ref, String code) async {
  final svc = ref.read(groupServiceProvider);
  if (svc == null) throw StateError('Akun belum aktif.');
  final group = await svc.joinByCode(code);
  await _adopt(ref, group);
  return group;
}

Future<void> _adopt(WidgetRef ref, Group group) async {
  await ref.read(groupRepositoryProvider).upsertActiveGroup(group);
  // Adopt the shared plan locally: plan.id == group.id aligns every member's
  // day-N rows under one key (the only way group stage aggregates).
  await ref.read(planRepositoryProvider).save(ReadingPlan(
        id: group.id,
        start: group.start,
        end: group.end,
        chaptersPerDay: group.chaptersPerDay,
        startDate: group.startDate,
        updatedAt: ref.read(clockProvider).nowUtc(),
      ));
  _invalidatePlan(ref);
  _invalidateGroup(ref);
  await refreshGroupAction(ref);
  // Go live so members' progress streams in without manual refresh.
  await ref.read(syncServiceProvider).activateGroup(group.id);
}

/// Pull-to-refresh: drain pending writes, then re-pull the group mirror.
Future<void> refreshGroupAction(WidgetRef ref) async {
  final sync = ref.read(syncServiceProvider);
  await sync.pushPending();
  await sync.pull();
  _invalidateGroup(ref);
}

/// Leave the active group (server + local). Personal reading history is kept.
Future<void> leaveGroupAction(WidgetRef ref) async {
  final group = await ref.read(groupRepositoryProvider).activeGroup();
  if (group == null) return;
  await ref.read(syncServiceProvider).deactivateGroup();
  await ref.read(groupServiceProvider)?.leave(group.id);
  await ref.read(groupRepositoryProvider).leaveActiveGroup();
  _invalidatePlan(ref);
  _invalidateGroup(ref);
}
