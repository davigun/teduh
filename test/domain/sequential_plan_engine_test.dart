import 'package:flutter_test/flutter_test.dart';
import 'package:teduh/core/time/calendar_date.dart';
import 'package:teduh/domain/entities/bible.dart';
import 'package:teduh/domain/entities/plan.dart';
import 'package:teduh/domain/services/sequential_plan_engine.dart';

void main() {
  const engine = SequentialPlanEngine();

  // MAT(3) + MRK(2, UNAVAILABLE) + LUK(2). The unavailable book stays in the
  // spine — index math must be availability-agnostic.
  const books = [
    BibleBook(code: 'MAT', order: 40, nama: 'Matius', testament: Testament.nt, chapterCount: 3, isAvailable: true),
    BibleBook(code: 'MRK', order: 41, nama: 'Markus', testament: Testament.nt, chapterCount: 2, isAvailable: false),
    BibleBook(code: 'LUK', order: 42, nama: 'Lukas', testament: Testament.nt, chapterCount: 2, isAvailable: true),
  ];

  group('chapterUniverse', () {
    test('walks all chapters start..end, availability-agnostic', () {
      final u = engine.chapterUniverse(books, const BibleRef('MAT', 1), const BibleRef('LUK', 2));
      expect(u.map((r) => r.toString()).toList(), [
        'MAT 1', 'MAT 2', 'MAT 3', 'MRK 1', 'MRK 2', 'LUK 1', 'LUK 2',
      ]);
    });

    test('respects partial start/end chapters', () {
      final u = engine.chapterUniverse(books, const BibleRef('MAT', 2), const BibleRef('MRK', 1));
      expect(u.map((r) => r.toString()).toList(), ['MAT 2', 'MAT 3', 'MRK 1']);
    });
  });

  group('day index + reading', () {
    test('dayIndexFor counts days from start (deterministic)', () {
      expect(
        engine.dayIndexFor(const CalendarDate(2026, 1, 1), const CalendarDate(2026, 1, 4)),
        3,
      );
      // Before start clamps to 0.
      expect(
        engine.dayIndexFor(const CalendarDate(2026, 1, 5), const CalendarDate(2026, 1, 1)),
        0,
      );
    });

    test('totalDays = ceil(chapters / pace)', () {
      expect(engine.totalDays(7, 2), 4);
      expect(engine.totalDays(6, 3), 2);
    });

    test('readingForDay slices the universe by pace', () {
      final u = engine.chapterUniverse(books, const BibleRef('MAT', 1), const BibleRef('LUK', 2));
      expect(engine.readingForDay(u, 2, 0).chapters.map((r) => '$r'), ['MAT 1', 'MAT 2']);
      expect(engine.readingForDay(u, 2, 1).chapters.map((r) => '$r'), ['MAT 3', 'MRK 1']);
      expect(engine.readingForDay(u, 2, 3).chapters.map((r) => '$r'), ['LUK 2']);
    });

    test('past the end yields an empty (finished) day', () {
      final u = engine.chapterUniverse(books, const BibleRef('MAT', 1), const BibleRef('LUK', 2));
      final d = engine.readingForDay(u, 2, 10);
      expect(d.chapters, isEmpty);
      expect(d.dayIndex, greaterThanOrEqualTo(d.totalDays));
    });

    // Day-change contract: with a fixed startDate, the day index and today's
    // reading must advance as "today" rolls forward — the domain oracle for the
    // cached-"today" provider bug.
    test('day index and reading advance as today rolls forward', () {
      final plan = ReadingPlan(
        id: 'p',
        start: const BibleRef('MAT', 1),
        end: const BibleRef('LUK', 2),
        chaptersPerDay: 2,
        startDate: const CalendarDate(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(engine.dayIndexFor(plan.startDate, const CalendarDate(2026, 1, 1)), 0);
      expect(engine.dayIndexFor(plan.startDate, const CalendarDate(2026, 1, 2)), 1);
      expect(engine.dayIndexFor(plan.startDate, const CalendarDate(2026, 1, 3)), 2);

      expect(engine.today(books, plan, const CalendarDate(2026, 1, 1)).chapters.map((r) => '$r'),
          ['MAT 1', 'MAT 2']);
      expect(engine.today(books, plan, const CalendarDate(2026, 1, 2)).chapters.map((r) => '$r'),
          ['MAT 3', 'MRK 1']);
    });

    test('a plan whose startDate is in the future clamps to day 0', () {
      expect(
        engine.dayIndexFor(const CalendarDate(2026, 6, 10), const CalendarDate(2026, 6, 5)),
        0,
      );
    });
  });
}
