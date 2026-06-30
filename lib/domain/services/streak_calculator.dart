import '../../core/time/calendar_date.dart';
import '../entities/progress.dart';

/// Pure streak logic over the global set of distinct completion dates (across
/// all plans, so switching plans never resets the streak).
///
/// MVP rule (gentle, never nagging): the current run counts consecutive
/// calendar days and stays "active" as long as the most recent completion is
/// today or yesterday — you have until the end of the next day before it breaks.
/// `graceDays` (extra forgiven gap) defaults to 0 and is a future one-line tweak.
class StreakCalculator {
  const StreakCalculator({this.graceDays = 0});

  final int graceDays;

  Streak compute(Set<CalendarDate> dates, CalendarDate today) {
    if (dates.isEmpty) return const Streak.empty();

    final sorted = dates.toList()..sort();
    final longest = _longestRun(sorted);

    final last = sorted.last;
    final gapFromToday = last.daysUntil(today); // >=0 if last is today/past
    final isActive = gapFromToday >= 0 && gapFromToday <= 1 + graceDays;

    var current = 0;
    if (isActive) {
      current = 1;
      for (var i = sorted.length - 1; i > 0; i--) {
        final gap = sorted[i - 1].daysUntil(sorted[i]);
        if (gap >= 1 && gap <= 1 + graceDays) {
          current++;
        } else {
          break;
        }
      }
    }

    return Streak(
      current: current,
      longest: longest,
      isActive: isActive,
      lastReadDate: last,
    );
  }

  int _longestRun(List<CalendarDate> sorted) {
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i - 1].daysUntil(sorted[i]);
      if (gap == 0) continue; // duplicate
      if (gap >= 1 && gap <= 1 + graceDays) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }
    return longest;
  }
}
