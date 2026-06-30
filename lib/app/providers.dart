import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/time/clock.dart';

/// Injected at the root in [main] after the instance is loaded, so device-local
/// prefs (theme, reading size) can be read synchronously on the first frame.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

/// The single clock. Override clockProvider in tests to pin "now".
final clockProvider = Provider<SystemClock>((ref) => const SystemClock());

/// Bumped by the SyncService after each realtime apply to the group mirror, so
/// group views (Beranda + group screen) recompute from the fresh local mirror.
/// Lives here (neutral) so the data layer can bump it without importing app UI.
class GroupMirrorRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state = state + 1;
}

final groupMirrorRevisionProvider =
    NotifierProvider<GroupMirrorRevision, int>(GroupMirrorRevision.new);
