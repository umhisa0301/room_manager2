/// 保存ジャンル（好きなジャンル）の選択・おすすめ生成における上限。
abstract final class FavoriteGenreSelectionPolicy {
  /// 新規選択・編集時の上限。
  static const int maxSelectable = 3;

  /// 今日のおすすめ生成で API に使う保存ジャンル数（先頭から）。
  static const int maxForRecommendGeneration = 3;
}
