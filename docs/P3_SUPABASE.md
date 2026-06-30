# P3 — "Read Together" on Supabase

How Teduh adds accounts + a shared group reading rhythm, replacing the originally-planned Firebase layer with **Supabase** (managed Postgres + Auth + Realtime). Produced from a 5-stream design pass + adversarial review; the **Decisions Log** records every contradiction reconciled into one answer.

**Non-negotiable invariant:** reading stays 100% offline with no account. Supabase only *adds* the social layer, dropped into the existing `SyncService` seam (`ARCHITECTURE.md` §7) with an **additive** sqlite migration — no rearchitect. (Note: bundling AYT already made Teduh non-commercial; Supabase's free tier is fine.)

---

## 1. The core idea (answers "which stage is the group on, so others can follow if behind")

The reading plan is **deterministic**: `dayIndex = daysBetween(plan.startDate, today)`, and `SequentialPlanEngine` maps any `dayIndex` to the *same passage* for everyone via canonical chapter counts. So if a group **shares one plan** (same start/end/pace/startDate), the entire "who's ahead / behind / catch up" problem reduces to **comparing integers** — no server-side passage math, no timezone math on the server.

- **A group _is_ a shared plan.** The plan fields live on the `groups` row. On join, a member adopts the group's plan locally.
- **Each member's "stage" = their contiguous high-water day index** — the latest day with *no gaps behind it* (`max consecutive completed from day 0`). Ungameable, and `hw + 1` is exactly "the next day to read." (We keep `furthestCompleted` as a descriptive extra, but stage = high-water.)
- **The group's headline stage = today's `scheduledDayIndex`** (`engine.dayIndexFor(startDate, today)`), the same for all members. "Behind" is measured against the **schedule**, not the fastest reader — so one keen member can't make everyone else feel behind. (Leader / median / trailing are shown descriptively.)
- **"Kamu tertinggal N hari"** = `scheduledDayIndex − myHighWater`, counting only **fully-elapsed** overdue days. "Today not read yet" is a separate gentle state, *not* "behind" (with a 1-day zone-skew tolerance, matching the streak's yesterday-grace).
- **Catch up = navigation only** ("Lanjutkan" → next uncompleted day). We never auto-mark days the user didn't read.

Everything the group view shows is computed **on-device** from a local mirror of each member's day indices — so it works offline and is consistent between Beranda and the group screen.

---

## 2. Identity model (MVP: tiers 0 → 2; anonymous deferred)

| Tier | Supabase session | What works |
|---|---|---|
| **0 — Local (default)** | none | Full reading, plans, progress, streak. The app never auto-signs-in. |
| **2 — Account** | email / Google / Apple | Tier 0 + create/join groups, see members' stages, catch up across devices. |

- **Anonymous (Tier 1) is cut from the MVP** (deferred to P3c). The reviewer flagged it as the highest-edge-case auth path (PKCE link flow, manual-linking config, skip-nonce, abandon-anon warnings) for little MVP value. Ship `0 → 2` only.
- **Reading providers never watch auth.** Auth gates *only* the `/together` subtree. Do **not** put auth in the global `go_router` redirect.
- **`AuthController` is a `Notifier<AuthSnapshot>`** seeded synchronously from `auth.currentSession` and updated by `onAuthStateChange` — correct tier on the first frame, even offline. (Matches the existing `app_prefs.dart` Notifier pattern.)
- **Sign-out keeps local reading data**; only the account-scoped social mirror is cleared (prevents one user's group data leaking to the next on a shared device). `signOut(scope: local)`.
- **`SupabaseClient?` is a nullable provider** overridden in `main()`. No keys / init failure / offline build → `null` → social disabled, `syncServiceProvider` returns the existing `LocalSyncService`. This makes the offline-first guarantee mechanical.

```dart
// init is offline-safe (restores local session only); guard so it can never take reading down.
try {
  await Supabase.initialize(url: env.url, anonKey: env.anonKey,
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce));
} catch (_) { /* run in Tier 0 */ }
```

Native id-token sign-in (`google_sign_in` v7 + `sign_in_with_apple` → `auth.signInWithIdToken`) — no browser bounce. **Apple Sign In is mandatory** once Google is offered (App Store 4.8). Apple requires a hashed nonce (raw → Supabase, sha256 → Apple); iOS native Google sends no nonce → enable "Skip nonce checks" on the Google provider.

---

## 3. Server schema + RLS (reconciled — one schema)

**One progress table, natural-key PK, no `id` column** (the local uuid is purely a local outbox pointer and is *not* sent in the upsert):

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Pembaca',
  avatar_emoji text not null default '📖',
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,             -- looked up only via RPC, never by SELECT
  created_by uuid references auth.users(id) on delete set null,   -- NULLABLE (so user-delete works)
  -- the shared plan (immutable after creation):
  start_book text, start_chapter int, end_book text, end_chapter int,
  chapters_per_day int, start_date date,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id  uuid references auth.users(id)  on delete cascade,
  role text not null default 'member',        -- 'owner' | 'member'
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table public.reading_progress (
  user_id   uuid not null references auth.users(id) on delete cascade,
  plan_id   text not null,                     -- = group id for group plans (members align here)
  day_index int  not null,
  group_id  uuid references public.groups(id) on delete set null,  -- history survives group deletion
  book_code text, chapter int,
  local_date date,
  completed_at timestamptz,
  updated_at   timestamptz not null,           -- client-authoritative; LWW key
  primary key (user_id, plan_id, day_index)
);
```

> The single most important alignment: **for a group plan, the local `plan_id` is overwritten with the group id on join**, so member A's "day 5" and member B's "day 5" collide on the same natural key. Free-reading rows (`plan_id` null locally) are **not synced**.

**RLS (the load-bearing part):**
- Break the classic `group_members` self-referential recursion with **`SECURITY DEFINER` helpers** — `is_group_member(gid)`, `is_group_owner(gid)` — each `language sql stable security definer set search_path = ''` and fully-qualified (`public.group_members`, `auth.uid()`). **Do not `FORCE` RLS** (it re-arms recursion inside the helpers). Exactly one definition of each helper.
- `reading_progress`: SELECT where `user_id = auth.uid() OR public.is_group_member(group_id)`; INSERT/UPDATE only `user_id = (select auth.uid())`.
- `groups` / `group_members`: SELECT only via `is_group_member`. **No "select group by join_code" policy** (it would let clients enumerate groups). **No client INSERT on `group_members`.**
- **Join only via `join_group_by_code(code)` RPC** (`SECURITY DEFINER`): validates code, checks capacity with `FOR UPDATE` (closes the count-then-insert race), inserts membership atomically, returns the group + plan snapshot. Add a per-uid **rate limit** (brute-forcing a 6-char code to auto-join a small private group is the real threat).
- `profiles` created by an `AFTER INSERT` trigger on `auth.users` (`SECURITY DEFINER`, `search_path=''`). Capture Apple's first-authorization full name into `display_name` (Apple only sends it once).
- **Server `BEFORE`-write trigger clamps `updated_at ≤ now() + 1 min`** so a future-dated device clock can't permanently win LWW.
- **Group plan fields are immutable after creation** (restrict `groups` UPDATE of plan columns) — editing them would retroactively shift every member's `dayIndex → passage` map.
- Add `reading_progress`, `group_members` to the `supabase_realtime` publication; scope channel filters by `group_id`.

---

## 4. Offline-first sync (P3b dirty-flag, P3c realtime)

**Write path (never blocks the user):** `markRead` writes **local sqlite first** (instant, offline), sets `dirty = 1`, bumps `updated_at`; a **fire-and-forget** `pushPending()` upserts dirty rows to Supabase (LWW via `updated_at`). No network on the write path. (P3b uses a simple dirty-flag scan; the trigger-based outbox the design proposed is cut as over-engineering for 2–10 users.)

**IDs:** plan-day completions use a **deterministic uuid v5** (`v5(namespace, "planId#dayIndex")`) so re-marking a day coalesces under `INSERT OR REPLACE` without orphaning the dirty row. (v4 only for free-reading rows.) The server **never receives `id`** — its PK is the natural key.

**Read path:** P3c subscribes with `.stream()` (snapshot + live + auto-resubscribe, ideal for ≤10 members) to the active group's `reading_progress`; rows land in a **local mirror** (`group_member_progress`); the UI watches local only via a `groupMirrorRevision` `Notifier` the service bumps after each apply (matches the project's invalidate-to-refresh reactivity — no drift `.watch()`). On every `subscribed` event, run a `select(updated_at > cursor)` reconcile (Realtime can drop messages during a disconnect).

**First-sign-in backfill (the bug the reviewer caught — must implement):** on first sign-in (`prevOwner == null`), explicitly enqueue **all pre-existing** plan-day rows: `UPDATE reading_progress SET user_id = :uid, dirty = 1, updated_at = updated_at WHERE plan_id IS NOT NULL`, then `pushPending()`. Without this, weeks of offline history are silently lost server-side.

**One `SyncService` surface** (implemented by both `LocalSyncService` no-op and `SupabaseSyncService`):
```dart
abstract interface class SyncService {
  Stream<SyncStatus> watchStatus();           // {offline, syncing, synced} — unchanged enum
  Future<void> pushPending();                  // fire-and-forget drain of dirty rows
  Future<void> pull();                         // pull-to-refresh / backfill
  Future<void> activateGroup(String planId, String groupId);  // subscribe + mirror (P3c)
  Future<void> onSignedIn(String uid);         // first-sign-in backfill + adopt
  Future<void> onSignedOut();                  // clear social mirror, keep reading
}
```

**Consolidated `app.db` v2 migration (additive, one block, transactional):** add `user_id`, `group_id`, `dirty INT DEFAULT 0` to `reading_progress`; add tables `groups`, `group_members`, `group_member_progress` (single mirror), `sync_state`; bump `user_version`. `user_id`/`group_id` stay nullable so pre-account rows remain valid.

---

## 5. Phasing

| Phase | Scope | Risk |
|---|---|---|
| **P3a — Auth** | `supabase_flutter` + nullable client; email + native Google + Apple sign-in; `profiles` + trigger; account UI in Settings. **Zero behavior change for non-users.** | Low |
| **P3b — Groups + offline sync** | `groups`/`group_members` + `join_group_by_code` RPC; create + join-by-code UI; dirty-flag `pushPending` + pull-to-refresh; **first-sign-in backfill**; group screen shows member stages computed locally. | Medium |
| **P3c — Live + catch-up + polish** | Realtime `.stream()` mirror; live "siapa sudah baca hari ini" + "tertinggal N hari" on Beranda + group screen; catch-up nav; optional anonymous tier; push reminders. | Higher |

---

## 6. Decisions Log (reconciled contradictions)

| # | Decision | Why |
|---|---|---|
| 1 | **One server `reading_progress`**: natural-key PK `(user_id, plan_id, day_index)`, no `id` | 3 specs disagreed; natural key makes cross-device/cross-member rows collapse correctly; `id` is a local-only pointer |
| 2 | **Local `plan_id` ← group id on join** | aligns every member's day-N rows under one key (the only way "group stage" aggregates) |
| 3 | **Deterministic uuid v5** for plan-day ids (v4 for free reading) | re-marks coalesce under `INSERT OR REPLACE`; no orphaned dirty rows |
| 4 | **One `SyncService` surface**, both impls satisfy it | 3 incompatible surfaces would not compile against the auth bridge |
| 5 | **Nullable `SupabaseClient?` provider** | only nullable preserves offline-first; non-null throws in no-keys builds |
| 6 | **Keep `SyncStatus {offline,syncing,synced}`** | add `error`/`disabled` later; avoid churn now |
| 7 | **One consolidated v2 migration; one mirror table** | 3 divergent migrations + 2 mirror tables would corrupt state |
| 8 | **One `profiles` + one `is_group_member`** (`search_path=''`, qualified) | `CREATE OR REPLACE` made the insecure duplicate silently win |
| 9 | **Member stage = contiguous high-water; group stage = scheduledDayIndex** | honest, ungameable, gentle; "behind" vs schedule not vs leader |
| 10 | **Catch-up = navigation only** (`markDayReadAction`) | integrity: credit only days actually read |
| 11 | **Cut anonymous tier, trigger-outbox, server stage view, dual-realtime, separate `group_progress`** for MVP | over-engineered for 2–10 users; additive later |
| 12 | **`created_by` nullable + last-owner transfer; immutable group plan; join-code RPC w/ `FOR UPDATE` + rate-limit; `updated_at` clamp** | fixes the review's HIGH/MEDIUM correctness + security holes |

---

## 7. Security & cost

- The **anon key is public by design** (ships in the binary); **RLS is the only real guard**. Never ship the `service_role` key (not in the app, not in `--dart-define`).
- **No `build_runner`/codegen Supabase helpers** — they would reintroduce the analyzer/codegen conflict that forced manual providers here. `supabase_flutter` itself is runtime-only and safe. Verify `flutter pub get` resolves with `intl` pinned (`0.20.2`); relax to `^0.20.2` if the solver complains.
- **Free tier is fine** for 2–10-person groups (rows, MAU, realtime). Two caveats: free projects **auto-pause after ~7 days of no API calls** (first social action after a quiet week is slow; reading is unaffected — document or add a weekly keepalive), and only mint accounts when a user enters the social layer (don't inflate MAU with plain readers).

---

## 8. Open questions (decide before P3b)

1. **Late joiners:** a member joining on calendar day 20 of a fixed-startDate plan is instantly "tertinggal 19 hari" — demoralizing. Recommend: default group `startDate = today` on create (warn if past), and/or baseline a member's "behind" to their `joined_at`. **Pick one.**
2. **"Loncat ke hari ini"** leaves a gap, so high-water (and "behind") doesn't advance — intended/honest, but the copy must explain it ("Kamu ikut hari ini; masih ada N hari sebelumnya"). Confirm wording.
3. **Plan change on an existing group** is forbidden by default (immutable). Confirm that "change plan = new group" is acceptable UX.
