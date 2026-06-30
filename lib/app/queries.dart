import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/time/calendar_date.dart';
import '../data/repositories.dart';
import '../domain/entities/bible.dart';
import '../domain/entities/plan.dart';
import '../domain/entities/progress.dart';
import '../domain/services/sequential_plan_engine.dart';
import '../domain/services/streak_calculator.dart';
import 'auth_controller.dart';
import 'providers.dart';

const _engine = SequentialPlanEngine();
const _streak = StreakCalculator();
const _uuid = Uuid();

/// Fixed namespace so a plan-day completion id is deterministic: re-marking the
/// same day coalesces under INSERT OR REPLACE instead of orphaning a dirty row.
const _planNamespace = '1b671a64-40d5-491e-99b0-da01ff1f3341';

CalendarDate _today(Ref ref) =>
    CalendarDate.fromLocal(ref.watch(clockProvider).nowLocal());

final booksProvider = FutureProvider<List<BibleBook>>(
    (ref) => ref.watch(bibleRepositoryProvider).books());

final chapterProvider = FutureProvider.family<Chapter, BibleRef>(
    (ref, r) => ref.watch(bibleRepositoryProvider).chapter(r));

final bookNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final books = await ref.watch(booksProvider.future);
  return {for (final b in books) b.code: b.nama};
});

/// Human label for a span of chapters, e.g. "Matius 5–7" or "Matius 28 – Markus 2".
String passageLabel(List<BibleRef> chapters, Map<String, String> names) {
  if (chapters.isEmpty) return '';
  final first = chapters.first;
  final last = chapters.last;
  final n1 = names[first.bookCode] ?? first.bookCode;
  if (first.bookCode == last.bookCode) {
    return first.chapter == last.chapter
        ? '$n1 ${first.chapter}'
        : '$n1 ${first.chapter}–${last.chapter}';
  }
  final n2 = names[last.bookCode] ?? last.bookCode;
  return '$n1 ${first.chapter} – $n2 ${last.chapter}';
}

final activePlanProvider = FutureProvider<ReadingPlan?>(
    (ref) => ref.watch(planRepositoryProvider).activePlan());

final todayDayIndexProvider = FutureProvider<int?>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return null;
  return _engine.dayIndexFor(plan.startDate, _today(ref));
});

final todaysReadingProvider = FutureProvider<DailyReading?>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return null;
  final books = await ref.watch(booksProvider.future);
  return _engine.today(books, plan, _today(ref));
});

final completedDatesProvider = FutureProvider<Set<CalendarDate>>(
    (ref) => ref.watch(progressRepositoryProvider).completedDates());

final streakProvider = FutureProvider<Streak>((ref) async {
  final dates = await ref.watch(completedDatesProvider.future);
  return _streak.compute(dates, _today(ref));
});

final isTodayDoneProvider = FutureProvider<bool>((ref) async {
  final idx = await ref.watch(todayDayIndexProvider.future);
  if (idx == null) return false;
  return ref.watch(progressRepositoryProvider).isDayCompleted(idx);
});

// ----------------------------------------------------------------- mutations

/// Persist a plan, then refresh everything derived from it.
Future<void> savePlanAction(WidgetRef ref, ReadingPlan plan) async {
  await ref.read(planRepositoryProvider).save(plan);
  ref.invalidate(activePlanProvider);
  ref.invalidate(todaysReadingProvider);
  ref.invalidate(todayDayIndexProvider);
  ref.invalidate(isTodayDoneProvider);
}

/// Mark today's reading done, then refresh streak + completion state. If the
/// active plan is a group plan and the user is signed in, the completion is
/// stamped with owner/group and pushed (fire-and-forget) for "baca bersama".
Future<void> markTodayReadAction(WidgetRef ref) async {
  final plan = await ref.read(activePlanProvider.future);
  final idx = await ref.read(todayDayIndexProvider.future);
  final reading = await ref.read(todaysReadingProvider.future);
  final clock = ref.read(clockProvider);
  final auth = ref.read(authProvider);
  final group = await ref.read(groupRepositoryProvider).activeGroup();

  final planId = plan?.id;
  final isGroupPlan = group != null && planId == group.id;
  final id = (planId != null && idx != null)
      ? _uuid.v5(_planNamespace, '$planId#$idx')
      : _uuid.v4();

  await ref.read(progressRepositoryProvider).markRead(DayCompletion(
        id: id,
        planId: planId,
        dayIndex: idx,
        passage: (reading != null && reading.chapters.isNotEmpty)
            ? reading.chapters.first
            : null,
        localDate: CalendarDate.fromLocal(clock.nowLocal()),
        completedAt: clock.nowUtc(),
        updatedAt: clock.nowUtc(),
        userId: auth.isSignedIn ? auth.userId : null,
        groupId: isGroupPlan ? group.id : null,
      ));

  ref.invalidate(completedDatesProvider);
  ref.invalidate(streakProvider);
  ref.invalidate(isTodayDoneProvider);

  // Offline-safe drain; no-op for local users, swallows network errors.
  if (isGroupPlan && auth.isSignedIn) {
    // ignore: unawaited_futures
    ref.read(syncServiceProvider).pushPending();
  }
}

/// Build a fresh sequential plan anchored at today.
ReadingPlan buildPlan(
  WidgetRef ref, {
  required BibleRef start,
  required BibleRef end,
  required int chaptersPerDay,
}) {
  final clock = ref.read(clockProvider);
  return ReadingPlan(
    id: _uuid.v4(),
    start: start,
    end: end,
    chaptersPerDay: chaptersPerDay,
    startDate: CalendarDate.fromLocal(clock.nowLocal()),
    updatedAt: clock.nowUtc(),
  );
}
