@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:koinonia/core/errors/app_exception.dart';
import 'package:koinonia/data/repositories.dart';
import 'package:koinonia/domain/entities/bible.dart';

/// Exercises the real bundled assets/db/bible.db (built from TSI USFX) through
/// the production repository. Runs on the host VM (system libsqlite3).
void main() {
  late Database db;
  late SqliteBibleRepository repo;

  setUpAll(() {
    db = sqlite3.open('assets/db/bible.db', mode: OpenMode.readOnly);
    repo = SqliteBibleRepository(db);
  });

  tearDownAll(() => db.dispose());

  test('canon is complete and fully available (TSI NT + AYT OT)', () async {
    final books = await repo.books();
    expect(books.length, 66);
    expect(books.where((b) => b.isAvailable).length, 66);
  });

  test('reads a real chapter (Matius 5) with verses', () async {
    final chap = await repo.chapter(const BibleRef('MAT', 5));
    expect(chap.verses.length, greaterThan(10));
    expect(chap.verses.first.text, isNotEmpty);
    // The Beatitudes mention being "diberkati" (blessed) in TSI.
    expect(chap.verses.any((v) => v.text.contains('diberkati')), isTrue);
  });

  test('verse ranges keep a display label', () async {
    final chap = await repo.chapter(const BibleRef('MAT', 1));
    expect(chap.verses.any((v) => v.label != null && v.label!.contains('-')), isTrue);
  });

  test('Mazmur 23 (AYT OT) now reads', () async {
    final chap = await repo.chapter(const BibleRef('PSA', 23));
    expect(chap.verses, isNotEmpty);
    expect(chap.verses.first.text, contains('gembala'));
  });

  test('a non-existent chapter throws ChapterUnavailable', () async {
    expect(
      () => repo.chapter(const BibleRef('PSA', 999)),
      throwsA(isA<ChapterUnavailable>()),
    );
  });
}
