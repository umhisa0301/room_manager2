/// Google Play Billing 課金商品ID定義。
///
/// NOTE: Phase 9C で in_app_purchase による商品照会を導入済み。
/// 実際の購入処理・復元・検証は次フェーズ以降で実装する。
///
/// Play Console での定期購入商品作成も次フェーズ以降の作業。
/// 商品IDは一度公開すると変更が困難なため、命名を慎重に維持すること。
abstract final class BillingProductConfig {
  /// Basic プラン月額定期購入商品ID。
  /// 予定価格: 月額 500円
  static const String basicMonthlyProductId = 'room_manager_basic_monthly';

  /// Pro プラン月額定期購入商品ID。
  /// 予定価格: 月額 900円
  static const String proMonthlyProductId = 'room_manager_pro_monthly';

  /// 定義されているすべての商品IDの一覧（将来の queryProductDetails 用）。
  static const List<String> allProductIds = [
    basicMonthlyProductId,
    proMonthlyProductId,
  ];
}
