/// 共通商品カタログ（Phase 1 土台）の設定。
abstract final class ProductCatalogConfig {
  /// Phase 1 では false。true のときのみカタログ書き込み・参照ヘルパーが動作。
  static const bool kProductCatalogEnabled = bool.fromEnvironment(
    'PRODUCT_CATALOG_ENABLED',
    defaultValue: false,
  );

  static const int maxCatalogProducts = 800;

  /// 価格: 24 時間
  static const int priceTtlSeconds = 24 * 60 * 60;

  /// 全体 TTL の既定（価格 TTL と同値。将来は項目別に分割しやすいよう定数を分離）。
  static const int defaultProductCacheTtlSeconds = priceTtlSeconds;

  /// レビュー: 3 日
  static const int reviewTtlSeconds = 3 * 24 * 60 * 60;

  /// 画像 URL: 7 日
  static const int imageTtlSeconds = 7 * 24 * 60 * 60;

  /// ショップ名: 30 日
  static const int shopTtlSeconds = 30 * 24 * 60 * 60;

  /// ジャンル名: 30 日
  static const int genreTtlSeconds = 30 * 24 * 60 * 60;
}
