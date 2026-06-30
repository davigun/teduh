import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_controller.dart';
import '../../../app/group_providers.dart';
import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/services/auth_service.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/adaptive_scaffold.dart';
import '../../../design/widgets/primary_button.dart';
import '../../../design/widgets/section_card.dart';

/// "Bersama" — a primary tab. Create or join a group and follow each other's
/// pace. Reading itself never depends on this screen; it only adds the social
/// layer, so every state degrades cleanly (disabled, signed-out, no group).
class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (!auth.isAvailable) {
      return const AdaptiveScaffold(
        title: 'Bersama',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Centered(text: 'Fitur ini belum tersedia.'),
          ),
        ],
      );
    }
    if (auth.status == AuthStatus.signedOut) {
      return const AdaptiveScaffold(
        title: 'Bersama',
        slivers: [SliverToBoxAdapter(child: _SignedOut())],
      );
    }

    final group = ref.watch(activeGroupProvider);
    return group.when(
      loading: () => const AdaptiveScaffold(
        title: 'Bersama',
        slivers: [
          SliverFillRemaining(
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ],
      ),
      error: (e, _) => const AdaptiveScaffold(
        title: 'Bersama',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Centered(text: 'Gagal memuat grup.'),
          ),
        ],
      ),
      data: (g) => g == null
          ? const AdaptiveScaffold(
              title: 'Bersama',
              slivers: [SliverToBoxAdapter(child: _NoGroup())],
            )
          : _GroupView(group: g),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(icon: Icons.people_outline, color: c.accent),
          const SizedBox(height: AppSpacing.xl),
          Text('Baca seiring dengan orang terdekat.',
              style: AppType.title
                  .copyWith(color: c.ink, fontSize: 23, height: 1.3)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cukup nama untuk membuat grup atau bergabung dengan kode. Tanpa email, tanpa kata sandi. Bacaanmu tetap tersimpan di perangkat.',
            style: AppType.body.copyWith(color: c.ink2, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Lanjutkan',
            icon: Icons.arrow_forward,
            onPressed: () => context.push(Routes.signIn),
          ),
        ],
      ),
    );
  }
}

class _NoGroup extends ConsumerWidget {
  const _NoGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(icon: Icons.people_outline, color: c.accent),
          const SizedBox(height: AppSpacing.xl),
          Text('Belum ada grup.',
              style: AppType.title.copyWith(color: c.ink, fontSize: 23)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Buat grup dari rencana bacamu, lalu bagikan kodenya. Atau masuk ke grup yang sudah ada.',
            style: AppType.body.copyWith(color: c.ink2, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Buat grup',
            icon: Icons.add,
            onPressed: () => _showCreateSheet(context, ref),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _showJoinSheet(context, ref),
            icon: const Icon(Icons.vpn_key_outlined, size: 19),
            label: const Text('Gabung dengan kode'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.ink,
              minimumSize: const Size(double.infinity, 54),
              side: BorderSide(color: c.hairline, width: 1.5),
              shape: const StadiumBorder(),
              textStyle: AppType.button,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupView extends ConsumerWidget {
  const _GroupView({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stages = ref.watch(groupStagesProvider);
    final scheduled = ref.watch(groupScheduledDayProvider).value;

    return AdaptiveScaffold(
      title: 'Bersama',
      trailing: IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Segarkan',
        onPressed: () => refreshGroupAction(ref),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, AppSpacing.xs, AppSpacing.xxl, AppSpacing.xxl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style:
                            AppType.title.copyWith(color: c.ink, fontSize: 24)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      scheduled == null
                          ? 'Rencana bersama'
                          : 'Hari ke-${scheduled + 1} · ${group.chaptersPerDay} pasal/hari',
                      style: AppType.body.copyWith(color: c.ink2),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CodeChip(code: group.joinCode),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(
                    bottom: AppSpacing.md, left: AppSpacing.xs),
                child: Text('ANGGOTA',
                    style: AppType.overline.copyWith(color: c.muted)),
              ),
              stages.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
                error: (e, _) => Text('Gagal memuat anggota.',
                    style: AppType.body.copyWith(color: c.muted)),
                data: (list) => SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.hairline),
                        _MemberTile(stage: list[i]),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextButton.icon(
                onPressed: () => _confirmLeave(context, ref),
                icon: Icon(Icons.logout, size: 18, color: c.red),
                label: Text('Keluar dari grup',
                    style: AppType.body.copyWith(color: c.red)),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.stage});
  final MemberStage stage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = stage.member;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.wash, shape: BoxShape.circle),
            child: Text(m.avatarEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(stage.isMe ? '${m.displayName} (kamu)' : m.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                            color: c.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (m.role == GroupRole.owner) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _Tag(text: 'Pemilik', color: c.accent),
                  ],
                ]),
                const SizedBox(height: 2),
                _StatusLine(stage: stage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.stage});
  final MemberStage stage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (text, color) = switch (stage) {
      _ when stage.behind > 0 => ('Tertinggal ${stage.behind} hari', c.gold),
      _ when stage.readToday => ('Sudah baca hari ini', c.success),
      _ when stage.highWater < 0 => ('Belum mulai', c.muted),
      _ => ('Hari ini belum dibaca', c.muted),
    };
    return Row(children: [
      Icon(
        stage.readToday
            ? Icons.check_circle
            : (stage.behind > 0 ? Icons.schedule : Icons.circle_outlined),
        size: 14,
        color: color,
      ),
      const SizedBox(width: 6),
      Text(text, style: AppType.caption.copyWith(color: color, fontSize: 12.5)),
    ]);
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kode disalin')));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
            color: c.sunken, borderRadius: BorderRadius.circular(AppRadii.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kode: ',
                style: AppType.caption.copyWith(color: c.muted)),
            Text(code,
                style: AppType.label.copyWith(
                    color: c.ink,
                    fontSize: 15,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.copy, size: 15, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.pill)),
        child: Text(text,
            style: AppType.caption
                .copyWith(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
            color: context.colors.wash, borderRadius: AppRadii.cardLg),
        child: Icon(icon, color: color, size: 32),
      );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: context.colors.ink2)),
        ),
      );
}

// --------------------------------------------------------------- create / join

Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
  final c = context.colors;
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      backgroundColor: c.surface,
      title: Text('Keluar dari grup?',
          style: AppType.title.copyWith(color: c.ink, fontSize: 19)),
      content: Text(
          'Riwayat bacamu tetap tersimpan. Kamu bisa bergabung lagi dengan kodenya.',
          style: AppType.body.copyWith(color: c.ink2)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Keluar', style: TextStyle(color: c.red))),
      ],
    ),
  );
  if (ok == true) await leaveGroupAction(ref);
}

void _showCreateSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _CreateSheet(),
  );
}

void _showJoinSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _JoinSheet(),
  );
}

class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet();
  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plan = ref.read(activePlanProvider).value;
    if (plan == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Beri nama grupnya.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await createGroupAction(ref,
          name: name,
          start: plan.start,
          end: plan.end,
          chaptersPerDay: plan.chaptersPerDay);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Gagal membuat grup. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plan = ref.watch(activePlanProvider).value;
    final names = ref.watch(bookNamesProvider).value ?? const {};

    return _SheetFrame(
      title: 'Buat grup',
      child: plan == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atur rencana bacamu dulu, lalu buat grup dari rencana itu.',
                    style: AppType.body.copyWith(color: c.ink2, height: 1.5)),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Atur rencana',
                  icon: Icons.tune,
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(Routes.planSetup);
                  },
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDeco(context, 'Nama grup', 'mis. Keluarga'),
                  style: AppType.body.copyWith(color: c.ink),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                      color: c.sunken, borderRadius: AppRadii.cardMd),
                  child: Row(children: [
                    Icon(Icons.menu_book_outlined, size: 18, color: c.accent),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${names[plan.start.bookCode] ?? plan.start.bookCode} – ${names[plan.end.bookCode] ?? plan.end.bookCode} · ${plan.chaptersPerDay} pasal/hari · mulai hari ini',
                        style: AppType.caption.copyWith(color: c.ink2),
                      ),
                    ),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: AppType.caption.copyWith(color: c.red)),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _busy ? 'Membuat…' : 'Buat grup',
                  icon: Icons.check,
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
    );
  }
}

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet();
  @override
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends ConsumerState<_JoinSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('group_not_found')) return 'Kode tidak ditemukan.';
    if (s.contains('group_full')) return 'Grup sudah penuh.';
    if (s.contains('not_authenticated')) return 'Masuk dulu untuk bergabung.';
    return 'Gagal bergabung. Periksa kodenya.';
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Masukkan kode grup.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await joinGroupAction(ref, code);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = _humanize(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _SheetFrame(
      title: 'Gabung grup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            maxLength: 6,
            decoration: _fieldDeco(context, 'Kode grup', '6 huruf/angka')
                .copyWith(counterText: ''),
            style: AppType.title.copyWith(
                color: c.ink, fontSize: 20, letterSpacing: 3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Bergabung akan mengikuti rencana baca grup.',
              style: AppType.caption.copyWith(color: c.muted)),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: AppType.caption.copyWith(color: c.red)),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _busy ? 'Bergabung…' : 'Gabung',
            icon: Icons.login,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.xxl + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.title.copyWith(color: c.ink, fontSize: 21)),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

InputDecoration _fieldDeco(BuildContext context, String label, String hint) {
  final c = context.colors;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: AppType.body.copyWith(color: c.muted),
    hintStyle: AppType.body.copyWith(color: c.muted),
    filled: true,
    fillColor: c.sunken,
    border: OutlineInputBorder(
        borderRadius: AppRadii.cardMd, borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.cardMd, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.cardMd,
        borderSide: BorderSide(color: c.accent, width: 1.5)),
  );
}
