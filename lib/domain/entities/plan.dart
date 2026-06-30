import 'package:meta/meta.dart';

import '../../core/time/calendar_date.dart';
import 'bible.dart';

/// A simple sequential reading plan: read [chaptersPerDay] chapters a day,
/// from [start] through [end], anchored at [startDate] so the day index is
/// deterministic and future-syncable.
@immutable
class ReadingPlan {
  const ReadingPlan({
    required this.id,
    required this.start,
    required this.end,
    required this.chaptersPerDay,
    required this.startDate,
    required this.updatedAt,
  });

  final String id; // uuid
  final BibleRef start;
  final BibleRef end;
  final int chaptersPerDay;
  final CalendarDate startDate;
  final DateTime updatedAt; // UTC
}

/// The chapters scheduled for one day of a plan. Computed, never stored.
@immutable
class DailyReading {
  const DailyReading({
    required this.dayIndex,
    required this.chapters,
    required this.totalDays,
  });

  final int dayIndex; // 0-based
  final List<BibleRef> chapters;
  final int totalDays;

  bool get isComplete => dayIndex >= totalDays;
}
