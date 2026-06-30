# Supabase backend setup (for Teduh P3 "Read Together")

What you do in the Supabase dashboard + the SQL to paste. Split into **P3a (auth — do first)** and **P3b (groups + progress sync)**. Reading stays fully offline regardless; this only powers the social layer. See `docs/P3_SUPABASE.md` for the why.

> Security reminder: the **anon key is public** (it ships in the app) — RLS is the real guard. **Never** put the `service_role` key in the app or in `--dart-define`.

---

## 0. Create the project (5 min)

1. supabase.com → **New project**. Pick a region close to your users (e.g. Singapore for Indonesia). Save the DB password somewhere safe.
2. **Project Settings → API** → copy **Project URL** and **anon/public key**.
3. Put them in a git-ignored `env.json` (don't commit):
   ```json
   { "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "eyJ..." }
   ```
   Run/build with `flutter run --dart-define-from-file=env.json`. (No keys → the app runs in offline/local mode with social disabled — by design.)

---

## P3a — Auth

### Dashboard
0. **Anonymous (PRIMARY sign-in method) — REQUIRED.** Account model is anonymous-first: a device-local account from just a name. Enable **Authentication → Sign In / Providers → "Anonymous Sign-Ins" → ON** (in some dashboard versions it's under **Authentication → Providers → Anonymous**). Without this, "Lanjutkan" fails with `anonymous_provider_disabled`.
1. **Authentication → Providers → Email:** enable (optional durable upgrade path). For an MVP you can turn **"Confirm email" off** to skip the email round-trip (turn it on before a real launch).
2. **Authentication → URL Configuration → Redirect URLs:** add `io.teduh.app://login-callback` (used by OAuth + email links).
3. **Google** (optional durable upgrade; see "Google Sign-In (native)" below):
   - Google Cloud Console → create OAuth client IDs: one **Web** (this is the Supabase "Client ID") and one **iOS**.
   - Supabase → Auth → Providers → **Google**: paste the **Web** client ID + secret, and **enable "Skip nonce checks"** (iOS native Google sends no nonce).
   - The iOS client ID goes into the app's `google_sign_in` init.
4. **Apple** (mandatory on iOS once Google is offered — App Store 4.8):
   - Apple Developer → create a **Service ID** + **Sign in with Apple key**.
   - Supabase → Auth → Providers → **Apple**: fill Service ID / Team ID / Key.
   - Xcode → Signing & Capabilities → add **Sign in with Apple**.
5. iOS deep link: in `ios/Runner/Info.plist` add a URL scheme `io.teduh.app` (CFBundleURLTypes) so the redirect returns to the app.

### SQL — run in **SQL Editor** (creates the profile table + auto-create trigger)
```sql
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Pembaca',
  avatar_emoji text not null default '📖',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create policy "profiles_self_select" on public.profiles
  for select using ((select auth.uid()) = id);
create policy "profiles_self_update" on public.profiles
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- auto-create a profile on signup (works for every provider)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',
                           new.raw_user_meta_data->>'full_name', 'Pembaca'))
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();
```
That's all P3a needs server-side.

---

## P3b — Groups, members, progress, RLS, RPCs

Run this whole block in the SQL Editor (as the default `postgres` role).

```sql
-- ---------- tables ----------
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,
  created_by uuid references auth.users(id) on delete set null,   -- NULLABLE so user-delete works
  start_book text not null, start_chapter int not null,
  end_book text not null, end_chapter int not null,
  chapters_per_day int not null, start_date date not null,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id  uuid references auth.users(id)  on delete cascade,
  role text not null default 'member',         -- 'owner' | 'member'
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.reading_progress (
  user_id   uuid not null references auth.users(id) on delete cascade,
  plan_id   text not null,                      -- = group id for group plans (members align here)
  day_index int  not null,
  group_id  uuid references public.groups(id) on delete set null,
  book_code text, chapter int,
  local_date date,
  completed_at timestamptz,
  updated_at   timestamptz not null,            -- client clock; LWW key (clamped below)
  primary key (user_id, plan_id, day_index)     -- natural key; NO id column
);

-- ---------- membership helpers (break RLS recursion) ----------
create or replace function public.is_group_member(gid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members m
                 where m.group_id = gid and m.user_id = auth.uid());
$$;
create or replace function public.is_group_owner(gid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members m
                 where m.group_id = gid and m.user_id = auth.uid() and m.role = 'owner');
$$;
-- do two members share any group? (lets the group screen show each other's names)
create or replace function public.shares_group_with(uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members a
    join public.group_members b on a.group_id = b.group_id
    where a.user_id = auth.uid() and b.user_id = uid
  );
$$;
grant execute on function public.shares_group_with(uuid) to anon, authenticated;

-- ---------- RLS (do NOT use FORCE — it re-arms recursion in the helpers) ----------
alter table public.groups           enable row level security;
alter table public.group_members    enable row level security;
alter table public.reading_progress enable row level security;

-- let group-mates read each other's profile (name + emoji) for the group screen.
-- (adds to the P3a self-select policy; permissive policies OR together.)
drop policy if exists "profiles_group_select" on public.profiles;
create policy "profiles_group_select" on public.profiles
  for select using (id = (select auth.uid()) or public.shares_group_with(id));

-- create policy is NOT idempotent, so drop-then-create makes the whole block re-runnable.
drop policy if exists "groups_member_select" on public.groups;
create policy "groups_member_select" on public.groups
  for select using (public.is_group_member(id));
drop policy if exists "groups_owner_update" on public.groups;
create policy "groups_owner_update" on public.groups
  for update using (public.is_group_owner(id)) with check (public.is_group_owner(id));

drop policy if exists "members_select" on public.group_members;
create policy "members_select" on public.group_members
  for select using (public.is_group_member(group_id));
drop policy if exists "members_self_delete" on public.group_members;
create policy "members_self_delete" on public.group_members   -- leave a group
  for delete using (user_id = (select auth.uid()));

drop policy if exists "progress_select" on public.reading_progress;
create policy "progress_select" on public.reading_progress
  for select using (user_id = (select auth.uid()) or public.is_group_member(group_id));
drop policy if exists "progress_insert_own" on public.reading_progress;
create policy "progress_insert_own" on public.reading_progress
  for insert with check (user_id = (select auth.uid()));
drop policy if exists "progress_update_own" on public.reading_progress;
create policy "progress_update_own" on public.reading_progress
  for update using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------- LWW + clock-clamp on progress writes ----------
create or replace function public.reading_progress_lww()
returns trigger language plpgsql as $$
begin
  if new.updated_at is null or new.updated_at > now() + interval '1 minute' then
    new.updated_at := now();                       -- reject future-dated client clocks
  end if;
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return old;                                     -- ignore stale offline writes
  end if;
  return new;
end; $$;
drop trigger if exists reading_progress_lww_trg on public.reading_progress;
create trigger reading_progress_lww_trg before insert or update on public.reading_progress
  for each row execute function public.reading_progress_lww();

-- ---------- keep the group plan immutable after creation ----------
create or replace function public.groups_plan_immutable()
returns trigger language plpgsql as $$
begin
  if (new.start_book, new.start_chapter, new.end_book, new.end_chapter,
      new.chapters_per_day, new.start_date)
     is distinct from
     (old.start_book, old.start_chapter, old.end_book, old.end_chapter,
      old.chapters_per_day, old.start_date)
  then raise exception 'plan_immutable'; end if;
  return new;
end; $$;
drop trigger if exists groups_plan_immutable_trg on public.groups;
create trigger groups_plan_immutable_trg before update on public.groups
  for each row execute function public.groups_plan_immutable();

-- ---------- create + join via SECURITY DEFINER RPCs (the only group write paths) ----------
create or replace function public.create_group(
  p_name text, p_start_book text, p_start_chapter int,
  p_end_book text, p_end_chapter int, p_pace int, p_start_date date)
returns public.groups language plpgsql security definer set search_path = '' as $$
declare g public.groups;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into public.groups(name, join_code, created_by, start_book, start_chapter,
       end_book, end_chapter, chapters_per_day, start_date)
    values (p_name, upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
       auth.uid(), p_start_book, p_start_chapter, p_end_book, p_end_chapter, p_pace, p_start_date)
    returning * into g;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'owner');
  return g;
end; $$;

create or replace function public.join_group_by_code(p_code text)
returns public.groups language plpgsql security definer set search_path = '' as $$
declare g public.groups; cnt int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into g from public.groups where join_code = upper(p_code) for update;  -- locks row (capacity TOCTOU)
  if g.id is null then raise exception 'group_not_found'; end if;
  select count(*) into cnt from public.group_members where group_id = g.id;
  if cnt >= 10 then raise exception 'group_full'; end if;
  insert into public.group_members(group_id, user_id, role)
    values (g.id, auth.uid(), 'member') on conflict (group_id, user_id) do nothing;
  return g;
end; $$;

grant execute on function public.create_group(text,text,int,text,int,int,date) to authenticated;
grant execute on function public.join_group_by_code(text) to authenticated;

-- ---------- realtime (P3c) — guarded so re-runs don't error if already added ----------
do $$
begin
  if not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='reading_progress')
  then alter publication supabase_realtime add table public.reading_progress; end if;
  if not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='group_members')
  then alter publication supabase_realtime add table public.group_members; end if;
end $$;

-- nudge PostgREST to pick up the new functions/policies immediately.
notify pgrst, 'reload schema';
```

> Verified end-to-end against the live project: create → join-by-code → progress
> upsert (idempotent) → cross-member visibility (progress + members + profiles)
> → negative RLS (bad code rejected, can't write another user's rows). All pass.

### Still TODO before real launch (noted, not in the SQL above)
- **Rate-limit `join_group_by_code`** (per-uid attempt throttle) so the 6-char code can't be brute-forced to auto-join small private groups. (Low impact at 2–10 users, but do it before public release.)
- **Last-owner-leaves** ownership transfer (a sole owner leaving orphans the group).
- **Late-joiner UX** decision (default `start_date = today` on create) so a new member isn't instantly "tertinggal N hari" — see `P3_SUPABASE.md` §8.

---

## Google Sign-In (native) — your checklist

The Flutter side is **already implemented** (native `google_sign_in` v7 → `signInWithIdToken`). The "Lanjut dengan Google" button appears automatically once `GOOGLE_WEB_CLIENT_ID` is set. You only need to create the OAuth clients and paste the IDs. App bundle id: **`com.davidgunawan.teduh`**.

### A. Google Cloud Console (console.cloud.google.com)
1. Create/select a project.
2. **APIs & Services → OAuth consent screen** → *External* → fill app name + support email + developer email → **Save**. While it's in "Testing", add your Gmail under **Test users** (only test users can sign in until you publish).
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**, twice:
   - **Web application** (name "Teduh Web") → copy its **Client ID** and **Client secret**. This Client ID = `GOOGLE_WEB_CLIENT_ID` *and* what Supabase needs.
   - **iOS** (name "Teduh iOS") → **Bundle ID = `com.davidgunawan.teduh`** → copy its **Client ID** = `GOOGLE_IOS_CLIENT_ID`.

### B. Supabase dashboard
4. **Authentication → Providers → Google** → enable → paste the **Web** Client ID + secret → turn **ON "Skip nonce checks"** (iOS native sends no nonce) → **Save**.

### C. App (local)
5. `env.json` → set `GOOGLE_WEB_CLIENT_ID` (web) and `GOOGLE_IOS_CLIENT_ID` (ios).
6. `ios/Runner/Info.plist` → replace `com.googleusercontent.apps.REPLACE_WITH_REVERSED_IOS_CLIENT_ID` with your **reversed iOS client ID**. The reversal is just the order flipped:
   `123456-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123456-abc`
7. Stop the running app, then `flutter run --dart-define-from-file=env.json`. (Dart-defines and Info.plist only take effect on a fresh launch, not hot reload.)

Pitfalls: the bundle id must match across Xcode / the iOS OAuth client / the reversed scheme; if the button doesn't appear, `GOOGLE_WEB_CLIENT_ID` is empty in the running build; "Sign in with Apple" is still required by App Store rule 4.8 before shipping with Google (deferred).

---

## Caveats
- **Free-tier projects auto-pause after ~7 days with no API calls.** Reading is unaffected (offline), but the first social action after a quiet week is slow/needs resume. Add a weekly keepalive (cron/GitHub Action hitting a trivial endpoint) before launch.
- **No codegen Supabase helpers** (`supabase_codegen_*`, build_runner-based) — they reintroduce the analyzer conflict that forced manual providers here. `supabase_flutter` itself is runtime-only and fine.
- Anonymous sign-in / the anonymous tier is **deferred** (P3c) — for the MVP only mint accounts when a user enters the social layer, so plain readers don't count toward MAU.

---

## Client side (recap — implemented during P3a/P3b, not dashboard work)
- `flutter pub add supabase_flutter google_sign_in sign_in_with_apple crypto` (verify `flutter pub get` resolves with the pinned `intl 0.20.2`).
- `Supabase.initialize(...)` in `main()`, wrapped in try/catch, keys from `--dart-define`.
- A nullable `supabaseClientProvider` (null = social off) + `authProvider` (`Notifier<AuthSnapshot>`); `syncServiceProvider` returns `SupabaseSyncService` only when the client is non-null, else the existing `LocalSyncService`.
