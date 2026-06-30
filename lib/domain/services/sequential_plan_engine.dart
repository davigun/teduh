import '../../core/time/calendar_date.dart';
import '../entities/bible.dart';
import '../entities/plan.dart';

/// Pure, deterministic sequential reading-plan engine.
///
/// The chapter spine is built from CANONICAL chapter counts and is
/// availability-agnostic, so a future TSI Old-Testament release never shifts an
/// existing plan's day→passage map. `today` is always passed in (never
/// `DateTime.now()`), so the engine is fully testable.
class SequentialPlanEngine {
  const SequentialPlanEngine();

  /// The ordered list of every chapter from [start] through [end], inclusive,
  /// walking books in canonical [books] order. [books] need not be available.
  List<BibleRef> chapterUniverse(
    List<BibleBook> books,
    BibleRef start,
    BibleRef end,
  ) {
    final ordered = [...books]..sort((a, b) => a.order.compareTo(b.order));
    final startOrder = _orderOf(ordered, start.bookCode);
    final endOrder = _orderOf(ordered, end.bookCode);
    if (startOrder == null || endOrder == null) return const [];

    final refs = <BibleRef>[];
    for (final book in ordered) {
      if (book.order < startOrder || book.order > endOrder) continue;
      final from = book.order == startOrder ? start.chapter : 1;
      final to = book.order == endOrder ? end.chapter : book.chapterCount;
      for (var ch = from; ch <= to && ch <= book.chapterCount; ch++) {
        refs.add(BibleRef(book.code, ch));
      }
    }
    return refs;
  }

  /// Total days the plan spans for a given universe size and pace.
  int totalDays(int universeLength, int chaptersPerDay) =>
      chaptersPerDay <= 0 ? 0 : (universeLength / chaptersPerDay).ceil();

  /// Today's 0-based day index, anchored to the plan's start date.
  int dayIndexFor(CalendarDate startDate, CalendarDate today) {
    final diff = startDate.daysUntil(today);
    return diff < 0 ? 0 : diff;
  }

  /// The chapters to read on [dayIndex] (may be empty once the plan is finished).
  DailyReading readingForDay(
    List<BibleRef> universe,
    int chaptersPerDay,
    int dayIndex,
  ) {
    final total = totalDays(universe.length, chaptersPerDay);
    final from = dayIndex * chaptersPerDay;
    final to = (from + chaptersPerDay).clamp(0, universe.length);
    return DailyReading(
      dayIndex: dayIndex,
      chapters: from >= universe.length ? const [] : universe.sublist(from, to),
      totalDays: total,
    );
  }

  /// Convenience: today's reading from a plan + canon + current date.
  DailyReading today(
    List<BibleBook> books,
    ReadingPlan plan,
    CalendarDate todayDate,
  ) {
    final universe = chapterUniverse(books, plan.start, plan.end);
    final idx = dayIndexFor(plan.startDate, todayDate);
    return readingForDay(universe, plan.chaptersPerDay, idx);
  }

  int? _orderOf(List<BibleBook> books, String code) {
    for (final b in books) {
      if (b.code == code) return b.order;
    }
    return null;
  }
}
