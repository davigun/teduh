import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme/app_theme.dart';
import 'router/app_router.dart';
import 'startup/app_startup.dart';
import 'theme_controller.dart';

class TeduhApp extends ConsumerWidget {
  const TeduhApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Teduh',
      debugShowCheckedModeBanner: false,
      theme: appThemeFor(theme),
      routerConfig: router,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          AppStartupGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
