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

  /// 優先順位: 投稿マイルストーン → おすすめ確認済み。1件のみ返す。
  static HomeInAppNotice? select({
    required int milestonePostCount,
    required int recPendingCount,
    required int recTotalCount,
    required bool recIsLoading,
    required Set<String> dismissedKeys,
    required String todayDateKey,
  }) {
    final postNotice = _selectPostMilestoneNotice(
      milestonePostCount: milestonePostCount,
      dismissedKeys: dismissedKeys,
      todayDateKey: todayDateKey,
    );
    if (postNotice != null) return postNotice;

    return _selectRecCompletedNotice(
      recPendingCount: recPendingCount,
      recTotalCount: recTotalCount,
      recIsLoading: recIsLoading,
      dismissedKeys: dismissedKeys,
      todayDateKey: todayDateKey,
    );
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
