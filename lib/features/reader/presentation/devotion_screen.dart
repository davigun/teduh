import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_prefs.dart';
import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../data/devotion/santapan_harian_service.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/section_card.dart';
import 'scripture_blocks.dart';

/// Renungan — today's Santapan Harian devotion on its own page, with the
/// devotion's "Bacaan:" passage rendered inline from the local Bible so the
/// reader never has to leave to look it up.
class DevotionScreen extends ConsumerWidget {
  const DevotionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final devotion = ref.watch(devotionProvider).value;
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final parsed =
        devotion == null ? null : parsePassageRef(devotion.passage, names);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: Text('Renungan',
            style: AppType.title.copyWith(
                color: c.ink, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: devotion == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Text('Renungan hari ini belum tersedia.',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: c.ink2, height: 1.5)),
              ),
            )
          : Scrollbar(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.x4),
                children: [
                  Text('RENUNGAN · SANTAPAN HARIAN',
                      style: AppType.overline.copyWith(color: c.muted)),
                  const SizedBox(height: AppSpacing.md),
                  Text(devotion.title,
                      style: AppType.title.copyWith(color: c.ink, fontSize: 22)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Bacaan: ${devotion.passage}',
                      style: AppType.caption.copyWith(color: c.accent)),
                  const SizedBox(height: AppSpacing.lg),
                  if (parsed != null) _PassageCard(parsed: parsed),
                  Text(devotion.body,
                      style: AppType.body.copyWith(color: c.ink2, height: 1.6)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '© Scripture Union Indonesia (Yay. Pancar Pijar Alkitab) · via SABDA, alkitab.mobi',
                    style: AppType.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: devotion == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.hairline)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: FilledButton.icon(
                    onPressed: () => context.go(Routes.home),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: const StadiumBorder(),
                      textStyle: AppType.label.copyWith(fontSize: 15),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Selesai'),
                  ),
                ),
              ),
            ),
    );
  }
}

/// The devotion's daily passage, rendered from the local Bible. Silently absent
/// when the chapter can't be loaded — the reference label above still stands.
class _PassageCard extends ConsumerWidget {
  const _PassageCard({required this.parsed});
  final PassageRef parsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = readingScaleSteps[ref.watch(readingScaleProvider)];
    final showVerses = ref.watch(showVerseNumbersProvider);
    return ref.watch(chapterProvider(parsed.ref)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (chap) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: buildScriptureBlocks(
                  context,
                  chap,
                  scale,
                  showVerses,
                  fromVerse: parsed.fromVerse,
                  toVerse: parsed.toVerse,
                ),
              ),
            ),
          ),
        );
  }
}
