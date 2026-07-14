import 'dart:async';

import 'package:sqlite3/sqlite3.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/group.dart';
import '../../domain/repositories.dart';

/// Account-scoped progress sync. Offline-first: the write path stays local
/// (markRead sets dirty=1); this drains dirty rows to the server with LWW, pulls
/// the active group's mirror, and (P3c) keeps it live via realtime streams.
/// Reading never blocks on any of this. See `docs/P3_SUPABASE.md` §4.
class SupabaseSyncService implements SyncService {
  SupabaseSyncService({
    required SupabaseClient client,
    required Database app,
    required GroupRepository groups,
    required void Function() onMirrorChanged,
  })  : _client = client,
        _app = app,
        _groups = groups,
        _onMirrorChanged = onMirrorChanged;

  final SupabaseClient _client;
  final Database _app;
  final GroupRepository _groups;
  final void Function() _onMirrorChanged;

  // P3c live subscriptions for the active group.
  String? _liveGroupId;
  StreamSubscription<List<Map<String, dynamic>>>? _progressSub;
  StreamSubscription<List<Map<String, dynamic>>>? _membersSub;

  // `_generation` invalidates ALL in-flight realtime work at once: every async
  // step captures the generation at start and bails if it changed (group switch,
  // deactivate, sign-out). `_activating` is a re-entrancy lock so two concurrent
  // activateGroup() calls (cold-start + sign-in event) can't double-subscribe.
  int _generation = 0;
  bool _activating = false;
  bool _memberRefreshing = false;
  bool _memberRefreshPending = false;

  // onSignedIn idempotency (cold-start microtask + auth listener can both fire).
  String? _signedInUid;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<void> pushPending() async {
    final uid = _uid;
    if (uid == null) return;

    // Scoped to the current uid: a previous account's unsynced rows on a shared
    // device must never be uploaded (stamped) as this account's.
    final rows = _app.select(
      'SELECT id, plan_id, day_index, group_id, book_code, chapter, local_date, '
      'completed_at, updated_at FROM reading_progress '
      'WHERE dirty = 1 AND plan_id IS NOT NULL AND user_id = ?',
      [uid],
    );
    if (rows.isEmpty) return;

    // The server PK is the natural key; never send the local `id`.
    final payload = [
      for (final r in rows)
        {
          'user_id': uid,
          'plan_id': r['plan_id'],
          'day_index': r['day_index'],
          'group_id': r['group_id'],
          'book_code': r['book_code'],
          'chapter': r['chapter'],
          'local_date': r['local_date'],
          'completed_at': r['completed_at'],
          'updated_at': r['updated_at'],
        }
    ];

    try {
      await _client
          .from('reading_progress')
          .upsert(payload, onConflict: 'user_id,plan_id,day_index');
      for (final r in rows) {
        _app.execute('UPDATE reading_progress SET dirty = 0 WHERE id = ?',
            [r['id']]);
      }
    } catch (_) {
      // Offline / transient: leave dirty=1 so the next push retries.
    }
  }

  @override
  Future<void> pull() async {
    final uid = _uid;
    final group = await _groups.activeGroup();
    if (uid == null || group == null) return;
    await _refreshMembers(group.id);
    await _refreshProgressRest(group.id);
    _onMirrorChanged();
  }

  /// Fetch membership + profiles (names/emojis) and rewrite the members mirror.
  /// Does NOT bump the revision — callers do, after a generation check.
  Future<void> _refreshMembers(String groupId) async {
    final memberRows = await _client
        .from('group_members')
        .select('user_id, role')
        .eq('group_id', groupId);
    final ids = [for (final m in memberRows) m['user_id'] as String];

    final profileRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
            .from('profiles')
            .select('id, display_name, avatar_emoji')
            .inFilter('id', ids);
    final profileById = {
      for (final p in profileRows) p['id'] as String: p,
    };

    final members = [
      for (final m in memberRows)
        GroupMember(
          userId: m['user_id'] as String,
          displayName:
              profileById[m['user_id']]?['display_name'] as String? ?? 'Pembaca',
          avatarEmoji:
              profileById[m['user_id']]?['avatar_emoji'] as String? ?? '📖',
          role: groupRoleFrom(m['role'] as String?),
        ),
    ];
    await _groups.replaceMembers(groupId, members);
  }

  /// One-shot REST fetch of the group's progress (used by pull-to-refresh).
  Future<void> _refreshProgressRest(String groupId) async {
    final rows = await _client
        .from('reading_progress')
        .select('user_id, day_index')
        .eq('group_id', groupId);
    await _applyProgressRows(groupId, rows);
  }

  /// Rewrite the per-member progress mirror from a full filtered row set.
  /// Skips empty sets: progress is append-only in this app, so an empty
  /// emission means "not loaded yet", never a real wipe — guarding it avoids a
  /// transient blank during a stream's initial fetch race. Does NOT bump.
  Future<void> _applyProgressRows(
      String groupId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final byUser = <String, Set<int>>{};
    for (final r in rows) {
      byUser
          .putIfAbsent(r['user_id'] as String, () => <int>{})
          .add(r['day_index'] as int);
    }
    await _groups.replaceMemberProgress(groupId, byUser);
  }

  @override
  Future<void> activateGroup(String groupId) async {
    if (_liveGroupId == groupId && _progressSub != null) return; // already live
    if (_activating) return; // a concurrent activate is in progress
    _activating = true;
    try {
      await deactivateGroup(); // cancels old subs, bumps generation
      _liveGroupId = groupId;
      final gen = _generation;

      // Seed names immediately, then go live. (Progress is seeded by the
      // stream's own initial snapshot, so we don't fetch it twice.)
      try {
        await _refreshMembers(groupId);
        if (_generation == gen) _onMirrorChanged();
      } catch (_) {/* offline: streams fill in when reachable */}
      if (_generation != gen) return; // deactivated during seed

      _progressSub = _client
          .from('reading_progress')
          .stream(primaryKey: ['user_id', 'plan_id', 'day_index'])
          .eq('group_id', groupId)
          .listen((rows) async {
            if (_generation != gen) return;
            await _applyProgressRows(groupId, rows);
            if (_generation != gen) return;
            _onMirrorChanged();
          }, onError: (_) {/* transient; stream auto-resubscribes */});

      _membersSub = _client
          .from('group_members')
          .stream(primaryKey: ['group_id', 'user_id'])
          .eq('group_id', groupId)
          .listen((_) {
            if (_generation != gen) return;
            _scheduleMemberRefresh(groupId, gen);
          }, onError: (_) {});
    } finally {
      _activating = false;
    }
  }

  /// Serialize member refreshes so overlapping membership events can't interleave
  /// their two network round-trips and clobber each other; coalesce a burst into
  /// at most one trailing re-run.
  void _scheduleMemberRefresh(String groupId, int gen) {
    if (_generation != gen) return;
    if (_memberRefreshing) {
      _memberRefreshPending = true;
      return;
    }
    _memberRefreshing = true;
    _refreshMembers(groupId).then((_) {
      if (_generation == gen) _onMirrorChanged();
    }).catchError((_) {}).whenComplete(() {
      _memberRefreshing = false;
      if (_memberRefreshPending && _generation == gen) {
        _memberRefreshPending = false;
        _scheduleMemberRefresh(groupId, gen);
      } else {
        _memberRefreshPending = false;
      }
    });
  }

  @override
  Future<void> deactivateGroup() async {
    _generation++; // invalidate all in-flight realtime work
    _liveGroupId = null;
    _memberRefreshing = false;
    _memberRefreshPending = false;
    final p = _progressSub;
    final m = _membersSub;
    _progressSub = null;
    _membersSub = null;
    await p?.cancel();
    await m?.cancel();
  }

  @override
  Future<void> onSignedIn(String uid) async {
    if (_signedInUid == uid) return; // already handled this session
    _signedInUid = uid;

    // Backfill once per account: claim every pre-account plan-day row and
    // enqueue it, so weeks of offline history aren't silently lost server-side.
    // Local + safe; only touches rows that are unowned or already ours.
    final prior =
        _app.select("SELECT value FROM sync_state WHERE key = 'backfilled_uid'");
    final alreadyBackfilled = prior.isNotEmpty && prior.first['value'] == uid;
    if (!alreadyBackfilled) {
      _app.execute(
        'UPDATE reading_progress SET user_id = ?, dirty = 1 '
        'WHERE plan_id IS NOT NULL AND (user_id IS NULL OR user_id = ?)',
        [uid, uid],
      );
      _app.execute(
        "INSERT OR REPLACE INTO sync_state(key, value) VALUES('backfilled_uid', ?)",
        [uid],
      );
    }
    await pushPending();
    await pull();
  }

  @override
  Future<void> onSignedOut() async {
    // Stop live streams + keep local reading history; only clear the
    // account-scoped social mirror so it can't leak to the next user.
    await deactivateGroup();
    _signedInUid = null;
    await _groups.clearSocialMirror();
  }
}
