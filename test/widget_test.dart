import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koinonia/app/app.dart';
import 'package:koinonia/app/providers.dart';
import 'package:koinonia/app/startup/app_startup.dart';
import 'package:koinonia/core/time/calendar_date.dart';
import 'package:koinonia/data/repositories.dart';
import 'package:koinonia/domain/entities/bible.dart';
import 'package:koinonia/domain/entities/plan.dart';
import 'package:koinonia/domain/entities/progress.dart';
import 'package:koinonia/domain/repositories.dart';

class _FakeBible implements BibleRepository {
  @override
  Future<List<BibleBook>> books() async => const [];
  @override
  Future<Chapter> chapter(BibleRef ref) async =>
      Chapter(ref: ref, verses: const []);
}

class _FakePlan implements PlanRepository {
  @override
  Future<ReadingPlan?> activePlan() async => null;
  @override
  Future<void> save(ReadingPlan plan) async {}
}

class _FakeProgress implements ProgressRepository {
  @override
  Future<Set<CalendarDate>> completedDates() async => {};
  @override
  Future<bool> isDayCompleted(String planId, int dayIndex) async => false;
  @override
  Future<void> markRead(DayCompletion completion) async {}
}

void main() {
  testWidgets('App boots to Beranda and invites a plan', (tester) async {
    // Past first-run onboarding so the app boots to Beranda.
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appStartupProvider.overrideWith((ref) async {}),
          bibleRepositoryProvider.overrideWithValue(_FakeBible()),
          planRepositoryProvider.overrideWithValue(_FakePlan()),
          progressRepositoryProvider.overrideWithValue(_FakeProgress()),
        ],
        child: const KoinoniaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Koinonia'), findsWidgets);
    // With no plan, the home invites setup.
    expect(find.text('Atur rencana'), findsWidgets);
  });
}
