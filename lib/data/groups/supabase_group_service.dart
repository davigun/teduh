import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/time/calendar_date.dart';
import '../../domain/entities/bible.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories.dart';

/// Remote group operations via the SECURITY DEFINER RPCs (the only write paths
/// to groups / group_members). See `docs/SUPABASE_SETUP.md` P3b.
class SupabaseGroupService implements GroupService {
  SupabaseGroupService(this._client);
  final SupabaseClient _client;

  @override
  Future<Group> create({
    required String name,
    required BibleRef start,
    required BibleRef end,
    required int chaptersPerDay,
    required CalendarDate startDate,
  }) async {
    final res = await _client.rpc('create_group', params: {
      'p_name': name,
      'p_start_book': start.bookCode,
      'p_start_chapter': start.chapter,
      'p_end_book': end.bookCode,
      'p_end_chapter': end.chapter,
      'p_pace': chaptersPerDay,
      'p_start_date': startDate.toIso(),
    });
    return _groupFrom(res, GroupRole.owner);
  }

  @override
  Future<Group> joinByCode(String code) async {
    final res = await _client.rpc('join_group_by_code', params: {
      'p_code': code.trim().toUpperCase(),
    });
    return _groupFrom(res, GroupRole.member);
  }

  @override
  Future<void> leave(String groupId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', uid);
  }

  /// The RPCs return a single `public.groups` row (object, or a 1-element list).
  Group _groupFrom(dynamic res, GroupRole role) {
    final row = (res is List ? res.first : res) as Map<String, dynamic>;
    return Group(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Grup',
      joinCode: row['join_code'] as String? ?? '',
      start: BibleRef(row['start_book'] as String, row['start_chapter'] as int),
      end: BibleRef(row['end_book'] as String, row['end_chapter'] as int),
      chaptersPerDay: row['chapters_per_day'] as int,
      startDate: CalendarDate.parse((row['start_date'] as String).split('T').first),
      myRole: role,
    );
  }
}
