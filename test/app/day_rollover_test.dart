import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:teduh/app/day_change_refresher.dart';
import 'package:teduh/app/providers.dart';
import 'package:teduh/app/queries.dart';
import 'package:teduh/core/time/calendar_date.dart';
import 'package:teduh/core/time/clock.dart';
import 'package:teduh/data/repositories.dart';
import 'package:teduh/domain/entities/bible.dart';
import 'package:teduh/domain/entities/plan.dart';
import 'package:teduh/domain/entities/progress.dart';
import 'package:teduh/domain/repositories.dart';

/// A clock whose "now" can be advanced to simulate the wall-clock rolling over.
class _FakeClock extends SystemClock {
  _FakeClock(this.now);
  DateTime now;
  @override
  DateTime nowLocal() => now;
  @override
  DateTime nowUtc() => now.toUtc();
}

class _FakePlan implements PlanRepository {
  _FakePlan(this._plan);
  final ReadingPlan _plan;
  @override
  Future<ReadingPlan?> activePlan() async => _plan;
  @override
  Future<void> save(ReadingPlan plan) async {}
}

class _FakeProgress implements ProgressRepository {
  _FakeProgress(this.completedIndex);
  final int completedIndex; // the single day index that reads as done
  @override
  Future<Set<CalendarDate>> completedDates() async => {};
  @override
  Future<bool> isDayCompleted(String planId, int dayIndex) async =>
      dayIndex == completedIndex;
  @override
  Future<void> markRead(DayCompletion c) async {}
}

ReadingPlan _planFrom(CalendarDate startDate) => ReadingPlan(
      id: 'p',
      start: const BibleRef('MAT', 1),
      end: const BibleRef('REV', 22),
      chaptersPerDay: 1,
      startDate: startDate,
      updatedAt: DateTime.utc(2026, 6, 1),
    );

void main() {
  // Fix #3 — the "already read today" query must be scoped to the active plan.
  group('isDayCompleted is scoped to the active plan (fix #3)', () {
    late Database db;
    setUp(() {
      db = sqlite3.openInMemory();
      db.execute(
          'CREATE TABLE reading_progress(id TEXT PRIMARY KEY, plan_id TEXT, day_index INTEGER)');
      db.execute(
          "INSERT INTO reading_progress(id, plan_id, day_index) VALUES('r1','oldPlan',0)");
    });
    tearDown(() => db.dispose());

    test('a day 0 completed under a previous plan does not mark a new plan done',
        () async {
      final repo = SqliteProgressRepository(db);
      expect(await repo.isDayCompleted('oldPlan', 0), isTrue);
      expect(await repo.isDayCompleted('newPlan', 0), isFalse);
    });
  });

  // Fix #1 — the core mechanism the observer relies on: once the date-derived
  // providers are invalidated, they recompute against the advanced clock. This
  // is deterministic (no lifecycle plumbing) and would have failed if "today"
  // were frozen inside the provider cache.
  group('date rollover clears "already read today" (fix #1)', () {
    test('providers recompute for the new day after invalidation', () async {
      final clock = _FakeClock(DateTime(2026, 6, 29, 21));
      final container = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(clock),
        // startDate day 1 → idx 28 on the 29th, 29 on the 30th.
        planRepositoryProvider.overrideWithValue(_FakePlan(
            _planFrom(const CalendarDate(2026, 6, 1)))),
        progressRepositoryProvider.overrideWithValue(_FakeProgress(28)),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(isTodayDoneProvider.future), isTrue);

      // Midnight passes.
      clock.now = DateTime(2026, 6, 30, 7);
      container.invalidate(todayDayIndexProvider);
      container.invalidate(isTodayDoneProvider);

      expect(await container.read(isTodayDoneProvider.future), isFalse);
    });

    testWidgets('DayChangeRefresher flips isTodayDone false on resume next day',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 6, 29, 21));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(clock),
            planRepositoryProvider.overrideWithValue(
                _FakePlan(_planFrom(const CalendarDate(2026, 6, 1)))),
            progressRepositoryProvider.overrideWithValue(_FakeProgress(28)),
          ],
          child: MaterialApp(
            home: DayChangeRefresher(
              child: Consumer(builder: (context, ref, _) {
                final done = ref.watch(isTodayDoneProvider).value;
                return Text(done == true ? 'DONE' : 'NOT_DONE',
                    textDirection: TextDirection.ltr);
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DONE'), findsOneWidget);

      // Advance past midnight, then simulate the app coming back to foreground.
      clock.now = DateTime(2026, 6, 30, 7);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('NOT_DONE'), findsOneWidget);
    });
  });
}
