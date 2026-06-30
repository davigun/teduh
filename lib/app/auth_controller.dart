import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/services/auth_service.dart';
import 'supabase.dart';

/// Exposes account state to the UI, seeded synchronously from the current
/// session (correct on the first frame, offline) and updated by auth events.
/// Reading providers MUST NOT watch this — it gates only the social layer.
class AuthController extends Notifier<AuthSnapshot> {
  @override
  AuthSnapshot build() {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return AuthSnapshot.disabled;

    final sub = client.auth.onAuthStateChange
        .listen((data) => state = _fromSession(data.session));
    ref.onDispose(sub.cancel);

    return _fromSession(client.auth.currentSession);
  }

  AuthSnapshot _fromSession(Session? session) {
    final user = session?.user;
    if (user == null) return AuthSnapshot.signedOut;
    final meta = user.userMetadata ?? const {};
    return AuthSnapshot(
      AuthStatus.signedIn,
      userId: user.id,
      email: user.email,
      displayName:
          (meta['display_name'] ?? meta['full_name']) as String?,
      isAnonymous: user.isAnonymous,
    );
  }
}

final authProvider =
    NotifierProvider<AuthController, AuthSnapshot>(AuthController.new);
