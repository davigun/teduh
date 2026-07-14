# Koinonia — Flutter Architecture

A scalable, offline-first architecture for **Koinonia**: an Indonesian Bible reader built around a daily reading rhythm, designed so the deferred "read together" layer (Firebase) drops in later **without a rearchitect**.

This plan was produced by a 6-stream design pass and an adversarial review; the **Decisions Log** at the end records every contradiction that was reconciled into a single answer.

---

## 1. Principles that drive the structure

1. **The passage is the product.** Reading is the immersive surface; everything else is chrome that recedes.
2. **Offline is permanent, not a fallback.** The full experience runs with the radio off. Network is only ever an enhancement.
3. **Build for "together," ship "alone" cleanly.** Design the seams for sync now, but ship no broken/empty social UI and no speculative sync machinery.
4. **Pure domain.** Business logic (plan engine, streak) is plain Dart with an injected clock: trivially testable, framework-free, and untouched by any future Firebase swap.
5. **Right-sized for a solo dev.** Clean architecture *lite*: three real layers, codegen where it pays, no DDD ceremony, no `Either`/`dartz`.

---

## 2. Architecture at a glance

```
┌──────────────────────────────────────────────────────────────┐
│  features/ (presentation)   design/        l10n/              │
│  Riverpod controllers + widgets, per feature                  │
│            │ depends on ▼ (interfaces + provider symbols only) │
├──────────────────────────────────────────────────────────────┤
│  domain/  (PURE DART)                                          │
│  entities · repository INTERFACES · usecases · services       │
│            ▲ implemented by ▼                                 │
├──────────────────────────────────────────────────────────────┤
│  data/    drift (2 DBs) · mappers · repository IMPLS · no-op  │
│           SyncService · interface-typed Riverpod providers     │
└──────────────────────────────────────────────────────────────┘
   app/ = composition root (wires everything, owns router + ProviderScope)
   core/ = cross-cutting leaf utils (Clock, errors, constants)
```

**Dependency rules (enforce with `riverpod_lint` + import lints):**

| Layer | May import |
|---|---|
| `app/` | everything (composition root only) |
| `features/` | `domain`, `design`, `core`, `l10n`, and provider **symbols** from `data` (never `*Impl`/drift types) |
| `data/` | `domain`, `core` |
| `design/` | `core`, `l10n` |
| `domain/` | **nothing framework** — pure Dart + `meta`/`equatable`/`freezed` annotations only |
| `core/` | pure Dart + minimal Flutter |

Hard rule: a feature that imports a drift-generated row or a concrete `*Impl` has broken the seam. Bind only to domain interfaces and the provider that yields them.

---

## 3. Folder structure (`lib/`)

```
lib/
  main.dart                      # preload SharedPreferences, build ProviderScope overrides, runApp
  app/                           # COMPOSITION ROOT (may touch every layer)
    bootstrap.dart
    app.dart                     # KoinoniaApp: MaterialApp.router, single active ThemeData, locale 'id'
    startup/app_startup.dart     # appStartupProvider (FutureProvider) + AppStartupGate (warm splash)
    router/
      app_router.dart            # goRouterProvider; StatefulShellRoute (4 tabs); reader/plan above shell
      routes.dart
  core/
    time/clock.dart              # ONE Clock: nowLocal() + nowUtc(); clockProvider (overridable in tests)
    time/calendar_date.dart      # date-only value object; daysBetween via UTC-midnight
    errors/app_exception.dart    # sealed AppException (+ id() → Indonesian copy catalog)
    constants/ · logging/ · extensions/
  domain/                        # PURE DART. zero IO, zero Flutter.
    entities/                    # freezed: BibleBook, BibleRef, Verse, VerseSpan, Chapter,
                                 #          ReadingPlan, DailyReading, DayCompletion, Streak,
                                 #          ReaderPreferences, BookAvailability
    repositories/                # ABSTRACT: BibleRepository, PlanRepository, ProgressRepository
                                 #           (SyncService lives here too — no-op marker for now)
    services/                    # SequentialPlanEngine, StreakCalculator (pure)
    usecases/                    # getTodaysReading, markTodayRead, generatePlan, watchStreak
  data/
    database/
      bible/bible_database.dart  # drift, READ-ONLY, background isolate, migrations neutralized
      app/app_database.dart      # drift, WRITABLE user state (plans, progress)
      asset_db_installer.dart    # copy bible.db asset → app-support dir, version-checked
    mappers/                     # drift rows ↔ domain entities (incl. CalendarDate round-trip)
    repositories/                # *_impl.dart + interface-typed @riverpod providers
      sync_service_local.dart    # no-op SyncService (the swap point)
    providers.dart               # appDatabaseProvider, bibleDatabaseProvider (keepAlive infra)
  design/                        # DESIGN SYSTEM (depends on core/l10n only)
    theme/                       # ReadingTheme enum, KoinoniaColors ThemeExtension, appThemeFor(mode)
    tokens/                      # colors (OKLCH→const sRGB), typography, spacing, radii, motion
    widgets/                     # PrimaryButton, AppScaffold, EmptyState, ChapterChip,
                                 # StreakRing, CompletionCheck (the mark-read bloom; reused later)
  features/
    home/        application/{home_controller, todays_reading_provider}  presentation/{home_screen, widgets/*}
    reader/      application/{reader_controller, reader_settings_controller}  presentation/{reader_screen, widgets/*}
    library/     application/library_controller  presentation/{library_screen, widgets/{book_tile, chapter_grid}}
    plan/        application/{plan_controller, plan_setup_controller}  presentation/{plan_screen, plan_setup_screen}
    progress/    application/progress_controller  presentation/{progress_screen, widgets/completion_calendar}
    settings/    application/settings_controller  presentation/{settings_screen, about_screen}  # about = TSI attribution
    onboarding/  presentation/onboarding_screen   # first-run; gated by a flag, NOT by "no plan"
  l10n/arb/{app_id.arb (template, Bahasa Indonesia), app_en.arb}   # gen-l10n via root l10n.yaml
```

---

## 4. Domain layer

### Entities (freezed, pure)

- `BibleBook { String code /* OSIS: GEN, MAT */, int order /* 1..66 */, String namaIndonesia, Testament testament, int chapterCount }` — canonical, **immutable**.
- `BookAvailability { String code, bool isAvailable }` — render-time TSI status, **separate** from `BibleBook`.
- `BibleRef { String bookCode, int chapter }` · `Verse { int number, String text, List<VerseSpan> spans }` · `VerseSpan { int start, int end, SpanKind kind /* wordsOfChrist, poetry, footnote */ }`.
- `Chapter { BibleRef ref, String? headingBefore, List<Verse> verses }`.
- `ReadingPlan { String id /* uuid */, BibleRef start, BibleRef end, int chaptersPerDay, CalendarDate startDate, DateTime updatedAt }`.
- `DailyReading { int dayIndex, List<BibleRef> chapters }` — **computed, not stored**.
- `DayCompletion { String id /* uuid */, String? planId, CalendarDate localDate, BibleRef passage, DateTime completedAt /* UTC */, DateTime updatedAt /* UTC */ }`.
- `Streak { int current, int longest, CalendarDate? lastReadDate, bool isActive }`.

> **The addressable key is the OSIS `code` (String), everywhere** — repository signatures, `BibleRef`, plan fields, and the `/read/:bookCode/:chapter` route. `order` exists only for sorting. (Resolves the bookId String-vs-int split.)

### Repository interfaces (the seam)

```dart
abstract interface class BibleRepository {
  Future<List<BibleBook>> books();
  Future<List<BookAvailability>> availability();
  Future<Chapter> chapter(BibleRef ref);            // throws ChapterUnavailable for not-yet-released books
}
abstract interface class PlanRepository {
  Stream<ReadingPlan?> watchActivePlan();
  Future<void> save(ReadingPlan plan);
}
abstract interface class ProgressRepository {
  Stream<Set<CalendarDate>> watchCompletedDates();  // streak source; logic stays in domain
  Future<void> markRead(DayCompletion c);
}
abstract interface class SyncService {                // NO-OP in MVP; documented full surface in §7
  Stream<SyncStatus> watchStatus();                  // returns const offline now
}
```

### The two algorithms (pure, deterministic)

**Reading-plan engine** — `SequentialPlanEngine` builds the chapter spine from **canonical** chapter counts (availability is *never* consulted), then:

```
universe   = ordered [BibleRef] from plan.start..plan.end using BibleBook.chapterCount   // availability-agnostic
dayIndex   = CalendarDate.daysBetween(plan.startDate, clock.nowLocal())                   // date-anchored, deterministic
todaysRefs = universe[ dayIndex*pace : (dayIndex+1)*pace ]                                // pace = chaptersPerDay
```

Because the spine uses immutable canonical counts, the day→passage map is **stable forever** and future-syncable — no need to materialize a `plan_days` table. Unavailable chapters simply render with a "segera" notice when opened. (Resolves: availability-in-math, and materialized-vs-pure plan.)

**Streak** — `StreakCalculator` walks the **global** set of distinct completion `CalendarDate`s (across all plans, so switching plans never resets it):

```
sorted desc; current = run of consecutive days ending today-or-yesterday   // graceDays = 0 in MVP
isActive = lastReadDate ∈ {today, yesterday}                               // a streak survives until end of next day
```

`graceDays` is a documented one-line future tweak; MVP is strict-consecutive with the natural yesterday-still-counts rule. (Resolves the 3-way grace disagreement.)

**Clock discipline:** calendar/day math uses `clock.nowLocal()` → `CalendarDate`; instants (`completedAt`/`updatedAt`) use `clock.nowUtc()`. `CalendarDate.daysBetween` normalizes both ends to `DateTime.utc(y,m,d)` to kill DST 23h/25h off-by-ones. A unit test crosses local midnight at a non-UTC offset.

---

## 5. Data layer

**drift over sqflite** — compile-checked SQL, typed mapping, tested migrations, reactive `.watch()` that pairs with Riverpod, background-isolate execution.

**Two physically separate databases:**

| DB | Mode | Contents | Lifecycle |
|---|---|---|---|
| `bible.db` | **read-only**, copied from asset | `books`, `verses`, `headings`, `meta` | replaced wholesale on content version bump; never migrated |
| `app.db` | writable | `plans`, `reading_progress` | migrated additively as features land (sync columns in P2) |

> Device-local UI prefs (theme, reading size, reminder, onboarding-done, last-read position) live in **SharedPreferences** — preloaded synchronously in `main()` so there is no theme flash and no async settings table. They are intentionally **not** synced. (Resolves settings source-of-truth + theme-flash.)

### `bible.db` schema (built offline, shipped as asset)

```sql
CREATE TABLE books   (code TEXT PRIMARY KEY, ord INT, nama TEXT, testament TEXT,
                      chapter_count INT, is_available INT);          -- ALL 66 books, even unreleased OT (is_available=0)
CREATE TABLE verses  (book_code TEXT, chapter INT, verse INT, text TEXT,
                      spans TEXT,                                     -- nullable JSON: char-offset wj/poetry/footnote
                      PRIMARY KEY (book_code, chapter, verse)) WITHOUT ROWID;
CREATE TABLE headings(book_code TEXT, chapter INT, before_verse INT, text TEXT);
CREATE TABLE meta    (key TEXT PRIMARY KEY, value TEXT);             -- license (CC BY-SA 4.0), schema_version, verse_count
CREATE INDEX ix_verses_chapter ON verses(book_code, chapter);
```

Chapter query: `SELECT verse, text, spans FROM verses WHERE book_code=? AND chapter=? ORDER BY verse`.

Red-letter (words of Christ) is a **char-offset span**, not a per-verse boolean — a verse can be partly Jesus' words. The renderer layers `spans` over the canonical `text`. (Resolves red-letter sub-verse loss + missing headings.)

### `app.db` schema (MVP)

```sql
CREATE TABLE plans            (id TEXT PRIMARY KEY, start_book TEXT, start_chapter INT,
                              end_book TEXT, end_chapter INT, chapters_per_day INT,
                              start_date TEXT,         -- 'YYYY-MM-DD' pure date (round-trips, never an instant)
                              is_active INT, updated_at TEXT);
CREATE TABLE reading_progress (id TEXT PRIMARY KEY,   -- uuid v4 (genuine cheap seam)
                              plan_id TEXT,            -- nullable: free reading allowed
                              book_code TEXT, chapter INT, day_index INT,
                              local_date TEXT,         -- 'YYYY-MM-DD' device-local, captured at mark time
                              completed_at TEXT,       -- UTC instant
                              updated_at TEXT,         -- UTC; last-write-wins key for future sync
                              UNIQUE(plan_id, day_index));
```

`uuid` PKs + `updated_at` are the **only** sync-prep we ship now (they avoid a painful backfill later). No outbox, no dirty flags, no identity/group/nudge tables — those are additive drift migrations in P2, not a rearchitect. (Resolves outbox/identity over-engineering + data-loss risk.)

### Critical install/open details (fixes from review)

- **Never open from the asset bundle** — an asset is not a file. The installer copies bytes to **`getApplicationSupportDirectory()`** (not Documents → avoids iCloud backup bloat; set the iOS no-backup flag).
- Build the asset with `PRAGMA journal_mode=DELETE` + `VACUUM` so it is a single clean file with no `-wal`/`-shm` sidecars; bake `PRAGMA user_version` and compare it against a Dart const to decide re-copy on upgrade.
- Open `bible.db` **read-only on a background isolate** (`NativeDatabase.createBackground` with `OpenMode.readOnly` + `PRAGMA query_only`) so chapter queries never jank the reading surface.
- **Neutralize drift migrations** on the read-only DB (a `MigrationStrategy` whose `onCreate`/`onUpgrade` throw) and guarantee `user_version == schemaVersion` via the installer, so drift never tries to write to a `query_only` handle and crash.

### `tool/build_bible_db.dart` (one-time, offline pipeline)

A pure-Dart CLI that **shares the same drift table definitions**, parses the TSI **USFX** (single XML, via `package:xml`) from eBible.org (id `ind`), and emits `assets/db/bible.db`: full 66-book canon (unreleased OT books inserted with `is_available=0` and correct canonical `chapter_count`), `wj`/poetry/heading/footnote captured as spans, `meta` carries the CC BY-SA license string. New TSI OT releases become a **data-only rebuild** — no app change.

---

## 6. Presentation & theming

**Riverpod (codegen, `@riverpod`) everywhere.** Pick the primitive by two questions — *async build?* → `AsyncNotifier`; *user-mutated?* → `Notifier`; else a plain function provider. `autoDispose` by default; per-chapter providers are `autoDispose` families. Use the generic `Ref` (Riverpod 3). No `Either`/`Result` — `AsyncValue` + typed `AppException`.

**Navigation (go_router):** `StatefulShellRoute.indexedStack` for the 4-tab bottom nav — **Beranda / Baca / Rencana / Pengaturan** — preserving per-tab scroll. **Reader** (`/read/:bookCode/:chapter`) and **Plan setup** are top-level routes *above* the shell (immersive, no bottom nav). The `/read/...` path param doubles as the future FCM deep-link.

> **Redirect rule (fix):** only the **Beranda (Home)** tab requires an active plan; Library and Reader are always reachable (free reading is a first-class path — `reading_progress.plan_id` is nullable). First-run onboarding is driven by a `onboardingCompleted` pref flag, **not** by "no plan," so reading is never walled. `hasActivePlanProvider` is a keepAlive **sync** provider seeded during the startup gate; the router is built only after `appStartupProvider` resolves.

**Theming:** three precomputed `ThemeData` selected by `appThemeFor(mode)` — **do not** use `darkTheme`/`themeMode` (that only toggles two). Pagi + Senja are `Brightness.light`; Malam is `Brightness.dark`. Colors are a `KoinoniaColors` `ThemeExtension` (with `lerp` for a smooth cross-fade). **OKLCH → const `Color(0xFF…)` is precomputed at build time** by a small script into a contrast-verified table (Flutter `Color` is sRGB; runtime OKLCH math is wasted). Typography is a color-agnostic static class; the reading-size step is applied **locally in the Reader** so resizing scripture doesn't rebuild app-wide `ThemeData`.

**Scripture rendering:** each paragraph is a `Text.rich` inside a `ListView.builder` (lazy, reflows as prose, gives scroll anchors). Superscript verse numbers use **`WidgetSpan`** (not font `sups`, which is unreliable in these fonts); red-letter uses a colored `TextSpan` derived from the verse `spans`; wrap the subtree in `RepaintBoundary`; a golden test at scale 1.3 with a long chapter (e.g. Ps 119) guards baseline drift.

**The one delight:** `CompletionCheck` animates a `gold→success` bloom + streak tick on mark-read, state-driven by the drift stream, and **snaps to final state under `prefers-reduced-motion`**. It is built generically so the future "friends read today" row reuses the same atom.

**Fonts are bundled** (`assets/fonts/`), declared in `pubspec.yaml` — no `google_fonts` runtime fetch (offline-first). Scripture/display = a humanist reading serif; UI = a clean sans. (The mockup proves the direction with macOS Iowan Old Style/Charter; the shipped app bundles its own e.g. Newsreader + Inter.)

---

## 7. The "together" seam (deferred, right-sized)

What ships **now** is the *minimum that prevents a rearchitect*, nothing more:

1. **Domain repository interfaces** (above) — features already depend only on these.
2. **`uuid` PKs + `updated_at`** on `plans`/`reading_progress` — globally unique, last-write-wins ready.
3. **One `syncServiceProvider`** returning a no-op `LocalOnlySyncService`.
4. **`communityEnabledProvider` (const `false`)** gating any social surface; `companions_row` renders nothing; no broken/empty UI.

**Documented (not built) target** — the eventual `SyncService` surface and Firestore model from the research (`users`, `groups`, `groups/{id}/progress`, `nudges`), turned on by overriding `syncServiceProvider` with a `FirebaseSyncService` in a separate `main_together.dart` entrypoint. Adding the group/nudge tables, identity, and an outbox at that point are **additive drift migrations**, covered by the schema-snapshot tests — not a rearchitect. We deliberately do **not** implement the DTOs, outbox, dirty flags, or identity now.

---

## 8. Cross-cutting concerns (don't forget — surfaced by review)

- **Day rollover:** an `AppLifecycleListener` + a midnight timer invalidate the streak and today's-reading providers on resume/at midnight, so "today's passage" and `isActive` never go stale while the app stays open.
- **Local daily reminder (P1, fully offline):** `flutter_local_notifications` `zonedSchedule` with `timezone` init + a permission flow (iOS + Android 13+ `POST_NOTIFICATIONS`), surfaced in Settings. FCM push is a P3 enhancement, never a dependency of the habit.
- **Errors → gentle Indonesian copy:** `AppException.id()` maps to a Bahasa Indonesia catalog; empty states teach the next action ("Belum ada bacaan hari ini — mulai rencanamu") and never say "Tidak ada data".
- **Continue reading:** the reader controller persists last-read `bookCode`/`chapter` to prefs; surfaced as "Lanjutkan" on Home.
- **Attribution (legal):** `about_screen` shows the TSI CC BY-SA 4.0 copyright/source/license — a non-removable surface.

---

## 9. Dependencies (`pubspec.yaml`)

> Versions reflect early-2026 stable; **confirm latest at scaffold time**. The Riverpod 3 version skew below is intentional and co-released — do not "fix" it to matching majors.

| Package | Purpose |
|---|---|
| `flutter_riverpod ^3.x` · `riverpod_annotation ^4.x` | state mgmt + DI |
| `riverpod_generator ^4.x` · `riverpod_lint` (native analyzer plugin, **no** custom_lint) | codegen + lints |
| `drift` · `drift_flutter` | typed local DB on a background isolate (pulls native sqlite3 transitively — do **not** declare `sqlite3_flutter_libs` directly) |
| `path` · `path_provider` | app-support dir for the DB copy |
| `go_router` | routing + deep links |
| `freezed` + `freezed_annotation` · `json_serializable` | immutable entities |
| `build_runner` | codegen runner |
| `shared_preferences` | device-local prefs (theme, size, reminder, onboarding, last-read) |
| `flutter_localizations` + `intl` | l10n (Bahasa Indonesia default) |
| `flutter_local_notifications` + `timezone` | offline daily reminder (P1) |
| `uuid` | progress/plan ids |
| `flutter_animate` *(optional)* | the mark-read bloom |
| **deferred P2+:** `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_messaging` | the together layer |

Pin Flutter with **FVM** for reproducible solo-dev/CI builds.

---

## 10. Testing & tooling

- **Highest ROI — pure domain unit tests (`dart test`, ms):** plan engine (determinism, boundaries, availability-agnostic), streak (consecutive, yesterday-grace, the midnight/DST crossing).
- **Repository tests:** drift in-memory (`sqlite3.openInMemory` via the bundled lib so host == CI engine; document the CI image).
- **Widget + golden tests:** the reading surface is the product — golden the Reader in all three themes and at scale 1.3.
- **Codegen hygiene:** gitignore `*.g.dart`/`*.freezed.dart`/generated l10n and regenerate in CI with a "codegen clean" guard; **commit** `drift_schemas/*.json` (migration history) and golden PNGs (visual baselines).

---

## 11. Performance

- Render a chapter as **one bounded `Text.rich`** (flowing prose); reserve `ListView/GridView.builder` for long lists (books, chapters, schedule). Never load the whole Bible into memory.
- Per-chapter `autoDispose` family providers free memory on navigation.
- `RepaintBoundary` around the scripture subtree; `const` widgets throughout chrome.
- Read-only `bible.db` on a background isolate; the multi-MB asset copy happens behind the startup gate (warm splash), never on the first-frame path.

---

## 12. Phased roadmap

| Phase | Scope | Backend |
|---|---|---|
| **P0 — Scaffold** | Project, `design/` system (3 themes, tokens, core widgets), router shell, startup gate, Clock, l10n skeleton, `tool/build_bible_db.dart` → `bible.db` asset. | none |
| **P1 — Offline reader (the MVP)** | Library (books/chapters, "segera" handling), Reader (themes, size, red-letter, headings, resume), sequential **Plan** setup + today's reading, **mark read** + local **streak/progress**, offline daily **reminder**, Settings + TSI **attribution**, onboarding. `SyncService` = no-op. **Shippable.** | none |
| **P2 — Together** | `FirebaseSyncService` behind the existing provider; anonymous/Google auth; join group by code; mirror progress to Firestore; live "siapa yang sudah baca hari ini". Additive `app.db` migration (identity/group/mirror/outbox). | Firebase (free tier) |
| **P3 — Nudges** | FCM tokens + one Cloud Function for the nudge; iOS APNs (.p8 key). | Firebase Blaze (~$0) |
| **P4 — Polish** | More translations (WEB/BSB English, full TSI OT as it releases — data-only), structured plans (M'Cheyne), search, bookmarks/highlights, audio. | — |

---

## 13. Decisions Log (reconciled contradictions)

| # | Decision | Why |
|---|---|---|
| 1 | **Book key = OSIS `code` (String)** + `ord` int for sorting | language-independent, sync-stable, debuggable; one key across repo/route/schema |
| 2 | **Plan index math is availability-agnostic** (canonical counts) | a future TSI OT release must not shift existing day→passage maps |
| 3 | **Pure `SequentialPlanEngine`, no materialized `plan_days`** | engine is O(chapters), deterministic, testable; canonical counts make it already stable |
| 4 | **Theme + reading-size in SharedPreferences only** (sync, preloaded) | kills theme flash, no async settings table, device prefs aren't synced |
| 5 | **Streak = strict consecutive + yesterday-grace (`graceDays=0`)** | one rule in `StreakCalculator`; gentle enough; grace is a future one-liner |
| 6 | **`reading_progress`: uuid PK + `updated_at`; nullable `plan_id`** | cheap genuine sync seam + free reading; no premature dirty/identity columns |
| 7 | **No outbox / SyncEngine / identity / group tables in MVP** | adding them later is an additive migration, not a rearchitect |
| 8 | **Red-letter + poetry + footnotes = char-offset `spans` JSON** | sub-verse words-of-Christ can't be a per-verse boolean |
| 9 | **`design/` is a real top-level layer** | single home for DESIGN.md tokens, no cross-layer coupling |
| 10 | **Install to `applicationSupport`, read-only, background isolate, migrations neutralized** | no iCloud bloat, no UI jank, no crash writing to a `query_only` handle |
| 11 | **Three explicit `ThemeData` via `appThemeFor`** (not `themeMode`) | Material's `themeMode` only toggles two; Koinonia has three |
| 12 | **Startup gate owns DB install/open; `main()` only preloads prefs** | the multi-MB copy never blocks the first frame |
| 13 | **One `Clock` (`nowLocal` + `nowUtc`)** | calendar math local, instants UTC; no off-by-one near midnight |
| 14 | **Riverpod 3 + generic `Ref` + native `riverpod_lint`** | current idiom; the 3.x/4.x version skew is intentional |
| 15 | **Read freely without a plan; onboarding gated by a flag** | "the passage is the product"; reading is never walled behind plan creation |

---

## 14. P0 build notes (as-built)

P0 is scaffolded, analyzes clean, and boots (widget smoke test green). A few pragmatic deviations were forced by the current Flutter SDK (Dart 3.9.2) dependency matrix; each has a clear path forward in P1.

- **Stack as-built:** `flutter_riverpod 3.3.2`, `go_router 17.2.3`, `shared_preferences`, `intl 0.20.2`, `flutter_localizations`, `meta`. Build-tool deps: `xml`, `sqlite3` (dev).
- **Riverpod providers are written by hand** (`NotifierProvider` / `Provider` / `FutureProvider`), not via `@riverpod` codegen. Reason: `riverpod_generator`/`riverpod_lint` for annotation 4.x pull an `analyzer`/`meta` that conflicts with the SDK-pinned `meta 1.16.0` (the removed `_macros` era). Manual providers are fully supported; revisit codegen in P1 behind a `dependency_overrides: { analyzer: ^7.x }` if desired.
- **Codegen (freezed / drift / json) is deferred to P1** (the data + domain layers). Expect the same analyzer conflict when adding `drift_dev`; resolve with a `dependency_overrides` for `analyzer`, keep **Freezed 3.x**, and do **not** add `riverpod_lint` (it forces Freezed 2.x).
- **l10n:** `lib/l10n/arb/app_id.arb` + `l10n.yaml` are in place (Bahasa Indonesia source of truth). P0 screens use inline Indonesian strings; wiring generated `AppLocalizations` is a small P1 follow-up.
- **`tool/build_bible_db.dart`** uses raw `package:sqlite3` + `package:xml` (not drift codegen) and emits the exact DDL from §5, so it shares the schema by convention. It carries the full 66-book canon (unreleased OT books → `is_available=0`).
- **Fonts** (`Newsreader`, `Inter` variable TTFs) are bundled in `assets/fonts/` and declared in `pubspec.yaml` (offline, no runtime fetch).
- **Verification:** `flutter analyze` → no issues; `flutter test` → smoke test passes (app boots to Beranda with today's reading).

### P1 build notes (as-built) — the offline reader

P1 is implemented, analyzes clean, and is covered by 17 passing tests (pure plan-engine + streak, a widget smoke test, and integration tests against the real `bible.db`).

- **Data layer uses raw `package:sqlite3`, not drift.** `drift_dev` shares the same incompatible analyzer toolchain as the Riverpod codegen, so the data layer is hand-written SQL with manual row→entity mappers (`lib/data/repositories.dart`). Same engine, no codegen. Trade-offs vs the drift plan: reactivity is via **Riverpod provider invalidation** (`markTodayReadAction` / `savePlanAction` invalidate the derived providers) instead of `.watch()`; migrations are a manual `PRAGMA user_version` switch in `lib/data/database/databases.dart`. Adopt drift later if the ecosystem catches up with this SDK.
- **Real TSI is bundled.** `tool/build_bible_db.dart` was run on the TSI USFX (eBible id `ind`) → `assets/db/bible.db` (20,650 verses, 48/66 books, 1,976 section headings, 4.58 MB). The bible.db is installed to applicationSupport read-only on first run.
- **TSI specifics handled:** the OT is partial (Mazmur/Ayub/etc. absent → rendered "segera"); **TSI has no `<wj>` red-letter markup**, so red-letter is simply absent for this translation (the renderer + char-offset span model still support it for future translations). Verse ranges (`id="2-6"`, 679 of them) parse to a start number + a `label` column shown as the verse marker.
- **Domain is pure Dart (no freezed):** entities are plain immutable classes; `SequentialPlanEngine` + `StreakCalculator` are pure and unit-tested (availability-agnostic indices, DST-safe day math, gentle yesterday-grace streak).
- **Riverpod note:** the nullable AsyncValue accessor in v3 is `.value` (not `.valueOrNull`); repos resolve via `databasesProvider.requireValue` behind the startup gate.
- **Wired end-to-end:** Beranda (today's reading + streak + week dots), Alkitab (real books, "segera"), Pembaca (real chapter render, headings, prev/next, mark-read), Rencana setup (live engine preview → save) + summary, Pengaturan (working theme switch), Tentang (TSI attribution). `SyncService` stays a no-op.
- **P1 polish — done:** reading-size control + verse-number toggle (persisted, applied live in the reader's settings sheet and Settings); first-run **onboarding** (router redirect on a prefs flag); **daily reminder** via `flutter_local_notifications` 20.x + `timezone` + `flutter_timezone` (timezone-resolved, inexact daily schedule, permission flow, switch + time picker in Settings); plan **start-point picker**.
  - *Notification platform caveats (untested on device):* Android needs a notification icon (`@mipmap/ic_launcher` used) and the plugin's manifest receiver; iOS needs the default AppDelegate plugin registration from `flutter create` and the runtime permission prompt (wired). Exact-alarm permission avoided by using `AndroidScheduleMode.inexactAllowWhileIdle`. fln 20.x uses **named** params (`initialize(settings:)`, `zonedSchedule(id:…, scheduledDate:…, notificationDetails:…)`, `cancel(id:)`); `flutter_timezone` returns `TimezoneInfo` (use `.identifier`).
- **Still open (P2 / nice-to-have):** reader golden tests, plan "resume from last read", then P2 Firebase `FirebaseSyncService` behind `syncServiceProvider`.
