import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme/reading_theme.dart';
import 'providers.dart';

const _kThemeKey = 'reading_theme';

/// Holds the active reading theme. Backed by SharedPreferences (preloaded in
/// main) so it reads synchronously on the first frame — no theme flash.
class ThemeController extends Notifier<ReadingTheme> {
  @override
  ReadingTheme build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ReadingTheme.fromName(prefs.getString(_kThemeKey));
  }

  Future<void> set(ReadingTheme theme) async {
    state = theme;
    await ref.read(sharedPreferencesProvider).setString(_kThemeKey, theme.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ReadingTheme>(ThemeController.new);
