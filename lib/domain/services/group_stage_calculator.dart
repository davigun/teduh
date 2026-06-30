import '../entities/group.dart';

/// Pure, deterministic "where is this member in the shared plan" math.
///
/// Everything is computed from a member's set of completed day indices plus the
/// group's `scheduledDayIndex` (today's deterministic day index, the same for
/// all members). No server-side passage or timezone math: the whole
/// ahead/behind problem is integer comparison. See `docs/P3_SUPABASE.md` §1.
class GroupStageCalculator {
  const GroupStageCalculator();

  /// The contiguous high-water day index: the latest day with *no gaps behind
  /// it* (max consecutive completed counting from day 0). `-1` when day 0 is not
  /// yet done. `highWater + 1` is exactly the next day to read. Ungameable: a
  /// member who jumps ahead leaving a gap does not advance their stage.
  int highWater(Set<int> completedDays) {
    var hw = -1;
    while (completedDays.contains(hw + 1)) {
      hw++;
    }
    return hw;
  }

  /// "Tertinggal N hari": fully-elapsed days that are still unread. Today's own
  /// day is excluded (not-read-yet today is a gentle separate state, not
  /// "behind"), which also absorbs a 1-day zone skew the same way the streak's
  /// yesterday-grace does. Never negative.
  int behind(Set<int> completedDays, int scheduledDayIndex) {
    final hw = highWater(completedDays);
    final overdue = scheduledDayIndex - 1 - hw;
    return overdue < 0 ? 0 : overdue;
  }

  MemberStage stageFor(
    GroupMember member,
    Set<int> completedDays,
    int scheduledDayIndex, {
    required bool isMe,
  }) {
    final hw = highWater(completedDays);
    final overdue = scheduledDayIndex - 1 - hw;
    return MemberStage(
      member: member,
      highWater: hw,
      behind: overdue < 0 ? 0 : overdue,
      readToday: completedDays.contains(scheduledDayIndex),
      isMe: isMe,
    );
  }
}
