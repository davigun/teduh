import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../domain/entities/bible.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/adaptive_scaffold.dart';
import '../../../design/widgets/section_card.dart';
import '../../../design/widgets/segmented_control.dart';

/// Alkitab — book browser. Not-yet-released TSI books render muted with a
/// "Segera" tag (e.g. Mazmur), never a dead end.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Testament _segment = Testament.nt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final booksAsync = ref.watch(booksProvider);

    return AdaptiveScaffold(
      title: 'Alkitab',
      slivers: booksAsync.when(
        loading: () => const [
          SliverFillRemaining(
              child: Center(child: CircularProgressIndicator.adaptive())),
        ],
        error: (e, _) => [
          SliverFillRemaining(
            child: Center(
                child: Text('Gagal memuat kitab.',
                    style: AppType.body.copyWith(color: c.ink2))),
          ),
        ],
        data: (books) {
          final shown = books.where((b) => b.testament == _segment).toList();
          final showOtNotice =
              _segment == Testament.ot && shown.any((b) => !b.isAvailable);
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.md),
                child: SegmentedControl(
                  segments: const [
                    SegmentItem('Perjanjian Lama'),
                    SegmentItem('Perjanjian Baru'),
                  ],
                  selected: _segment == Testament.ot ? 0 : 1,
                  onChanged: (i) => setState(
                      () => _segment = i == 0 ? Testament.ot : Testament.nt),
                ),
              ),
            ),
            if (showOtNotice)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color: c.wash, borderRadius: AppRadii.cardMd),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 17, color: c.accent),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Sebagian kitab Perjanjian Lama masih dalam pengerjaan dan akan hadir bertahap.',
                            style: AppType.caption.copyWith(color: c.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _BookTile(book: shown[i]),
                  childCount: shown.length,
                ),
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});
  final BibleBook book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final available = book.isAvailable;
    return Opacity(
      opacity: available ? 1 : 0.55,
      child: InkWell(
        borderRadius: AppRadii.cardMd,
        onTap: available ? () => context.push(Routes.reader(book.code, 1)) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: available ? c.wash : c.sunken,
                    borderRadius: BorderRadius.circular(11)),
                child: Text(_abbr(book.nama),
                    style: AppType.label.copyWith(
                        fontFamily: AppType.serif,
                        color: available ? c.accent : c.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.nama,
                        style: AppType.body.copyWith(
                            color: c.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    Text('${book.chapterCount} pasal',
                        style: AppType.caption.copyWith(color: c.muted)),
                  ],
                ),
              ),
              if (available)
                Icon(Icons.chevron_right, color: c.muted)
              else
                const SoonTag(label: 'Segera'),
            ],
          ),
        ),
      ),
    );
  }

  String _abbr(String nama) {
    final cleaned = nama.replaceAll(RegExp(r'^\d+\s*'), '');
    return cleaned.length >= 3 ? cleaned.substring(0, 3) : cleaned;
  }
}
