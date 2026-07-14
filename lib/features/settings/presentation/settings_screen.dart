import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_prefs.dart';
import '../../../app/auth_controller.dart';
import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme_controller.dart';
import '../../../data/auth/supabase_auth_service.dart';
import '../../../domain/services/auth_service.dart';
import '../../../design/theme/reading_theme.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/adaptive_scaffold.dart';
import '../../../design/widgets/reading_size_stepper.dart';
import '../../../design/widgets/section_card.dart';
import '../../../design/widgets/segmented_control.dart';
import '../../../services/notification_service.dart';

/// Pengaturan. Theme, reading size, daily reminder, and About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final theme = ref.watch(themeControllerProvider);
    final step = ref.watch(readingScaleProvider);
    final reminder = ref.watch(reminderProvider);
    final auth = ref.watch(authProvider);
    final plan = ref.watch(activePlanProvider).value;
    final names = ref.watch(bookNamesProvider).value ?? const {};

    return AdaptiveScaffold.list(
      title: 'Pengaturan',
      children: [
          if (auth.isAvailable) ...[
            _SectionLabel('AKUN'),
            SectionCard(
              padding: EdgeInsets.zero,
              child: auth.status == AuthStatus.signedIn
                  ? Column(children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                        leading: CircleAvatar(
                          backgroundColor: c.wash,
                          child: Icon(Icons.person_outline, color: c.accent),
                        ),
                        title: Text(auth.displayName ?? 'Akun Koinonia',
                            style: AppType.body
                                .copyWith(color: c.ink, fontSize: 15)),
                        subtitle: Text(
                            auth.email ??
                                (auth.isAnonymous
                                    ? 'Akun di perangkat ini'
                                    : 'Akun Koinonia'),
                            style: AppType.caption.copyWith(color: c.muted)),
                      ),
                      Divider(height: 1, color: c.hairline),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                        title: Text('Keluar',
                            style: AppType.body
                                .copyWith(color: c.red, fontSize: 15)),
                        trailing: Icon(Icons.logout, color: c.red, size: 20),
                        onTap: () => ref.read(authServiceProvider)?.signOut(),
                      ),
                    ])
                  : ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                      title: Text('Mulai baca bersama',
                          style:
                              AppType.body.copyWith(color: c.ink, fontSize: 15)),
                      subtitle: Text('Cukup nama, tanpa email',
                          style: AppType.caption.copyWith(color: c.muted)),
                      trailing: Icon(Icons.chevron_right, color: c.muted),
                      onTap: () => context.push(Routes.signIn),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          _SectionLabel('BACAAN'),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
              title: Text('Rencana baca',
                  style: AppType.body.copyWith(color: c.ink, fontSize: 15)),
              subtitle: Text(
                  plan == null
                      ? 'Belum diatur'
                      : '${names[plan.start.bookCode] ?? plan.start.bookCode} – ${names[plan.end.bookCode] ?? plan.end.bookCode} · ${plan.chaptersPerDay} pasal/hari',
                  style: AppType.caption.copyWith(color: c.muted)),
              trailing: Icon(Icons.chevron_right, color: c.muted),
              onTap: () => context.push(Routes.plan),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('TAMPILAN'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema baca',
                    style: AppType.label.copyWith(
                        color: c.ink, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.md),
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
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.lg),
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.hairline))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ukuran teks',
                          style: AppType.body.copyWith(color: c.ink, fontSize: 15)),
                      ReadingSizeStepper(
                        onSmaller: () => ref
                            .read(readingScaleProvider.notifier)
                            .setStep(step - 1),
                        onLarger: () => ref
                            .read(readingScaleProvider.notifier)
                            .setStep(step + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('PENGINGAT'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pengingat harian',
                                style: AppType.body
                                    .copyWith(color: c.ink, fontSize: 15)),
                            Text('Ajakan lembut untuk membaca tiap hari',
                                style: AppType.caption.copyWith(color: c.muted)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: reminder.enabled,
                        activeTrackColor: c.accent,
                        onChanged: (v) => _toggleReminder(context, ref, reminder, v),
                      ),
                    ],
                  ),
                ),
                if (reminder.enabled)
                  Container(
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.hairline))),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Waktu',
                          style: AppType.body.copyWith(color: c.ink, fontSize: 15)),
                      trailing: Text(_fmt(reminder.hour, reminder.minute),
                          style: AppType.title.copyWith(
                              color: c.accent,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      onTap: () => _pickTime(context, ref, reminder),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('LAINNYA'),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
              title: Text('Tentang Koinonia',
                  style: AppType.body.copyWith(color: c.ink, fontSize: 15)),
              trailing: Icon(Icons.chevron_right, color: c.muted),
              onTap: () => context.push(Routes.about),
            ),
          ),
        ],
    );
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref,
      ReminderSettings current, bool enable) async {
    final svc = ref.read(notificationServiceProvider);
    if (enable) {
      final granted = await svc.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Izin notifikasi diperlukan untuk pengingat.')));
        }
        return;
      }
      await ref.read(reminderProvider.notifier).update(current.copyWith(enabled: true));
      await svc.scheduleDaily(current.hour, current.minute);
    } else {
      await ref.read(reminderProvider.notifier).update(current.copyWith(enabled: false));
      await svc.cancel();
    }
  }

  Future<void> _pickTime(
      BuildContext context, WidgetRef ref, ReminderSettings current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    final next = current.copyWith(hour: picked.hour, minute: picked.minute);
    await ref.read(reminderProvider.notifier).update(next);
    if (next.enabled) {
      await ref.read(notificationServiceProvider).scheduleDaily(next.hour, next.minute);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(text,
            style: AppType.overline.copyWith(color: context.colors.muted)),
      );
}

