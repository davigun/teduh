import 'package:flutter_test/flutter_test.dart';
import 'package:teduh/core/time/calendar_date.dart';
import 'package:teduh/domain/services/streak_calculator.dart';

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
}
