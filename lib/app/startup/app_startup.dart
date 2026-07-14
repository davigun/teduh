import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/databases.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_typography.dart';
import '../day_change_refresher.dart';
import '../sync_controller.dart';

/// One-time async startup: installs the read-only bible.db from assets and opens
/// both databases, off the first-frame path. UI is gated on this so the
/// multi-MB copy never janks.
final appStartupProvider = FutureProvider<void>((ref) async {
  await ref.watch(databasesProvider.future);
});

/// Shows a calm splash while [appStartupProvider] resolves, then the app.
class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    return startup.when(
      data: (_) => DayChangeRefresher(child: _SyncBridge(child: child)),
      loading: () => const _Splash(),
      error: (e, _) => _StartupError(message: '$e'),
    );
  }
}

/// Instantiates the auth→sync bridge only after the databases are open (it reads
/// the writable app.db), so the offline-first first-frame path is never blocked.
class _SyncBridge extends ConsumerWidget {
  const _SyncBridge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncBridgeProvider);
    return child;
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Text(
          'Koinonia',
          style: AppType.display.copyWith(color: c.accent, fontSize: 40),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Maaf, ada kendala saat memuat.\n$message',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: c.ink2),
          ),
        ),
      ),
    );
  }
}
