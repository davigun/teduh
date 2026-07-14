import 'package:flutter_test/flutter_test.dart';
import 'package:koinonia/core/time/calendar_date.dart';
import 'package:koinonia/domain/services/streak_calculator.dart';

void main() {
  const calc = StreakCalculator();
  const today = CalendarDate(2026, 6, 29);

  CalendarDate d(int day) => CalendarDate(2026, 6, day);

  test('empty → no streak', () {
    final s = calc.compute({}, today);
    expect(s.current, 0);
    expect(s.isActive, isFalse);
  });

  test('consecutive days ending today → active run', () {
    final s = calc.compute({d(27), d(28), d(29)}, today);
    expect(s.current, 3);
    expect(s.isActive, isTrue);
    expect(s.longest, 3);
  });

  test('last read yesterday still counts (gentle)', () {
    final s = calc.compute({d(27), d(28)}, today);
    expect(s.isActive, isTrue);
    expect(s.current, 2);
  });

  test('a full missed day breaks the active streak', () {
    final s = calc.compute({d(26), d(27)}, today); // 27 is 2 days ago
    expect(s.isActive, isFalse);
    expect(s.current, 0);
    expect(s.longest, 2); // history still reflected
  });

  test('longest run is found across gaps', () {
    final s = calc.compute({d(20), d(21), d(22), d(28), d(29)}, today);
    expect(s.longest, 3);
    expect(s.current, 2); // 28,29 ending today
    expect(s.isActive, isTrue);
  });

  test('duplicate dates do not inflate the run', () {
    final s = calc.compute({d(28), d(29)}, today);
    expect(s.current, 2);
  });

  // Day-change contract: with the SAME history, the streak must move correctly
  // as "today" advances. This is the domain oracle for the provider-level
  // rollover bug — if a cached "today" froze, current would be wrong here.
  group('same history across an advancing today', () {
    final dates = {d(27), d(28), d(29)};

    test('read through today → full active run', () {
      final s = calc.compute(dates, d(29));
      expect(s.isActive, isTrue);
      expect(s.current, 3);
      expect(s.longest, 3);
    });

    test('rolling to an unread tomorrow keeps the run (grace, no inflate)', () {
      final s = calc.compute(dates, d(30));
      expect(s.isActive, isTrue);
      expect(s.current, 3); // yesterday-grace: not 4, not 0
      expect(s.longest, 3);
    });

    test('a second unread day breaks the active run', () {
      final s = calc.compute(dates, d(31));
      expect(s.isActive, isFalse);
      expect(s.current, 0);
      expect(s.longest, 3); // history preserved
    });
  });

  test('a completion dated in the future keeps the streak inactive (current behaviour)', () {
    // Backward local-date shift (west across the date line): newest completion
    // is "tomorrow" relative to today. Pinned so any future change is deliberate.
    final s = calc.compute({d(28), d(29), d(30)}, today); // today = 29
    expect(s.isActive, isFalse);
    expect(s.current, 0);
    expect(s.longest, 3);
  });
}
