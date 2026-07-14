import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/supabase.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload only small device-local prefs so theme/reading-size are available
  // synchronously on the first frame. Heavy work (DB install) is deferred to
  // appStartupProvider behind the AppStartupGate.
  final prefs = await SharedPreferences.getInstance();

  // Offline-safe: only restores a persisted session from disk (no network on the
  // first-frame path) and never blocks reading. null when no keys / init fails →
  // the social layer is simply disabled.
  SupabaseClient? supabase;
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        // The provided key is the legacy JWT anon key; anonKey is the right param
        // for it. Migrate to publishableKey (sb_publishable_*) before it's removed.
        // ignore: deprecated_member_use
        anonKey: _supabaseAnonKey,
        authOptions:
            const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      );
      supabase = Supabase.instance.client;
    } catch (_) {
      supabase = null;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(supabase),
      ],
      child: const KoinoniaApp(),
    ),
  );
}
