import 'package:meta/meta.dart';

enum AuthStatus { disabled, signedOut, signedIn }

/// Account state for the UI. `disabled` = Supabase not configured (offline build).
@immutable
class AuthSnapshot {
  const AuthSnapshot(this.status,
      {this.userId, this.email, this.displayName, this.isAnonymous = false});

  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? displayName;
  final bool isAnonymous; // device-local account (no email/Google linked yet)

  static const disabled = AuthSnapshot(AuthStatus.disabled);
  static const signedOut = AuthSnapshot(AuthStatus.signedOut);

  bool get isAvailable => status != AuthStatus.disabled;
  bool get isSignedIn => status == AuthStatus.signedIn;
}

/// Account actions. Reading never depends on this; it gates only the social layer.
abstract interface class AuthService {
  /// Frictionless default: create a device-local (anonymous) account with just a
  /// display name. No email/password. Upgradeable to a durable account later.
  Future<void> signInAnonymously({required String name});

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password, String? displayName});

  /// Native Google sign-in (id-token flow). Throws [AuthCancelled] if the user
  /// backs out. No-op-safe: only offered when Google is configured.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

/// Thrown when the user dismisses a provider sheet — surface nothing.
class AuthCancelled implements Exception {
  const AuthCancelled();
}
