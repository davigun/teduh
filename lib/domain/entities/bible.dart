import 'package:meta/meta.dart';

enum Testament { ot, nt }

/// A canonical book. [chapterCount] is fixed (the plan engine uses it and
/// ignores [isAvailable]); [isAvailable] is a render-time TSI status only.
@immutable
class BibleBook {
  const BibleBook({
    required this.code,
    required this.order,
    required this.nama,
    required this.testament,
    required this.chapterCount,
    required this.isAvailable,
  });

  final String code; // OSIS, e.g. 'GEN', 'MAT'
  final int order; // 1..66
  final String nama; // Indonesian name
  final Testament testament;
  final int chapterCount;
  final bool isAvailable;
}

/// Addressing key for a chapter. The book is referenced by OSIS [bookCode].
@immutable
class BibleRef {
  const BibleRef(this.bookCode, this.chapter);
  final String bookCode;
  final int chapter;

  @override
  bool operator ==(Object other) =>
      other is BibleRef && other.bookCode == bookCode && other.chapter == chapter;

  @override
  int get hashCode => Object.hash(bookCode, chapter);

  @override
  String toString() => '$bookCode $chapter';
}

enum SpanKind { wordsOfChrist, poetry, footnote }

/// A character-offset span over a verse's [Verse.text] (e.g. red-letter).
@immutable
class VerseSpan {
  const VerseSpan(this.kind, this.start, this.end);
  final SpanKind kind;
  final int start;
  final int end;
}

@immutable
class Verse {
  const Verse({
    required this.number,
    required this.text,
    this.label,
    this.spans = const [],
  });

  final int number; // start number (ordering)
  final String? label; // e.g. "2-6" for a merged range; else null
  final String text;
  final List<VerseSpan> spans;

  /// What to show as the verse marker.
  String get display => label ?? '$number';
}

@immutable
class Heading {
  const Heading(this.beforeVerse, this.text);
  final int beforeVerse;
  final String text;
}

@immutable
class Chapter {
  const Chapter({
    required this.ref,
    required this.verses,
    this.headings = const [],
  });

  final BibleRef ref;
  final List<Verse> verses;
  final List<Heading> headings;

  Heading? headingBefore(int verseNumber) {
    for (final h in headings) {
      if (h.beforeVerse == verseNumber) return h;
    }
    return null;
  }
}
