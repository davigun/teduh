import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../domain/services/auth_service.dart';
import 'auth_controller.dart';
import 'group_providers.dart';

/// After sign-in/sync, go live on the active group (if any) so members' progress
/// streams in. Safe no-op offline / when there's no group.
Future<void> _activateActiveGroup(Ref ref) async {
  final group = await ref.read(groupRepositoryProvider).activeGroup();
  if (group != null) {
    await ref.read(syncServiceProvider).activateGroup(group.id);
  }
}

/// Bridges auth → sync. On sign-in it runs the first-sign-in backfill + push +
/// pull; on sign-out it clears the social mirror. Kept alive by a watch at the
/// app root. Reading never depends on this — it only feeds the social layer.
final syncBridgeProvider = Provider<void>((ref) {
  ref.listen<AuthSnapshot>(authProvider, (prev, next) {
    final sync = ref.read(syncServiceProvider);
    final wasSignedIn = prev?.isSignedIn ?? false;
    if (next.isSignedIn && !wasSignedIn && next.userId != null) {
      // ignore: unawaited_futures
      sync.onSignedIn(next.userId!).then((_) async {
        ref.invalidate(activeGroupProvider);
        ref.invalidate(groupStagesProvider);
        await _activateActiveGroup(ref);
      });
    } else if (!next.isSignedIn && wasSignedIn) {
      // ignore: unawaited_futures
      sync.onSignedOut().then((_) {
        ref.invalidate(activeGroupProvider);
        ref.invalidate(groupStagesProvider);
      });
    }
  });

  // Cold start already signed in (session restored from disk): sync once.
  final auth = ref.read(authProvider);
  if (auth.isSignedIn && auth.userId != null) {
    final uid = auth.userId!;
    Future.microtask(() async {
      await ref.read(syncServiceProvider).onSignedIn(uid);
      ref.invalidate(activeGroupProvider);
      ref.invalidate(groupStagesProvider);
      await _activateActiveGroup(ref);
    });
  }
});
