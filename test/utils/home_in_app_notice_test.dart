import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/home_in_app_notice.dart';

void main() {
  const today = '2026-06-09';

  group('HomeInAppNoticeSelector.highestMilestoneTier', () {
    test('maps post counts to milestone tiers', () {
      expect(HomeInAppNoticeSelector.highestMilestoneTier(0), 0);
      expect(HomeInAppNoticeSelector.highestMilestoneTier(1), 1);
      expect(HomeInAppNoticeSelector.highestMilestoneTier(4), 1);
      expect(HomeInAppNoticeSelector.highestMilestoneTier(5), 5);
      expect(HomeInAppNoticeSelector.highestMilestoneTier(10), 10);
      expect(HomeInAppNoticeSelector.highestMilestoneTier(20), 20);
      expect(HomeInAppNoticeSelector.highestMilestoneTier(25), 20);
    });
  });

  group('HomeInAppNoticeSelector.select post milestone', () {
    test('count=0 and no rec → no notice', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice, isNull);
    });

    test('count=1 → milestone praise', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 1,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice, isNotNull);
      expect(notice!.noticeKey, 'post_milestone_${today}_1');
      expect(notice.title, 'いい感じです');
      expect(notice.body, contains('1件投稿できました'));
    });

    test('count=5 → 5件達成 copy', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 5,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice!.title, '5件達成です');
      expect(notice.body, contains('5件投稿できました'));
    });

    test('count=10 → 10件達成 copy', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 10,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice!.title, '10件達成です');
      expect(notice.body, contains('10件投稿できました'));
    });

    test('count=20 → high progress copy', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 20,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice!.title, 'たくさん進みました');
      expect(notice.body, contains('20件投稿できています'));
    });

    test('count=3 → generic progress copy', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 3,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice!.noticeKey, 'post_milestone_${today}_1');
      expect(notice.title, 'いい感じです');
      expect(notice.body, contains('3件投稿できています'));
    });

    test('dismissed post milestone is skipped', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 3,
        recPendingCount: 0,
        recTotalCount: 5,
        recIsLoading: false,
        dismissedKeys: {'post_milestone_${today}_1'},
        todayDateKey: today,
      );
      expect(notice!.noticeKey, 'rec_completed_$today');
    });
  });

  group('HomeInAppNoticeSelector.select rec completed', () {
    test('shows when all recommendations are processed', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 4,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice, isNotNull);
      expect(notice!.noticeKey, 'rec_completed_$today');
      expect(notice.title, '今日のおすすめを確認しました');
    });

    test('hidden while recommendations are pending', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 2,
        recTotalCount: 4,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice, isNull);
    });

    test('hidden while loading', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 4,
        recIsLoading: true,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice, isNull);
    });
  });

  group('HomeInAppNoticeSelector priority', () {
    test('post milestone wins over rec completed', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 2,
        recPendingCount: 0,
        recTotalCount: 5,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
      );
      expect(notice!.noticeKey, startsWith('post_milestone_'));
    });
  });
}
