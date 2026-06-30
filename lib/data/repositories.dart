import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app/providers.dart';
import '../app/supabase.dart';
import '../core/errors/app_exception.dart';
import '../core/time/calendar_date.dart';
import '../domain/entities/bible.dart';
import '../domain/entities/group.dart';
import '../domain/entities/plan.dart';
import '../domain/entities/progress.dart';
import '../domain/repositories.dart';
import 'database/databases.dart';
import 'groups/supabase_group_service.dart';
import 'sync/supabase_sync_service.dart';

// ---------------------------------------------------------------- Bible (read)

class SqliteBibleRepository implements BibleRepository {
  SqliteBibleRepository(this._db);
  final Database _db;

  @override
  Future<List<BibleBook>> books() async {
    final rows = _db.select(
        'SELECT code, ord, nama, testament, chapter_count, is_available FROM books ORDER BY ord');
    return rows
        .map((r) => BibleBook(
              code: r['code'] as String,
              order: r['ord'] as int,
              nama: r['nama'] as String,
              testament:
                  (r['testament'] as String) == 'OT' ? Testament.ot : Testament.nt,
              chapterCount: r['chapter_count'] as int,
              isAvailable: (r['is_available'] as int) == 1,
            ))
        .toList();
  }

  @override
  Future<Chapter> chapter(BibleRef ref) async {
    final avail = _db.select(
        'SELECT is_available FROM books WHERE code = ?', [ref.bookCode]);
    if (avail.isEmpty || (avail.first['is_available'] as int) == 0) {
      throw ChapterUnavailable(ref.bookCode, ref.chapter);
    }

    final vrows = _db.select(
      'SELECT verse, label, text, spans FROM verses WHERE book_code = ? AND chapter = ? ORDER BY verse',
      [ref.bookCode, ref.chapter],
    );
    if (vrows.isEmpty) throw ChapterUnavailable(ref.bookCode, ref.chapter);

    final verses = vrows.map((r) {
      return Verse(
        number: r['verse'] as int,
        label: r['label'] as String?,
        text: r['text'] as String,
        spans: _parseSpans(r['spans'] as String?),
      );
    }).toList();

    final hrows = _db.select(
      'SELECT before_verse, text FROM headings WHERE book_code = ? AND chapter = ? ORDER BY before_verse',
      [ref.bookCode, ref.chapter],
    );
    final headings = hrows
        .map((r) => Heading(r['before_verse'] as int, r['text'] as String))
        .toList();

    return Chapter(ref: ref, verses: verses, headings: headings);
  }

  List<VerseSpan> _parseSpans(String? json) {
    if (json == null || json.isEmpty) return const [];
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((e) {
      final m = e as Map<String, dynamic>;
      return VerseSpan(_spanKind(m['kind'] as String?), m['start'] as int, m['end'] as int);
    }).toList();
  }

  SpanKind _spanKind(String? kind) => switch (kind) {
        'poetry' => SpanKind.poetry,
        'footnote' => SpanKind.footnote,
        _ => SpanKind.wordsOfChrist,
      };
}

// ----------------------------------------------------------------- Plan (write)

class SqlitePlanRepository implements PlanRepository {
  SqlitePlanRepository(this._db);
  final Database _db;

  @override
  Future<ReadingPlan?> activePlan() async {
    final rows = _db.select(
        'SELECT * FROM plans WHERE is_active = 1 ORDER BY updated_at DESC LIMIT 1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ReadingPlan(
      id: r['id'] as String,
      start: BibleRef(r['start_book'] as String, r['start_chapter'] as int),
      end: BibleRef(r['end_book'] as String, r['end_chapter'] as int),
      chaptersPerDay: r['chapters_per_day'] as int,
      startDate: CalendarDate.parse(r['start_date'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  @override
  Future<void> save(ReadingPlan plan) async {
    _db.execute('UPDATE plans SET is_active = 0');
    _db.execute(
      'INSERT OR REPLACE INTO plans(id, start_book, start_chapter, end_book, end_chapter, chapters_per_day, start_date, is_active, updated_at) '
      'VALUES(?,?,?,?,?,?,?,1,?)',
      [
        plan.id,
        plan.start.bookCode,
        plan.start.chapter,
        plan.end.bookCode,
        plan.end.chapter,
        plan.chaptersPerDay,
        plan.startDate.toIso(),
        plan.updatedAt.toIso8601String(),
      ],
    );
  }
}

// ------------------------------------------------------------- Progress (write)

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository(this._db);
  final Database _db;

  @override
  Future<Set<CalendarDate>> completedDates() async {
    final rows = _db.select(
        'SELECT DISTINCT local_date FROM reading_progress WHERE local_date IS NOT NULL');
    return rows.map((r) => CalendarDate.parse(r['local_date'] as String)).toSet();
  }

  @override
  Future<bool> isDayCompleted(int dayIndex) async {
    final rows = _db.select(
        'SELECT 1 FROM reading_progress WHERE day_index = ? LIMIT 1', [dayIndex]);
    return rows.isNotEmpty;
  }

  @override
  Future<void> markRead(DayCompletion c) async {
    // dirty=1 so SupabaseSyncService can drain it later; harmless for local users.
    _db.execute(
      'INSERT OR REPLACE INTO reading_progress'
      '(id, plan_id, book_code, chapter, day_index, local_date, completed_at, updated_at, user_id, group_id, dirty) '
      'VALUES(?,?,?,?,?,?,?,?,?,?,1)',
      [
        c.id,
        c.planId,
        c.passage?.bookCode,
        c.passage?.chapter,
        c.dayIndex,
        c.localDate.toIso(),
        c.completedAt.toIso8601String(),
        c.updatedAt.toIso8601String(),
        c.userId,
        c.groupId,
      ],
    );
  }
}

// --------------------------------------------------------- Group mirror (local)

class SqliteGroupRepository implements GroupRepository {
  SqliteGroupRepository(this._db);
  final Database _db;

  @override
  Future<Group?> activeGroup() async {
    final rows = _db.select('SELECT * FROM groups WHERE is_active = 1 LIMIT 1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Group(
      id: r['id'] as String,
      name: r['name'] as String? ?? 'Grup',
      joinCode: r['join_code'] as String? ?? '',
      start: BibleRef(r['start_book'] as String, r['start_chapter'] as int),
      end: BibleRef(r['end_book'] as String, r['end_chapter'] as int),
      chaptersPerDay: r['chapters_per_day'] as int,
      startDate: CalendarDate.parse(r['start_date'] as String),
      myRole: groupRoleFrom(r['my_role'] as String?),
    );
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    final rows = _db.select(
        'SELECT * FROM group_members WHERE group_id = ? ORDER BY role DESC, display_name',
        [groupId]);
    return rows
        .map((r) => GroupMember(
              userId: r['user_id'] as String,
              displayName: r['display_name'] as String? ?? 'Pembaca',
              avatarEmoji: r['avatar_emoji'] as String? ?? '📖',
              role: groupRoleFrom(r['role'] as String?),
            ))
        .toList();
  }

  @override
  Future<Set<int>> memberDayIndices(String groupId, String userId) async {
    final rows = _db.select(
        'SELECT day_index FROM group_member_progress WHERE group_id = ? AND user_id = ?',
        [groupId, userId]);
    return rows.map((r) => r['day_index'] as int).toSet();
  }

  @override
  Future<void> upsertActiveGroup(Group g) async {
    _db.execute('UPDATE groups SET is_active = 0');
    _db.execute(
      'INSERT OR REPLACE INTO groups'
      '(id, name, join_code, start_book, start_chapter, end_book, end_chapter, chapters_per_day, start_date, my_role, is_active) '
      'VALUES(?,?,?,?,?,?,?,?,?,?,1)',
      [
        g.id,
        g.name,
        g.joinCode,
        g.start.bookCode,
        g.start.chapter,
        g.end.bookCode,
        g.end.chapter,
        g.chaptersPerDay,
        g.startDate.toIso(),
        g.myRole == GroupRole.owner ? 'owner' : 'member',
      ],
    );
  }

  @override
  Future<void> replaceMembers(String groupId, List<GroupMember> members) async {
    _db.execute('BEGIN');
    try {
      _db.execute('DELETE FROM group_members WHERE group_id = ?', [groupId]);
      for (final m in members) {
        _db.execute(
          'INSERT OR REPLACE INTO group_members(group_id, user_id, display_name, avatar_emoji, role) VALUES(?,?,?,?,?)',
          [
            groupId,
            m.userId,
            m.displayName,
            m.avatarEmoji,
            m.role == GroupRole.owner ? 'owner' : 'member',
          ],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> replaceMemberProgress(
      String groupId, Map<String, Set<int>> byUser) async {
    _db.execute('BEGIN');
    try {
      _db.execute(
          'DELETE FROM group_member_progress WHERE group_id = ?', [groupId]);
      for (final entry in byUser.entries) {
        for (final day in entry.value) {
          _db.execute(
            'INSERT OR REPLACE INTO group_member_progress(group_id, user_id, day_index) VALUES(?,?,?)',
            [groupId, entry.key, day],
          );
        }
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> leaveActiveGroup() async {
    final rows = _db.select('SELECT id FROM groups WHERE is_active = 1 LIMIT 1');
    if (rows.isEmpty) return;
    final gid = rows.first['id'] as String;
    _db.execute('DELETE FROM group_member_progress WHERE group_id = ?', [gid]);
    _db.execute('DELETE FROM group_members WHERE group_id = ?', [gid]);
    _db.execute('DELETE FROM groups WHERE id = ?', [gid]);
    // Detach the local plan so the personal reader isn't tied to a left group.
    _db.execute('UPDATE plans SET is_active = 0 WHERE id = ?', [gid]);
  }

  @override
  Future<void> clearSocialMirror() async {
    _db.execute('DELETE FROM group_member_progress');
    _db.execute('DELETE FROM group_members');
    _db.execute('DELETE FROM groups');
  }
}

// ------------------------------------------------------------------ Sync (no-op)

class LocalSyncService implements SyncService {
  const LocalSyncService();
  @override
  Future<void> pushPending() async {}
  @override
  Future<void> pull() async {}
  @override
  Future<void> onSignedIn(String uid) async {}
  @override
  Future<void> onSignedOut() async {}
  @override
  Future<void> activateGroup(String groupId) async {}
  @override
  Future<void> deactivateGroup() async {}
}

// -------------------------------------------------------------------- Providers
// Bound to the DOMAIN interface types. Swapping in Firebase later is a one-line
// override of syncServiceProvider (+ a Firebase ProgressRepository).

final bibleRepositoryProvider = Provider<BibleRepository>(
    (ref) => SqliteBibleRepository(ref.watch(databasesProvider).requireValue.bible));

final planRepositoryProvider = Provider<PlanRepository>(
    (ref) => SqlitePlanRepository(ref.watch(databasesProvider).requireValue.app));

final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => SqliteProgressRepository(ref.watch(databasesProvider).requireValue.app));

/// Local mirror of the active group (always available, even offline).
final groupRepositoryProvider = Provider<GroupRepository>(
    (ref) => SqliteGroupRepository(ref.watch(databasesProvider).requireValue.app));

/// Remote group ops — null when Supabase isn't configured (social off).
final groupServiceProvider = Provider<GroupService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseGroupService(client);
});

/// Real sync only when a client exists; otherwise the offline no-op.
final syncServiceProvider = Provider<SyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const LocalSyncService();
  final service = SupabaseSyncService(
    client: client,
    app: ref.watch(databasesProvider).requireValue.app,
    groups: ref.watch(groupRepositoryProvider),
    onMirrorChanged: () =>
        ref.read(groupMirrorRevisionProvider.notifier).bump(),
  );
  ref.onDispose(() => service.deactivateGroup());
  return service;
});
