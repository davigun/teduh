import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_controller.dart';
import '../../../data/auth/supabase_auth_service.dart';
import '../../../domain/services/auth_service.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/primary_button.dart';

/// Account entry for "Baca bersama". Name-first: the default path creates a
/// device-local (anonymous) account from just a name. Google/email are optional
/// durable alternatives. Reached only from Settings / the Together tab; reading
/// never routes here.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showEmail = false; // reveal the durable email form
  bool _isSignUp = false; // within the email form
  bool _anonBusy = false;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  bool get _anyBusy => _anonBusy || _busy || _googleBusy;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _closeIfDone() {
    if (mounted && ref.read(authProvider).isSignedIn) context.pop();
  }

  Future<void> _quickStart() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Isi namamu dulu.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _anonBusy = true;
      _error = null;
    });
    try {
      await auth.signInAnonymously(name: name);
      _closeIfDone();
    } catch (e) {
      if (mounted) setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _anonBusy = false);
    }
  }

  Future<void> _google() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await auth.signInWithGoogle();
      _closeIfDone();
    } on AuthCancelled {
      // user dismissed the Google sheet — say nothing
    } catch (e) {
      if (mounted) setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _emailSubmit() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await auth.signUp(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text);
      } else {
        await auth.signIn(email: _email.text.trim(), password: _password.text);
      }
      if (!mounted) return;
      if (ref.read(authProvider).isSignedIn) {
        context.pop();
      } else {
        setState(() =>
            _error = 'Akun dibuat. Cek email untuk konfirmasi, lalu masuk.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('anonymous') && m.contains('disabled')) {
      return 'Mode tamu belum diaktifkan di server.';
    }
    if (m.contains('invalid login')) return 'Email atau kata sandi salah.';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Email ini sudah terdaftar. Coba masuk.';
    }
    if (m.contains('password')) return 'Kata sandi minimal 6 karakter.';
    if (m.contains('socket') || m.contains('network') || m.contains('failed host')) {
      return 'Tidak ada koneksi. Coba lagi nanti.';
    }
    return 'Maaf, ada kendala. Coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Baca bersama')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Siapa namamu?',
              style: AppType.title.copyWith(color: c.ink, fontSize: 24)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Cukup nama untuk mulai baca bersama. Tanpa email, tanpa kata sandi. Membaca tetap bisa tanpa ini.',
            style: AppType.body.copyWith(color: c.ink2, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Field(
            controller: _name,
            label: 'Nama',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: AppType.caption.copyWith(color: c.red, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _anonBusy ? 'Sebentar…' : 'Lanjutkan',
            icon: Icons.arrow_forward,
            onPressed: _anyBusy ? null : _quickStart,
          ),
          const SizedBox(height: AppSpacing.x4),

          // Optional durable account.
          Row(children: [
            Expanded(child: Divider(color: c.hairline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('amankan akun (opsional)',
                  style: AppType.caption.copyWith(color: c.muted)),
            ),
            Expanded(child: Divider(color: c.hairline)),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tambahkan Google atau email agar akunmu bisa dipulihkan saat ganti HP atau pasang ulang.',
            style: AppType.caption.copyWith(color: c.muted, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (googleSignInEnabled) ...[
            _GoogleButton(
                busy: _googleBusy, onPressed: _anyBusy ? null : _google),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!_showEmail)
            Center(
              child: TextButton(
                onPressed:
                    _anyBusy ? null : () => setState(() => _showEmail = true),
                child: Text('Pakai email',
                    style: AppType.label.copyWith(color: c.accent)),
              ),
            )
          else ...[
            _Field(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.md),
            _Field(
                controller: _password,
                label: 'Kata sandi',
                icon: Icons.lock_outline,
                obscure: true),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: _busy
                  ? 'Mohon tunggu…'
                  : (_isSignUp ? 'Daftar dengan email' : 'Masuk dengan email'),
              onPressed: _anyBusy ? null : _emailSubmit,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _anyBusy
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                        }),
                child: Text(
                  _isSignUp
                      ? 'Sudah punya akun? Masuk'
                      : 'Belum punya akun email? Daftar',
                  style: AppType.label.copyWith(color: c.accent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(double.infinity, 54),
        side: BorderSide(color: c.hairline, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: AppType.button,
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation(c.muted)))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4285F4), shape: BoxShape.circle),
                  child: const Text('G',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                const Text('Lanjut dengan Google'),
              ],
            ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: false,
      enableSuggestions: false,
      style: AppType.body.copyWith(color: c.ink, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: c.muted, size: 20),
        filled: true,
        fillColor: c.surface,
        labelStyle: AppType.body.copyWith(color: c.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.cardMd,
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.cardMd,
          borderSide: BorderSide(color: c.accent, width: 1.6),
        ),
      ),
    );
  }
}
