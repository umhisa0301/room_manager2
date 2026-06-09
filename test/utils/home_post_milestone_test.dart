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
}
