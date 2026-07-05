import '../core/time/calendar_date.dart';
import 'entities/bible.dart';
import 'entities/group.dart';
import 'entities/plan.dart';
import 'entities/progress.dart';

/// Read-only Scripture access (the bundled bible.db).
abstract interface class BibleRepository {
  Future<List<BibleBook>> books();
  Future<Chapter> chapter(BibleRef ref); // throws ChapterUnavailable if not released
}

/// The (single) active reading plan, stored locally.
abstract interface class PlanRepository {
  Future<ReadingPlan?> activePlan();
  Future<void> save(ReadingPlan plan);
}

/// Local reading progress.
abstract interface class ProgressRepository {
  Future<Set<CalendarDate>> completedDates();
  Future<bool> isDayCompleted(String planId, int dayIndex);
  Future<void> markRead(DayCompletion completion);
}

/// Local mirror of the active "Baca bersama" group: what the group screen reads
/// from. Populated by [SyncService.pull]; never blocks reading.
abstract interface class GroupRepository {
  Future<Group?> activeGroup();
  Future<List<GroupMember>> members(String groupId);
  Future<Set<int>> memberDayIndices(String groupId, String userId);

  /// Adopt [group] as the active group + its plan locally (on create / join).
  Future<void> upsertActiveGroup(Group group);
  Future<void> replaceMembers(String groupId, List<GroupMember> members);

  /// Replace the whole per-member day-index mirror for [groupId].
  Future<void> replaceMemberProgress(String groupId, Map<String, Set<int>> byUser);

  /// Leave the active group locally (keeps personal reading history).
  Future<void> leaveActiveGroup();

  /// Sign-out: wipe the account-scoped social mirror (groups stay server-side).
  Future<void> clearSocialMirror();
}

/// Remote group operations. Only the SECURITY DEFINER RPCs are write paths.
/// `null` when Supabase isn't configured / the user is signed out.
abstract interface class GroupService {
  Future<Group> create({
    required String name,
    required BibleRef start,
    required BibleRef end,
    required int chaptersPerDay,
    required CalendarDate startDate,
  });
  Future<Group> joinByCode(String code);
  Future<void> leave(String groupId);
}

/// The "read together" seam. [LocalSyncService] is a no-op (offline / signed
/// out); [SupabaseSyncService] drives account-scoped progress sync. Reading
/// never depends on any of this — see `docs/P3_SUPABASE.md` §4.
abstract interface class SyncService {
  /// Fire-and-forget: drain locally-dirty plan-day rows to the server (LWW).
  Future<void> pushPending();

  /// Pull the active group's members + everyone's progress into the mirror.
  Future<void> pull();

  /// First sign-in: enqueue all pre-account plan-day history, then push.
  Future<void> onSignedIn(String uid);

  /// Sign-out: clear the social mirror (local reading data is untouched).
  Future<void> onSignedOut();

  /// P3c: subscribe to the active group's live progress + membership. Each live
  /// change rewrites the local mirror and bumps the mirror revision so the UI
  /// refreshes. Idempotent: re-activating the same group is a no-op.
  Future<void> activateGroup(String groupId);

  /// Stop live subscriptions (group left, signed out, or no active group).
  Future<void> deactivateGroup();
}
