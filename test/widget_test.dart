import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teduh/app/app.dart';
import 'package:teduh/app/providers.dart';
import 'package:teduh/app/startup/app_startup.dart';
import 'package:teduh/core/time/calendar_date.dart';
import 'package:teduh/data/repositories.dart';
import 'package:teduh/domain/entities/bible.dart';
import 'package:teduh/domain/entities/plan.dart';
import 'package:teduh/domain/entities/progress.dart';
import 'package:teduh/domain/repositories.dart';

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
  Future<bool> isDayCompleted(int dayIndex) async => false;
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
        child: const TeduhApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teduh'), findsWidgets);
    // With no plan, the home invites setup.
    expect(find.text('Atur rencana'), findsWidgets);
  });
}
