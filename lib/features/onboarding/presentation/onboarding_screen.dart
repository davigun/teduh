import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_prefs.dart';
import '../../../app/router/app_router.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/primary_button.dart';

/// First-run welcome. Shown until [onboardingDoneProvider] is true.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Text('Koinonia',
                  style: AppType.display.copyWith(color: c.accent, fontSize: 48)),
              const SizedBox(height: AppSpacing.sm),
              Text('Saat teduh, setiap hari.',
                  style: AppType.sectionHead.copyWith(color: c.ink2, fontSize: 19)),
              const SizedBox(height: AppSpacing.x3),
              _Point(
                icon: Icons.menu_book_outlined,
                title: 'Baca dengan tenang',
                body: 'Firman Allah dalam Bahasa Indonesia (TSI), bisa dibaca tanpa internet.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _Point(
                icon: Icons.route_outlined,
                title: 'Langkah yang pas',
                body: 'Tentukan beberapa pasal sehari; Koinonia menjaga jadwalmu.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _Point(
                icon: Icons.local_fire_department_outlined,
                title: 'Tumbuh perlahan',
                body: 'Tandai bacaan selesai dan lihat kebiasaanmu bertumbuh, tanpa tekanan.',
              ),
              const Spacer(flex: 3),
              PrimaryButton(
                label: 'Mulai',
                onPressed: () async {
                  await ref.read(onboardingDoneProvider.notifier).complete();
                  if (context.mounted) context.go(Routes.home);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: c.wash, borderRadius: AppRadii.cardMd),
          child: Icon(icon, color: c.accent, size: 22),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppType.label.copyWith(
                      color: c.ink, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(body, style: AppType.body.copyWith(color: c.ink2, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
