@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:teduh/domain/entities/group.dart';
import 'package:teduh/domain/services/group_stage_calculator.dart';

void main() {
  const calc = GroupStageCalculator();

  const member = GroupMember(
    userId: 'u1',
    displayName: 'Budi',
    avatarEmoji: '📖',
    role: GroupRole.member,
  );

  group('highWater', () {
    test('is -1 when nothing is read', () {
      expect(calc.highWater(const {}), -1);
    });

    test('counts only the contiguous run from day 0', () {
      expect(calc.highWater(const {0, 1, 2}), 2);
      expect(calc.highWater(const {0, 1, 3}), 1); // gap at 2 stops the run
      expect(calc.highWater(const {1, 2, 3}), -1); // day 0 missing
    });

    test('nextDayIndex is high-water + 1', () {
      final s = calc.stageFor(member, const {0, 1}, 1, isMe: true);
      expect(s.nextDayIndex, 2);
    });
  });

  group('behind (tertinggal)', () {
    test('day 0 unread on the start day is not behind (today grace)', () {
      // startDate == today → scheduledDayIndex 0; nothing read.
      expect(calc.behind(const {}, 0), 0);
    });

    test('one fully-elapsed unread day counts as behind', () {
      // It is day 1; day 0 elapsed and unread.
      expect(calc.behind(const {}, 1), 1);
    });

    test('caught up through yesterday is not behind even if today unread', () {
      // Day 1 today; day 0 done; today not yet read → not behind.
      expect(calc.behind(const {0}, 1), 0);
    });

    test('gaps in the middle count toward behind', () {
      // Day 5 today; only day 0 done → days 1..4 elapsed & unread.
      expect(calc.behind(const {0}, 5), 4);
    });

    test('a jump-ahead leaves earlier elapsed days behind', () {
      // Read today (day 5) but skipped 1..4 → still tertinggal 4 hari.
      expect(calc.behind(const {0, 5}, 5), 4);
    });
  });

  group('stageFor', () {
    test('readToday reflects the scheduled day, not the high-water', () {
      final jumped = calc.stageFor(member, const {0, 5}, 5, isMe: false);
      expect(jumped.readToday, isTrue);
      expect(jumped.highWater, 0);
      expect(jumped.behind, 4);
      expect(jumped.caughtUp, isFalse);
    });

    test('fully caught up reads as caught up', () {
      final s = calc.stageFor(member, const {0, 1, 2}, 2, isMe: true);
      expect(s.caughtUp, isTrue);
      expect(s.readToday, isTrue);
      expect(s.behind, 0);
    });

    // Day-change contract: with the SAME completedDays, as the scheduled day
    // advances (a real midnight rollover), readToday must clear and behind grow.
    // This is the group-side oracle for the provider rollover bug.
    test('as the scheduled day advances, readToday clears then behind grows', () {
      const done = {0, 1, 2};
      final onDay2 = calc.stageFor(member, done, 2, isMe: false);
      expect(onDay2.readToday, isTrue);
      expect(onDay2.behind, 0);

      final onDay3 = calc.stageFor(member, done, 3, isMe: false);
      expect(onDay3.readToday, isFalse); // today (day 3) not yet read
      expect(onDay3.behind, 0); // day 3 is today, grace

      final onDay4 = calc.stageFor(member, done, 4, isMe: false);
      expect(onDay4.readToday, isFalse);
      expect(onDay4.behind, 1); // day 3 elapsed unread
    });

    test('a jump-ahead member stops reading-today once the schedule passes their day', () {
      expect(calc.stageFor(member, const {0, 5}, 5, isMe: false).readToday, isTrue);
      expect(calc.stageFor(member, const {0, 5}, 6, isMe: false).readToday, isFalse);
    });

    test('reading ahead of schedule never goes negative-behind', () {
      final ahead = calc.stageFor(member, const {0, 1, 2}, 1, isMe: false);
      expect(ahead.behind, 0);
      expect(ahead.highWater, 2);
    });
  });
}
