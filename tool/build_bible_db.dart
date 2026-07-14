// Builds the prebuilt, read-only `assets/db/bible.db` from a TSI USFX file.
//
// Usage:
//   dart run tool/build_bible_db.dart <path-to-tsi.usfx> [out=assets/db/bible.db]
//
// Download the TSI USFX from eBible.org (id `ind`). This is a one-time, offline
// pipeline: the app never parses USFX at runtime, it ships the resulting .db.
//
// The DB matches docs/ARCHITECTURE.md §5:
//   books(code PK, ord, nama, testament, chapter_count, is_available)
//   verses(book_code, chapter, verse, text, spans, PRIMARY KEY(book_code,chapter,verse)) WITHOUT ROWID
//   headings(book_code, chapter, before_verse, text)
//   meta(key PK, value)
//
// Red-letter / poetry / footnotes are stored as char-offset spans (JSON) over the
// canonical verse text, so sub-verse words-of-Christ are representable. The full
// 66-book canon is always inserted; books with no released TSI text get
// is_available=0 (rendered as "segera"), never omitted.

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:xml/xml.dart';

const int schemaVersion = 2; // v2: OT from AYT, NT from TSI

/// Canonical canon: (code, Indonesian name, testament, chapterCount). Order is
/// the list index + 1. Chapter counts are fixed; availability is decided by
/// whether the USFX actually contains the book.
const List<(String, String, String, int)> canon = [
  ('GEN', 'Kejadian', 'OT', 50), ('EXO', 'Keluaran', 'OT', 40),
  ('LEV', 'Imamat', 'OT', 27), ('NUM', 'Bilangan', 'OT', 36),
  ('DEU', 'Ulangan', 'OT', 34), ('JOS', 'Yosua', 'OT', 24),
  ('JDG', 'Hakim-hakim', 'OT', 21), ('RUT', 'Rut', 'OT', 4),
  ('1SA', '1 Samuel', 'OT', 31), ('2SA', '2 Samuel', 'OT', 24),
  ('1KI', '1 Raja-raja', 'OT', 22), ('2KI', '2 Raja-raja', 'OT', 25),
  ('1CH', '1 Tawarikh', 'OT', 29), ('2CH', '2 Tawarikh', 'OT', 36),
  ('EZR', 'Ezra', 'OT', 10), ('NEH', 'Nehemia', 'OT', 13),
  ('EST', 'Ester', 'OT', 10), ('JOB', 'Ayub', 'OT', 42),
  ('PSA', 'Mazmur', 'OT', 150), ('PRO', 'Amsal', 'OT', 31),
  ('ECC', 'Pengkhotbah', 'OT', 12), ('SNG', 'Kidung Agung', 'OT', 8),
  ('ISA', 'Yesaya', 'OT', 66), ('JER', 'Yeremia', 'OT', 52),
  ('LAM', 'Ratapan', 'OT', 5), ('EZK', 'Yehezkiel', 'OT', 48),
  ('DAN', 'Daniel', 'OT', 12), ('HOS', 'Hosea', 'OT', 14),
  ('JOL', 'Yoel', 'OT', 3), ('AMO', 'Amos', 'OT', 9),
  ('OBA', 'Obaja', 'OT', 1), ('JON', 'Yunus', 'OT', 4),
  ('MIC', 'Mikha', 'OT', 7), ('NAM', 'Nahum', 'OT', 3),
  ('HAB', 'Habakuk', 'OT', 3), ('ZEP', 'Zefanya', 'OT', 3),
  ('HAG', 'Hagai', 'OT', 2), ('ZEC', 'Zakharia', 'OT', 14),
  ('MAL', 'Maleakhi', 'OT', 4),
  ('MAT', 'Matius', 'NT', 28), ('MRK', 'Markus', 'NT', 16),
  ('LUK', 'Lukas', 'NT', 24), ('JHN', 'Yohanes', 'NT', 21),
  ('ACT', 'Kisah Para Rasul', 'NT', 28), ('ROM', 'Roma', 'NT', 16),
  ('1CO', '1 Korintus', 'NT', 16), ('2CO', '2 Korintus', 'NT', 13),
  ('GAL', 'Galatia', 'NT', 6), ('EPH', 'Efesus', 'NT', 6),
  ('PHP', 'Filipi', 'NT', 4), ('COL', 'Kolose', 'NT', 4),
  ('1TH', '1 Tesalonika', 'NT', 5), ('2TH', '2 Tesalonika', 'NT', 3),
  ('1TI', '1 Timotius', 'NT', 6), ('2TI', '2 Timotius', 'NT', 4),
  ('TIT', 'Titus', 'NT', 3), ('PHM', 'Filemon', 'NT', 1),
  ('HEB', 'Ibrani', 'NT', 13), ('JAS', 'Yakobus', 'NT', 5),
  ('1PE', '1 Petrus', 'NT', 5), ('2PE', '2 Petrus', 'NT', 3),
  ('1JN', '1 Yohanes', 'NT', 5), ('2JN', '2 Yohanes', 'NT', 1),
  ('3JN', '3 Yohanes', 'NT', 1), ('JUD', 'Yudas', 'NT', 1),
  ('REV', 'Wahyu', 'NT', 22),
];

class ParsedVerse {
  ParsedVerse(this.book, this.chapter, this.verse, {this.label});
  final String book;
  final int chapter;
  final int verse; // start number (PK / ordering)
  final String? label; // original id when a range, e.g. "2-6"; else null
  final StringBuffer text = StringBuffer();
  final List<Map<String, Object>> spans = [];
}

/// Usage: `dart run tool/build_bible_db.dart <nt.usfx> [ot.usfx] [out.db]`
/// Books are taken per-testament from the matching source. With one input,
/// both testaments come from it. Koinonia's canonical build:
///   dart run tool/build_bible_db.dart ind_usfx.xml indayt_usfx.xml assets/db/bible.db
/// (NT = TSI, OT = AYT.)
void main(List<String> args) {
  final inputs = args.where((a) => !a.endsWith('.db')).toList();
  final outPath = args.firstWhere((a) => a.endsWith('.db'),
      orElse: () => 'assets/db/bible.db');
  if (inputs.isEmpty) {
    stderr.writeln('Usage: dart run tool/build_bible_db.dart <nt.usfx> [ot.usfx] [out.db]');
    exitCode = 64;
    return;
  }
  final ntPath = inputs[0];
  final otPath = inputs.length > 1 ? inputs[1] : inputs[0];

  final testamentOf = {for (final c in canon) c.$1: c.$3};
  final verses = <ParsedVerse>[];
  final headings = <(String, int, int, String)>[];
  final presentBooks = <String>{};

  void collect(String path, String testament) {
    final xml = XmlDocument.parse(File(path).readAsStringSync());
    for (final book in xml.findAllElements('book')) {
      final code = book.getAttribute('id')?.toUpperCase();
      if (code == null || testamentOf[code] != testament) continue;
      presentBooks.add(code);
      _parseBook(book, code, verses, headings);
    }
  }

  collect(ntPath, 'NT');
  collect(otPath, 'OT');

  _writeDatabase(outPath, verses, headings, presentBooks);
  stdout.writeln(
      'Wrote $outPath — ${verses.length} verses, ${presentBooks.length}/${canon.length} books. NT<-$ntPath OT<-$otPath');
}

/// Walks a `<book>` in document order, emitting verses with wj (words-of-Christ)
/// char-offset spans and section headings (`<s>`).
void _parseBook(
  XmlElement book,
  String code,
  List<ParsedVerse> out,
  List<(String, int, int, String)> headings,
) {
  var chapter = 0;
  var wjDepth = 0;
  int? wjStart;
  ParsedVerse? current;

  void closeWj() {
    if (current != null && wjStart != null) {
      final end = current!.text.length;
      if (end > wjStart!) {
        current!.spans.add({'kind': 'wj', 'start': wjStart!, 'end': end});
      }
    }
    wjStart = null;
  }

  void walk(XmlNode node) {
    if (node is XmlText) {
      current?.text.write(node.value);
      return;
    }
    if (node is! XmlElement) return;

    switch (node.name.local) {
      case 'c':
        chapter = int.tryParse(node.getAttribute('id') ?? '') ?? chapter;
        return;
      case 'v':
        final id = node.getAttribute('id') ?? '';
        final m = RegExp(r'^\d+').firstMatch(id);
        if (m != null) {
          if (wjDepth > 0) closeWj();
          current = ParsedVerse(code, chapter, int.parse(m.group(0)!),
              label: id.contains('-') ? id : null);
          out.add(current!);
          if (wjDepth > 0) wjStart = 0;
        }
        return;
      case 've':
        if (wjDepth > 0) closeWj();
        current = null;
        return;
      case 's':
        headings.add((code, chapter, (current?.verse ?? 0) + 1, node.innerText.trim()));
        return;
      case 'wj':
        wjDepth++;
        wjStart = current?.text.length ?? 0;
        for (final child in node.children) {
          walk(child);
        }
        closeWj();
        wjDepth--;
        return;
      case 'f': // footnote — excluded from the verse body (rendered separately later)
        return;
      default:
        for (final child in node.children) {
          walk(child);
        }
    }
  }

  for (final child in book.children) {
    walk(child);
  }
}

void _writeDatabase(
  String outPath,
  List<ParsedVerse> verses,
  List<(String, int, int, String)> headings,
  Set<String> presentBooks,
) {
  final file = File(outPath);
  if (file.existsSync()) file.deleteSync();
  file.parent.createSync(recursive: true);
  // Clear any stale sidecars so the shipped asset is a single clean file.
  for (final ext in ['-wal', '-shm', '-journal']) {
    final s = File('$outPath$ext');
    if (s.existsSync()) s.deleteSync();
  }

  final db = sqlite3.open(outPath);
  db.execute('PRAGMA journal_mode=DELETE;');
  db.execute('''
    CREATE TABLE books(
      code TEXT PRIMARY KEY, ord INTEGER, nama TEXT, testament TEXT,
      chapter_count INTEGER, is_available INTEGER
    );
    CREATE TABLE verses(
      book_code TEXT, chapter INTEGER, verse INTEGER, label TEXT, text TEXT, spans TEXT,
      PRIMARY KEY(book_code, chapter, verse)
    ) WITHOUT ROWID;
    CREATE TABLE headings(
      book_code TEXT, chapter INTEGER, before_verse INTEGER, text TEXT
    );
    CREATE INDEX ix_verses_chapter ON verses(book_code, chapter);
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
  ''');

  db.execute('BEGIN;');
  final bookStmt = db.prepare(
      'INSERT INTO books(code, ord, nama, testament, chapter_count, is_available) VALUES(?,?,?,?,?,?)');
  for (var i = 0; i < canon.length; i++) {
    final (code, nama, testament, chapters) = canon[i];
    bookStmt.execute(
        [code, i + 1, nama, testament, chapters, presentBooks.contains(code) ? 1 : 0]);
  }
  bookStmt.dispose();

  final verseStmt = db.prepare(
      'INSERT OR REPLACE INTO verses(book_code, chapter, verse, label, text, spans) VALUES(?,?,?,?,?,?)');
  for (final v in verses) {
    verseStmt.execute([
      v.book,
      v.chapter,
      v.verse,
      v.label,
      v.text.toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
      v.spans.isEmpty ? null : jsonEncode(v.spans),
    ]);
  }
  verseStmt.dispose();

  final headingStmt = db.prepare(
      'INSERT INTO headings(book_code, chapter, before_verse, text) VALUES(?,?,?,?)');
  for (final (book, chapter, beforeVerse, text) in headings) {
    if (text.isNotEmpty) headingStmt.execute([book, chapter, beforeVerse, text]);
  }
  headingStmt.dispose();

  final metaStmt = db.prepare('INSERT INTO meta(key, value) VALUES(?,?)');
  metaStmt.execute(['schema_version', '$schemaVersion']);
  metaStmt.execute(['verse_count', '${verses.length}']);
  metaStmt.execute([
    'license_nt',
    'Perjanjian Baru: Terjemahan Sederhana Indonesia (TSI). CC BY-SA 4.0. © Yayasan Alkitab BahasaKita (Albata) & Pioneer Bible Translators. Sumber: eBible.org (ind).'
  ]);
  metaStmt.execute([
    'license_ot',
    'Perjanjian Lama: Alkitab Yang Terbuka (AYT). CC BY-NC-SA 4.0. © YLSA-AYT 2011-2024. Sumber: eBible.org (indayt).'
  ]);
  metaStmt.execute([
    'license',
    'PB: TSI (CC BY-SA 4.0). PL: AYT (CC BY-NC-SA 4.0, penggunaan non-komersial).'
  ]);
  metaStmt.dispose();

  db.execute('COMMIT;');
  db.execute('PRAGMA user_version=$schemaVersion;');
  db.execute('VACUUM;');
  db.dispose();
}
