import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/calendar_date.dart';
import 'group_providers.dart';
import 'providers.dart';
import 'queries.dart';

/// Keeps "today" honest across a date rollover.
///
/// Every date-derived provider snapshots the local date exactly once
/// ([clockProvider] never re-emits, and none of them are autoDispose). Without
/// this, a process that survives midnight — resumed the next morning, or left
/// foreground across midnight — keeps showing yesterday's reading and a false
/// "sudah selesai hari ini", so the user thinks today is done, skips, and the
/// streak silently breaks. On resume and at each local midnight we compare the
/// current calendar date to the last seen one and, if it changed, invalidate the
/// date-derived set so it recomputes for the real today.
class DayChangeRefresher extends ConsumerStatefulWidget {
  const DayChangeRefresher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DayChangeRefresher> createState() => _DayChangeRefresherState();
}

class _DayChangeRefresherState extends ConsumerState<DayChangeRefresher>
    with WidgetsBindingObserver {
  late CalendarDate _lastDate;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _lastDate = _now();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfDateChanged();
  }

  CalendarDate _now() =>
      CalendarDate.fromLocal(ref.read(clockProvider).nowLocal());

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider).nowLocal();
    // Next local midnight + 1s cushion so the date has definitely rolled when we
    // fire. `day + 1` lets DateTime normalise month/year (and is DST-correct).
    final next = DateTime(now.year, now.month, now.day + 1)
        .add(const Duration(seconds: 1));
    _midnightTimer = Timer(next.difference(now), () {
      _refreshIfDateChanged();
      _scheduleMidnight();
    });
  }

  void _refreshIfDateChanged() {
    final today = _now();
    if (today == _lastDate) return;
    _lastDate = today;
    ref.invalidate(todayDayIndexProvider);
    ref.invalidate(todaysReadingProvider);
    ref.invalidate(isTodayDoneProvider);
    ref.invalidate(streakProvider);
    ref.invalidate(groupScheduledDayProvider);
    ref.invalidate(groupStagesProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
