import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/supabase.dart';
import '../../domain/services/auth_service.dart';

// Google OAuth client IDs (from Google Cloud Console), injected via --dart-define.
// Web client = the "Client ID" you paste into Supabase's Google provider; it's
// the audience of the idToken. iOS client = the native app's client.
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Whether the "Lanjut dengan Google" button should be shown at all.
const googleSignInEnabled = _googleWebClientId != '';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);
  final SupabaseClient _client;

  /// Matches the server's `profiles_display_name_len` check (40 chars).
  static String _clampName(String name) {
    final n = name.trim();
    return n.length > 40 ? n.substring(0, 40) : n;
  }

  static bool _googleInitialized = false;

  @override
  Future<void> signInAnonymously({required String name}) async {
    await _client.auth.signInAnonymously();
    // 40 = the server-side profiles_display_name_len cap; clamping here keeps
    // the profile update from bouncing off the constraint.
    final n = _clampName(name);
    if (n.isEmpty) return;
    // Set the name on the user (drives AuthSnapshot) and on the profile row
    // (what group-mates see via the mirror).
    await _client.auth.updateUser(UserAttributes(data: {'display_name': n}));
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await _client.from('profiles').update({'display_name': n}).eq('id', uid);
      } catch (_) {/* profile trigger default 'Pembaca' stands if this races */}
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': _clampName(displayName),
        },
      );

  @override
  Future<void> signInWithGoogle() async {
    if (!googleSignInEnabled) {
      throw const AuthException('Google belum dikonfigurasi.');
    }
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(
        clientId: _googleIosClientId.isEmpty ? null : _googleIosClientId,
        serverClientId: _googleWebClientId,
      );
      _googleInitialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google tidak mengembalikan idToken.');
    }
    // accessToken lets Supabase complete the Google id-token grant.
    final authz =
        await account.authorizationClient.authorizeScopes(const ['email', 'profile']);

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authz.accessToken,
    );
  }

  @override
  Future<void> signOut() async {
    // Sign out of Google too so the next user gets the account chooser.
    if (googleSignInEnabled && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {/* ignore */}
    }
    await _client.auth.signOut();
  }
}

/// null when Supabase isn't configured.
final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthService(client);
});
