import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_prefs.dart';
import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/devotion/santapan_harian_service.dart';
import '../../../domain/entities/bible.dart';
import '../../../design/theme/reading_theme.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/reading_size_stepper.dart';
import '../../../design/widgets/segmented_control.dart';
import 'scripture_blocks.dart';

/// Pembaca — the reading surface. Renders real TSI text: serif on warm paper,
/// optional superscript verse numbers, section headings, red-letter spans where
/// the source provides them, with an adjustable reading size.
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.bookCode, required this.chapter});

  final String bookCode;
  final int chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ref0 = BibleRef(bookCode, chapter);
    final chapterAsync = ref.watch(chapterProvider(ref0));
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final books = ref.watch(booksProvider).value ?? const [];
    final bookName = names[bookCode] ?? bookCode;
    final chapterCount =
        books.where((b) => b.code == bookCode).map((b) => b.chapterCount).firstOrNull;
    final scale = readingScaleSteps[ref.watch(readingScaleProvider)];
    final showVerses = ref.watch(showVerseNumbersProvider);

    // Devotion hand-off: only from the LAST chapter of today's plan reading.
    final todays = ref.watch(todaysReadingProvider).value;
    final isTodaysClosing = todays != null &&
        todays.chapters.isNotEmpty &&
        todays.chapters.last == ref0;
    final devotion =
        isTodaysClosing ? ref.watch(devotionProvider).value : null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.canPop() ? context.pop() : context.go('/today'),
        ),
        title: Text('$bookName $chapter',
            style: AppType.title.copyWith(
                color: c.ink, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Tampilan',
            onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => const ReaderSettingsSheet()),
          ),
        ],
      ),
      body: chapterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => _ReaderError(unavailable: e is ChapterUnavailable),
        data: (chap) => Scrollbar(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.x4),
            children: buildScriptureBlocks(context, chap, scale, showVerses),
          ),
        ),
      ),
      bottomNavigationBar: _ReaderFooter(
        onPrev: chapter > 1
            ? () => context.pushReplacement(Routes.reader(bookCode, chapter - 1))
            : null,
        onNext: (chapterCount != null && chapter < chapterCount)
            ? () => context.pushReplacement(Routes.reader(bookCode, chapter + 1))
            : null,
        onMarkRead: () async {
          await markTodayReadAction(ref);
          if (context.mounted) context.go(Routes.home); // mark done + return home
        },
        // "Baca renungan" also counts as done — the devotion is the gentle
        // closing, not extra homework.
        onDevotion: devotion == null
            ? null
            : () async {
                await markTodayReadAction(ref);
                if (context.mounted) context.push(Routes.devotion);
              },
      ),
    );
  }

}

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final theme = ref.watch(themeControllerProvider);
    final step = ref.watch(readingScaleProvider);
    final showVerses = ref.watch(showVerseNumbersProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.x3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tampilan', style: AppType.title.copyWith(color: c.ink, fontSize: 20)),
          const SizedBox(height: AppSpacing.lg),
          SegmentedControl(
            segments: const [
              SegmentItem('Pagi', icon: Icons.wb_sunny_outlined),
              SegmentItem('Senja', icon: Icons.wb_twilight),
              SegmentItem('Malam', icon: Icons.nightlight_outlined),
            ],
            selected: theme.index,
            onChanged: (i) => ref
                .read(themeControllerProvider.notifier)
                .set(ReadingTheme.values[i]),
          ),
          _Row(
            label: 'Ukuran teks',
            trailing: ReadingSizeStepper(
              onSmaller: () =>
                  ref.read(readingScaleProvider.notifier).setStep(step - 1),
              onLarger: () =>
                  ref.read(readingScaleProvider.notifier).setStep(step + 1),
            ),
          ),
          _Row(
            label: 'Tampilkan nomor ayat',
            trailing: Switch.adaptive(
              value: showVerses,
              activeTrackColor: context.colors.accent,
              onChanged: (v) =>
                  ref.read(showVerseNumbersProvider.notifier).toggle(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.body.copyWith(color: c.ink, fontSize: 15)),
          trailing,
        ],
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.unavailable});
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Text(
          unavailable
              ? 'Bagian ini masih dalam pengerjaan dan akan hadir bertahap.'
              : 'Maaf, bacaan tidak bisa dimuat.',
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: c.ink2, height: 1.5),
        ),
      ),
    );
  }
}

class _ReaderFooter extends StatelessWidget {
  const _ReaderFooter(
      {required this.onPrev,
      required this.onNext,
      required this.onMarkRead,
      this.onDevotion});
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final Future<void> Function() onMarkRead;

  /// Non-null only on the last chapter of today's reading with a devotion
  /// available: shows the secondary "Baca renungan" hand-off (which also
  /// marks today done).
  final Future<void> Function()? onDevotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _RoundChip(icon: Icons.chevron_left, onTap: onPrev),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onMarkRead,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: c.onAccent,
                        minimumSize: const Size(0, 50),
                        shape: const StadiumBorder(),
                        textStyle: AppType.label.copyWith(fontSize: 15),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Tandai selesai'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _RoundChip(icon: Icons.chevron_right, onTap: onNext),
                ],
              ),
              if (onDevotion != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onDevotion,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.accent.withValues(alpha: 0.4)),
                      minimumSize: const Size(0, 46),
                      shape: const StadiumBorder(),
                      textStyle: AppType.label.copyWith(fontSize: 15),
                    ),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Baca renungan'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Material(
      color: c.sunken,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                color: enabled ? c.ink2 : c.muted.withValues(alpha: 0.4), size: 22)),
      ),
    );
  }
}
