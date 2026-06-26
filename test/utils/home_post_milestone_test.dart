import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/home_post_milestone.dart';

void main() {
  group('HomePostMilestoneSnapshot.fromPostCount', () {
    test('count=0 → next=1', () {
      final snap = HomePostMilestoneSnapshot.fromPostCount(
        0,
        useCalendarDayLabel: true,
      );
      expect(snap.nextMilestone, 1);
      expect(snap.isHighProgress, isFalse);
      expect(snap.hintMessage, 'まずは1件投稿してみましょう');
    });

    test('count=1 → next=5', () {
      final snap = HomePostMilestoneSnapshot.fromPostCount(
        1,
        useCalendarDayLabel: true,
      );
      expect(snap.nextMilestone, 5);
      expect(snap.hintMessage, '5件まであと4件です');
    });

    test('count=5 → next=10', () {
      final snap = HomePostMilestoneSnapshot.fromPostCount(
        5,
        useCalendarDayLabel: true,
      );
      expect(snap.nextMilestone, 10);
      expect(snap.hintMessage, '10件まであと5件です');
    });

    test('count=10 → next=20', () {
      final snap = HomePostMilestoneSnapshot.fromPostCount(
        10,
        useCalendarDayLabel: true,
      );
      expect(snap.nextMilestone, 20);
      expect(snap.hintMessage, '20件まであと10件です');
    });

    test('count=20 → completed/highProgress', () {
      final snap = HomePostMilestoneSnapshot.fromPostCount(
        20,
        useCalendarDayLabel: true,
      );
      expect(snap.nextMilestone, isNull);
      expect(snap.isHighProgress, isTrue);
      expect(snap.hintMessage, '今日はかなり進んでいます。無理なく続けましょう');
    });

    test('uses rolling-24h label when calendar day is unavailable', () {
      final snap = HomePostMilestoneSnapshot.fromPostCount(
        3,
        useCalendarDayLabel: false,
      );
      expect(snap.sectionTitle, '直近24時間の目標');
      expect(snap.countSummaryLine, '直近24時間で3件投稿できています');
    });
  });

  group('HomePostMilestoneSnapshot.milestoneState', () {
    test('postedCount=0: 1件は挑戦中、他は未達', () {
      expect(
        HomePostMilestoneSnapshot.milestoneState(0, 1),
        HomeGoalMilestoneState.inProgress,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(0, 5),
        HomeGoalMilestoneState.pending,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(0, 10),
        HomeGoalMilestoneState.pending,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(0, 20),
        HomeGoalMilestoneState.pending,
      );
    });

    test('postedCount=1: 1件は達成済み、5件は挑戦中', () {
      expect(
        HomePostMilestoneSnapshot.milestoneState(1, 1),
        HomeGoalMilestoneState.achieved,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(1, 5),
        HomeGoalMilestoneState.inProgress,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(1, 10),
        HomeGoalMilestoneState.pending,
      );
    });

    test('postedCount=5: 5件は達成済み、10件は挑戦中', () {
      expect(
        HomePostMilestoneSnapshot.milestoneState(5, 1),
        HomeGoalMilestoneState.achieved,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(5, 5),
        HomeGoalMilestoneState.achieved,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(5, 10),
        HomeGoalMilestoneState.inProgress,
      );
      expect(
        HomePostMilestoneSnapshot.milestoneState(5, 20),
        HomeGoalMilestoneState.pending,
      );
    });
  });

  group('HomePostMilestoneSnapshot.remainingProgressLabel', () {
    test('postedCount=0 は 1件まであと1件', () {
      expect(
        HomePostMilestoneSnapshot.remainingProgressLabel(0),
        '1件まであと1件',
      );
    });

    test('postedCount=1 は 5件まであと4件', () {
      expect(
        HomePostMilestoneSnapshot.remainingProgressLabel(1),
        '5件まであと4件',
      );
    });

    test('postedCount=5 は 10件まであと5件', () {
      expect(
        HomePostMilestoneSnapshot.remainingProgressLabel(5),
        '10件まであと5件',
      );
    });
  });
}
