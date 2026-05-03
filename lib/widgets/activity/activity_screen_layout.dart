/// 活動画面（実績・分析）の余白・間隔を揃える。
class ActivityScreenLayout {
  ActivityScreenLayout._();

  static const double paddingH = 13;
  static const double cardPadding = 16;
  static const double sectionGap = 12;
  static const double cardRadius = 18;

  /// 「今日の実績」進捗バー用の1日あたり目安（暦日ベースの投稿・候補件数）。
  static const int dailyPostProgressGoal = 20;
  static const int dailyCandidateProgressGoal = 50;

  /// 上部タブバーの統一高さ。
  static const double mainTabBarHeight = 52;
}
