/// 共通ショップカタログ（Phase 3-B/D 土台）の設定。
abstract final class ShopCatalogConfig {
  /// Phase 3-B/D では false。true のときのみカタログ書き込み・参照が動作。
  static const bool kShopCatalogEnabled = bool.fromEnvironment(
    'SHOP_CATALOG_ENABLED',
    defaultValue: false,
  );

  static const int maxShopCatalogEntries = 300;

  /// ショップメタ（名称・URL・代表画像）: 30 日
  static const int shopMetaTtlSeconds = 30 * 24 * 60 * 60;

  /// ショップスコア集計: 3 日
  static const int shopScoreTtlSeconds = 3 * 24 * 60 * 60;

  /// 全体 TTL の既定（メタ TTL と同値）。
  static const int defaultShopCatalogTtlSeconds = shopMetaTtlSeconds;
}
