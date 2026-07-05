/// A chapter exists in the canon but its TSI text is not yet released ("segera").
/// The UI maps this to gentle Bahasa Indonesia copy — never a raw "Tidak ada data".
class ChapterUnavailable implements Exception {
  const ChapterUnavailable(this.bookCode, this.chapter);
  final String bookCode;
  final int chapter;

  @override
  String toString() => 'ChapterUnavailable($bookCode $chapter)';
}
