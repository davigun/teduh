import 'package:meta/meta.dart';

import '../../core/time/calendar_date.dart';
import 'bible.dart';

enum GroupRole { owner, member }

GroupRole groupRoleFrom(String? raw) =>
    raw == 'owner' ? GroupRole.owner : GroupRole.member;

/// A "Baca bersama" group. A group *is* a shared, deterministic reading plan:
/// the plan fields live here and every member adopts them locally on join, so
/// "who is ahead / behind" reduces to comparing day indices. Immutable after
/// creation on the server (editing the plan would re-map everyone's day→passage).
@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.start,
    required this.end,
    required this.chaptersPerDay,
    required this.startDate,
    required this.myRole,
  });

  final String id; // server uuid; doubles as the local plan_id
  final String name;
  final String joinCode; // 6-char, share to invite
  final BibleRef start;
  final BibleRef end;
  final int chaptersPerDay;
  final CalendarDate startDate;
  final GroupRole myRole;
}

/// One member of a group (identity only; their progress lives in the mirror).
@immutable
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String avatarEmoji;
  final GroupRole role;
}

/// A member paired with their computed position in the shared plan. View model
/// for the group screen, built on-device from the local progress mirror.
@immutable
class MemberStage {
  const MemberStage({
    required this.member,
    required this.highWater,
    required this.behind,
    required this.readToday,
    required this.isMe,
  });

  final GroupMember member;
  final int highWater; // latest day with no gaps behind it; -1 if day 0 undone
  final int behind; // "tertinggal N hari" — fully-elapsed overdue days
  final bool readToday; // today's scheduled day already completed
  final bool isMe;

  int get nextDayIndex => highWater + 1;
  bool get caughtUp => behind == 0;
}
