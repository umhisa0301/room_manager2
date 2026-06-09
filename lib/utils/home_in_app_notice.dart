import '../models/room_reaction_sync_history_entry.dart';
import 'home_post_milestone.dart';

/// ホームお知らせカードのアクション種別（既存タブ導線のみ）。
enum HomeInAppNoticeAction { openActivity, openRoomCollect }

/// ホームお知らせカード1件分の表示内容（UI専用・純粋データ）。
class HomeInAppNotice {
  const HomeInAppNotice({
    required this.noticeKey,
    required this.title,
    required this.body,
    this.actionLabel,
    this.action,
  });

  final String noticeKey;
  final String title;
  final String body;
  final String? actionLabel;
  final HomeInAppNoticeAction? action;
}

/// ホームお知らせカードの候補選定（既存画面データのみ・純粋関数）。
abstract final class HomeInAppNoticeSelector {
  const HomeInAppNoticeSelector._();

  /// 投稿数から「到達済みマイルストーン帯」のキー用ティア（1 / 5 / 10 / 20）。
  static int highestMilestoneTier(int postCount) {
    if (postCount >= 20) return 20;
    if (postCount >= 10) return 10;
    if (postCount >= 5) return 5;
    if (postCount >= 1) return 1;
    return 0;
  }

  /// 優先順位: 投稿マイルストーン → 反応増加 → おすすめ確認済み。1件のみ返す。
  static HomeInAppNotice? select({
    required int milestonePostCount,
    required int recPendingCount,
    required int recTotalCount,
    required bool recIsLoading,
    required Set<String> dismissedKeys,
    required String todayDateKey,
    RoomReactionSyncHistoryEntry? latestReactionSyncHistory,
    int reactionSyncHistoryCount = 0,
  }) {
    final postNotice = _selectPostMilestoneNotice(
      milestonePostCount: milestonePostCount,
      dismissedKeys: dismissedKeys,
      todayDateKey: todayDateKey,
    );
    if (postNotice != null) return postNotice;

    final reactionNotice = _selectReactionIncreasedNotice(
      latestReactionSyncHistory: latestReactionSyncHistory,
      reactionSyncHistoryCount: reactionSyncHistoryCount,
      dismissedKeys: dismissedKeys,
      todayDateKey: todayDateKey,
    );
    if (reactionNotice != null) return reactionNotice;

    return _selectRecCompletedNotice(
      recPendingCount: recPendingCount,
      recTotalCount: recTotalCount,
      recIsLoading: recIsLoading,
      dismissedKeys: dismissedKeys,
      todayDateKey: todayDateKey,
    );
  }

  /// 反応増加通知の [noticeKey]（同期日時ベース・記号なし）。
  static String reactionIncreasedNoticeKey({
    required String todayDateKey,
    required String syncedAtIso,
  }) {
    return 'reaction_increased_${todayDateKey}_${_syncedAtCompactForNoticeKey(syncedAtIso)}';
  }

  static HomeInAppNotice? _selectPostMilestoneNotice({
    required int milestonePostCount,
    required Set<String> dismissedKeys,
    required String todayDateKey,
  }) {
    if (milestonePostCount < 1) return null;
    final tier = highestMilestoneTier(milestonePostCount);
    if (tier < 1) return null;

    final noticeKey = 'post_milestone_${todayDateKey}_$tier';
    if (dismissedKeys.contains(noticeKey)) return null;

    return _buildPostMilestoneNotice(
      postCount: milestonePostCount,
      tier: tier,
      noticeKey: noticeKey,
    );
  }

  static HomeInAppNotice _buildPostMilestoneNotice({
    required int postCount,
    required int tier,
    required String noticeKey,
  }) {
    final snap = HomePostMilestoneSnapshot.fromPostCount(
      postCount,
      useCalendarDayLabel: true,
    );

    switch (tier) {
      case 20:
        return HomeInAppNotice(
          noticeKey: noticeKey,
          title: 'たくさん進みました',
          body:
              '今日は$postCount件投稿できています。${snap.hintMessage}',
        );
      case 10:
        return HomeInAppNotice(
          noticeKey: noticeKey,
          title: '10件達成です',
          body:
              '今日は10件投稿できました。${snap.hintMessage}',
        );
      case 5:
        return HomeInAppNotice(
          noticeKey: noticeKey,
          title: '5件達成です',
          body:
              '今日は5件投稿できました。ペースがついてきましたね。',
        );
      case 1:
        if (postCount == 1) {
          return HomeInAppNotice(
            noticeKey: noticeKey,
            title: 'いい感じです',
            body: '今日は1件投稿できました。この調子で少しずつ続けましょう。',
          );
        }
        return HomeInAppNotice(
          noticeKey: noticeKey,
          title: 'いい感じです',
          body: '今日は$postCount件投稿できています。${snap.hintMessage}',
        );
      default:
        return HomeInAppNotice(
          noticeKey: noticeKey,
          title: 'いい感じです',
          body:
              '今日は$postCount件投稿できています。${snap.hintMessage}',
        );
    }
  }

  static HomeInAppNotice? _selectReactionIncreasedNotice({
    required RoomReactionSyncHistoryEntry? latestReactionSyncHistory,
    required int reactionSyncHistoryCount,
    required Set<String> dismissedKeys,
    required String todayDateKey,
  }) {
    if (latestReactionSyncHistory == null) return null;
    if (reactionSyncHistoryCount < 2) return null;

    final likeIncreased = latestReactionSyncHistory.likeIncreasedItems;
    final commentIncreased = latestReactionSyncHistory.commentIncreasedItems;
    if (likeIncreased <= 0 && commentIncreased <= 0) return null;

    final noticeKey = reactionIncreasedNoticeKey(
      todayDateKey: todayDateKey,
      syncedAtIso: latestReactionSyncHistory.syncedAtIso,
    );
    if (dismissedKeys.contains(noticeKey)) return null;

    return HomeInAppNotice(
      noticeKey: noticeKey,
      title: '反応がありました',
      body: _reactionIncreasedBody(
        likeIncreased: likeIncreased,
        commentIncreased: commentIncreased,
      ),
      actionLabel: '分析で見る',
      action: HomeInAppNoticeAction.openActivity,
    );
  }

  static String _reactionIncreasedBody({
    required int likeIncreased,
    required int commentIncreased,
  }) {
    final hasLike = likeIncreased > 0;
    final hasComment = commentIncreased > 0;
    if (hasLike && hasComment) {
      return 'いいね・コメントが増えた商品があります。分析で詳しく見られます。';
    }
    if (hasLike) {
      return 'いいねが増えた商品が$likeIncreased件あります。分析で詳しく見られます。';
    }
    if (hasComment) {
      return 'コメントが増えた商品が$commentIncreased件あります。分析で詳しく見られます。';
    }
    return 'いいねやコメントが増えた商品があります。分析で詳しく見られます。';
  }

  static String _syncedAtCompactForNoticeKey(String syncedAtIso) {
    try {
      final dt = DateTime.parse(syncedAtIso).toUtc();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h$m$s';
    } catch (_) {
      final digits = syncedAtIso.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 6) return digits.substring(digits.length - 6);
      return digits.padRight(6, '0');
    }
  }

  static HomeInAppNotice? _selectRecCompletedNotice({
    required int recPendingCount,
    required int recTotalCount,
    required bool recIsLoading,
    required Set<String> dismissedKeys,
    required String todayDateKey,
  }) {
    if (recIsLoading) return null;
    if (recTotalCount < 1) return null;
    if (recPendingCount > 0) return null;

    final noticeKey = 'rec_completed_$todayDateKey';
    if (dismissedKeys.contains(noticeKey)) return null;

    return HomeInAppNotice(
      noticeKey: noticeKey,
      title: '今日のおすすめを確認しました',
      body: 'また明日、あなた向けの候補を提案します。',
    );
  }
}
