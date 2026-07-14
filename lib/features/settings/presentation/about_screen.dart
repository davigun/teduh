import 'package:flutter/material.dart';

import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';

/// Tentang — includes the TSI CC BY-SA 4.0 attribution. This surface is required
/// by the translation's license and must not be removed.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Tentang Koinonia')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Text('Koinonia',
              style: AppType.display.copyWith(color: c.accent, fontSize: 36)),
          const SizedBox(height: AppSpacing.xs),
          Text('Saat teduh, bersama.',
              style: AppType.sectionHead.copyWith(color: c.ink2)),
          const SizedBox(height: AppSpacing.x3),
          Text('Terjemahan', style: AppType.overline.copyWith(color: c.muted)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Perjanjian Baru — Terjemahan Sederhana Indonesia (TSI). '
            'Hak cipta © Yayasan Alkitab BahasaKita (Albata) dan Pioneer Bible '
            'Translators. Lisensi: Creative Commons Attribution-ShareAlike 4.0 '
            '(CC BY-SA 4.0). Sumber: eBible.org (ind).',
            style: AppType.body.copyWith(color: c.ink2, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Perjanjian Lama — Alkitab Yang Terbuka (AYT). '
            'Hak cipta © YLSA-AYT 2011-2024. Lisensi: Creative Commons '
            'Attribution-NonCommercial-ShareAlike 4.0 (CC BY-NC-SA 4.0). '
            'Sumber: eBible.org (indayt).',
            style: AppType.body.copyWith(color: c.ink2, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Renungan — Santapan Harian. Hak cipta © Scripture Union Indonesia '
            '(Yayasan Pancar Pijar Alkitab). Ditampilkan dari SABDA (alkitab.mobi).',
            style: AppType.body.copyWith(color: c.ink2, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Karena Perjanjian Lama (AYT) berlisensi non-komersial, Koinonia '
            'dibagikan secara gratis dan tidak untuk dijual. Perubahan atas teks, '
            'bila ada, dibagikan di bawah lisensi yang sama.',
            style: AppType.caption.copyWith(color: c.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
