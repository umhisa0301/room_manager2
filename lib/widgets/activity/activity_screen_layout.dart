/// 活動画面（実績・分析）の余白・間隔を揃える。
class ActivityScreenLayout {
  ActivityScreenLayout._();

  /// 投稿管理・探す画面と同じ 16dp。
  static const double paddingH = 16;

  static const double cardPadding = 16;

  static const double sectionGap = 12;

  static const double cardRadius = 16;

  /// 右端コメント FAB との干渉を抑える追加余白。
  static const double fabSideReserve = 12;

  /// リスト末尾の FAB 下余白（[ActivityPlaceholderScreen] の bottomInset に加算）。
  static const double fabBottomReserve = 16;

  /// 「今日の実績」進捗バー用の1日あたり目安（暦日ベースの投稿・候補件数）。
  static const int dailyPostProgressGoal = 20;
  static const int dailyCandidateProgressGoal = 50;

  /// 上部タブバーの統一高さ。
  static const double mainTabBarHeight = 48;
}
