import 'package:meta/meta.dart';

/// A date with no time-of-day and no zone: the unit the reading plan and streak
/// reason about. All day arithmetic is done against UTC midnight so a wall-clock
/// "day" is always exactly 24h (no DST 23h/25h drift).
@immutable
class CalendarDate implements Comparable<CalendarDate> {
  final int year;
  final int month;
  final int day;

  const CalendarDate(this.year, this.month, this.day);

  /// Build from a [DateTime] by reading its *local* calendar fields.
  factory CalendarDate.fromLocal(DateTime dt) {
    final local = dt.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  factory CalendarDate.parse(String iso) {
    final p = iso.split('-');
    return CalendarDate(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  /// Whole days from this date until [other] (negative if [other] is earlier).
  int daysUntil(CalendarDate other) =>
      other._utcMidnight.difference(_utcMidnight).inDays;

  CalendarDate addDays(int days) {
    final d = _utcMidnight.add(Duration(days: days));
    return CalendarDate(d.year, d.month, d.day);
  }

  /// `YYYY-MM-DD` — the storage form. Round-trips as a pure date, never an instant.
  String toIso() => '${year.toString().padLeft(4, '0')}'
      '-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDate other) => daysUntil(other) == 0
      ? 0
      : (_utcMidnight.isBefore(other._utcMidnight) ? -1 : 1);

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
