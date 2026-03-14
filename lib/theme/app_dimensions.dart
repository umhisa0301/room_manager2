/// 角丸・余白・アイコンサイズなどの共通寸法。
/// カード・検索バー・チップは角丸を大きめに統一。
class AppDimensions {
  AppDimensions._();

  // --- 角丸（大きめ）---
  /// カード・カード風コンテナ
  static const double radiusCard = 16.0;
  /// 検索バー・入力フィールド
  static const double radiusSearchBar = 24.0;
  /// チップ・タグ・ナビタップ領域
  static const double radiusChip = 20.0;
  /// ボタン
  static const double radiusButton = 12.0;

  // --- 余白（広め）---
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 40.0;

  /// 画面左右のパディング
  static const double screenPaddingH = 20.0;
  /// 画面上下のパディング（SafeArea内）
  static const double screenPaddingV = 16.0;

  // --- アイコン ---
  static const double iconNav = 24.0;
  static const double iconPlaceholder = 56.0;
  static const double iconFab = 24.0;
}
