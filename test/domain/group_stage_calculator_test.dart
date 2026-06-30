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
  });
}
