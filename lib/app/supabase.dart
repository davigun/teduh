import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client, or null when not configured (no --dart-define keys) or
/// init failed. null ⇒ the app runs fully offline with the social layer off.
/// Overridden in main() once Supabase.initialize succeeds.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
