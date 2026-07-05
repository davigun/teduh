import 'package:flutter/material.dart';

import '../../../domain/entities/bible.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';

/// Pick a starting point for a reading plan: choose a book, then a chapter.
/// Returns the chosen [BibleRef], or null if dismissed. Only released books are
/// offered (the engine is availability-agnostic, but you can't read what isn't
/// out yet). Shared by plan setup and the create-group sheet.
Future<BibleRef?> showStartPicker(BuildContext context, List<BibleBook> books) {
  final available = books.where((b) => b.isAvailable).toList();
  return showModalBottomSheet<BibleRef>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _StartPickerSheet(books: available),
  );
}

class _StartPickerSheet extends StatefulWidget {
  const _StartPickerSheet({required this.books});
  final List<BibleBook> books;

  @override
  State<_StartPickerSheet> createState() => _StartPickerSheetState();
}

class _StartPickerSheetState extends State<_StartPickerSheet> {
  BibleBook? _book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final book = _book;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl, AppSpacing.xs, AppSpacing.xxl, AppSpacing.sm),
              child: Row(
                children: [
                  if (book != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: GestureDetector(
                        onTap: () => setState(() => _book = null),
                        child: Icon(Icons.chevron_left, color: c.ink, size: 24),
                      ),
                    ),
                  Text(book == null ? 'Mulai dari' : book.nama,
                      style: AppType.title.copyWith(color: c.ink, fontSize: 20)),
                ],
              ),
            ),
            Flexible(
              child: book == null
                  ? _BookList(
                      books: widget.books,
                      onPick: (b) => b.chapterCount <= 1
                          ? Navigator.pop(context, BibleRef(b.code, 1))
                          : setState(() => _book = b),
                    )
                  : _ChapterGrid(
                      book: book,
                      onPick: (ch) =>
                          Navigator.pop(context, BibleRef(book.code, ch)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.books, required this.onPick});
  final List<BibleBook> books;
  final ValueChanged<BibleBook> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: books.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(books[i].nama,
            style: AppType.body.copyWith(color: c.ink, fontSize: 16)),
        trailing: Text('${books[i].chapterCount} pasal',
            style: AppType.caption.copyWith(color: c.muted)),
        onTap: () => onPick(books[i]),
      ),
    );
  }
}

class _ChapterGrid extends StatelessWidget {
  const _ChapterGrid({required this.book, required this.onPick});
  final BibleBook book;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxl),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var ch = 1; ch <= book.chapterCount; ch++)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => onPick(ch),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.sunken,
                    borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text('$ch',
                    style: AppType.body.copyWith(
                        color: c.ink, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
