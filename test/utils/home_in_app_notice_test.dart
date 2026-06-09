import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/room_reaction_sync_history_entry.dart';
import 'package:room_manager2/utils/home_in_app_notice.dart';

RoomReactionSyncHistoryEntry _historyEntry({
  String syncedAtIso = '2026-06-09T20:30:15.000Z',
  int likeIncreasedItems = 0,
  int commentIncreasedItems = 0,
}) {
  return RoomReactionSyncHistoryEntry(
    syncedAtIso: syncedAtIso,
    checkedItems: 10,
    updatedItems: 2,
    likeIncreasedItems: likeIncreasedItems,
    commentIncreasedItems: commentIncreasedItems,
    unchangedItems: 8,
    hasReactionItems: 5,
    commentedItems: 1,
    stopReason: '',
    hasNextCursor: false,
    topReactedProducts: const [],
  );
}

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

    test('post milestone wins over reaction increased', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 2,
        recPendingCount: 0,
        recTotalCount: 5,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: _historyEntry(likeIncreasedItems: 3),
        reactionSyncHistoryCount: 2,
      );
      expect(notice!.noticeKey, startsWith('post_milestone_'));
    });

    test('reaction increased wins over rec completed', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 5,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: _historyEntry(commentIncreasedItems: 2),
        reactionSyncHistoryCount: 2,
      );
      expect(notice!.noticeKey, startsWith('reaction_increased_'));
      expect(notice.title, '反応がありました');
    });
  });

  group('HomeInAppNoticeSelector.select reaction increased', () {
    test('no history → no reaction notice', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: null,
        reactionSyncHistoryCount: 0,
      );
      expect(notice, isNull);
    });

    test('single history entry → no reaction notice (baseline guard)', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: _historyEntry(likeIncreasedItems: 5),
        reactionSyncHistoryCount: 1,
      );
      expect(notice, isNull);
    });

    test('2+ history + likeIncreasedItems > 0 → reaction notice', () {
      final latest = _historyEntry(likeIncreasedItems: 3);
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: latest,
        reactionSyncHistoryCount: 2,
      );
      expect(notice, isNotNull);
      expect(notice!.title, '反応がありました');
      expect(notice.body, contains('いいねが増えた商品が3件あります'));
      expect(notice.actionLabel, '分析で見る');
      expect(notice.action, HomeInAppNoticeAction.openActivity);
      expect(
        notice.noticeKey,
        HomeInAppNoticeSelector.reactionIncreasedNoticeKey(
          todayDateKey: today,
          syncedAtIso: latest.syncedAtIso,
        ),
      );
    });

    test('2+ history + commentIncreasedItems > 0 → reaction notice', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: _historyEntry(commentIncreasedItems: 2),
        reactionSyncHistoryCount: 3,
      );
      expect(notice, isNotNull);
      expect(notice!.body, contains('コメントが増えた商品が2件あります'));
      expect(notice.action, HomeInAppNoticeAction.openActivity);
    });

    test('both like and comment increased → combined body', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: _historyEntry(
          likeIncreasedItems: 1,
          commentIncreasedItems: 1,
        ),
        reactionSyncHistoryCount: 2,
      );
      expect(notice!.body, contains('いいね・コメントが増えた商品があります'));
    });

    test('dismissed reaction notice key → no notice', () {
      final latest = _historyEntry(likeIncreasedItems: 1);
      final noticeKey = HomeInAppNoticeSelector.reactionIncreasedNoticeKey(
        todayDateKey: today,
        syncedAtIso: latest.syncedAtIso,
      );
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: {noticeKey},
        todayDateKey: today,
        latestReactionSyncHistory: latest,
        reactionSyncHistoryCount: 2,
      );
      expect(notice, isNull);
    });

    test('no increase counts → no reaction notice', () {
      final notice = HomeInAppNoticeSelector.select(
        milestonePostCount: 0,
        recPendingCount: 0,
        recTotalCount: 0,
        recIsLoading: false,
        dismissedKeys: const {},
        todayDateKey: today,
        latestReactionSyncHistory: _historyEntry(),
        reactionSyncHistoryCount: 2,
      );
      expect(notice, isNull);
    });
  });
}
