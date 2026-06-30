import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'providers.dart';

const _scaleKey = 'reading_scale_step';
const _versesKey = 'show_verse_numbers';
const _onboardKey = 'onboarding_done';
const _reminderOnKey = 'reminder_enabled';
const _reminderHourKey = 'reminder_hour';
const _reminderMinKey = 'reminder_minute';

/// Scripture size multipliers (applied only to the reading surface).
const readingScaleSteps = [0.9, 1.0, 1.15, 1.3];

class ReadingScaleController extends Notifier<int> {
  @override
  int build() => ref.watch(sharedPreferencesProvider).getInt(_scaleKey) ?? 1;

  double get multiplier => readingScaleSteps[state];

  Future<void> setStep(int step) async {
    final clamped = step.clamp(0, readingScaleSteps.length - 1);
    state = clamped;
    await ref.read(sharedPreferencesProvider).setInt(_scaleKey, clamped);
  }
}

final readingScaleProvider =
    NotifierProvider<ReadingScaleController, int>(ReadingScaleController.new);

class ShowVerseNumbersController extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_versesKey) ?? true;

  Future<void> toggle(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_versesKey, value);
  }
}

final showVerseNumbersProvider =
    NotifierProvider<ShowVerseNumbersController, bool>(ShowVerseNumbersController.new);

/// First-run flag. The router redirects to onboarding until this is true.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_onboardKey) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_onboardKey, true);
  }
}

final onboardingDoneProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

@immutable
class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.hour, required this.minute});
  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class ReminderController extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ReminderSettings(
      enabled: prefs.getBool(_reminderOnKey) ?? false,
      hour: prefs.getInt(_reminderHourKey) ?? 6,
      minute: prefs.getInt(_reminderMinKey) ?? 30,
    );
  }

  Future<void> update(ReminderSettings value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_reminderOnKey, value.enabled);
    await prefs.setInt(_reminderHourKey, value.hour);
    await prefs.setInt(_reminderMinKey, value.minute);
  }
}

final reminderProvider =
    NotifierProvider<ReminderController, ReminderSettings>(ReminderController.new);
