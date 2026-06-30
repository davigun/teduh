import 'package:meta/meta.dart';

import '../../core/time/calendar_date.dart';
import 'bible.dart';

/// One day's reading marked done. Carries uuid + updatedAt now so future
/// Firebase sync is a data add (last-write-wins), not a rearchitect.
@immutable
class DayCompletion {
  const DayCompletion({
    required this.id,
    required this.localDate,
    required this.completedAt,
    required this.updatedAt,
    this.planId,
    this.dayIndex,
    this.passage,
    this.userId,
    this.groupId,
  });

  final String id; // deterministic uuid v5 for plan days; v4 for free reading
  final String? planId; // null = free reading
  final int? dayIndex;
  final BibleRef? passage;
  final CalendarDate localDate; // device-local date at mark time
  final DateTime completedAt; // UTC instant
  final DateTime updatedAt; // UTC
  final String? userId; // owner when signed in (drives the sync upsert)
  final String? groupId; // set when this plan is a group plan
}

@immutable
class Streak {
  const Streak({
    required this.current,
    required this.longest,
    required this.isActive,
    this.lastReadDate,
  });

  const Streak.empty()
      : current = 0,
        longest = 0,
        isActive = false,
        lastReadDate = null;

  final int current;
  final int longest;
  final bool isActive;
  final CalendarDate? lastReadDate;
}
