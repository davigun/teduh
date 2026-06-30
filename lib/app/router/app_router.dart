import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/plan/presentation/plan_setup_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/together/presentation/together_screen.dart';
import '../app_prefs.dart';
import 'home_shell.dart';

/// App routes. Reading is never walled behind a plan: /library and /read are
/// always reachable. (First-run onboarding will gate only /today via a prefs
/// flag in P1.)
abstract final class Routes {
  static const home = '/today';
  static const library = '/library';
  static const plan = '/plan';
  static const planSetup = '/plan/setup';
  static const settings = '/settings';
  static const about = '/about';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const together = '/together';
  static String reader(String bookCode, int chapter) => '/read/$bookCode/$chapter';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    initialLocation: Routes.home,
    navigatorKey: shellKey,
    redirect: (context, state) {
      final done = ref.read(onboardingDoneProvider);
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!done && !atOnboarding) return Routes.onboarding;
      if (done && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
          path: Routes.onboarding, builder: (c, s) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.library, builder: (c, s) => const LibraryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.together, builder: (c, s) => const TogetherScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.settings, builder: (c, s) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/read/:bookCode/:chapter',
        builder: (c, s) => ReaderScreen(
          bookCode: s.pathParameters['bookCode']!,
          chapter: int.tryParse(s.pathParameters['chapter'] ?? '1') ?? 1,
        ),
      ),
      GoRoute(path: Routes.plan, builder: (c, s) => const PlanScreen()),
      GoRoute(path: Routes.planSetup, builder: (c, s) => const PlanSetupScreen()),
      GoRoute(path: Routes.about, builder: (c, s) => const AboutScreen()),
      GoRoute(path: Routes.signIn, builder: (c, s) => const SignInScreen()),
    ],
  );
});
