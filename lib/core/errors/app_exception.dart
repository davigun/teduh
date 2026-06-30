/// App-wide failure type. Each case carries a stable [messageId] that the UI
/// maps to gentle Bahasa Indonesia copy — never a raw "Tidak ada data".
sealed class AppException implements Exception {
  const AppException();

  /// Stable key for the localized, user-facing message.
  String get messageId;
}

/// A chapter exists in the canon but its TSI text is not yet released ("segera").
class ChapterUnavailable extends AppException {
  const ChapterUnavailable(this.bookCode, this.chapter);
  final String bookCode;
  final int chapter;

  @override
  String get messageId => 'chapterUnavailable';

  @override
  String toString() => 'ChapterUnavailable($bookCode $chapter)';
}
