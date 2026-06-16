# Monetization Billing Plan

## 概要

このドキュメントは Google Play Billing 導入前の課金商品情報と、次フェーズで行うべき作業を整理する。

**Phase 9B 時点では Google Play Billing / in_app_purchase は未導入。**  
実際の購入処理・復元・レシート検証は次フェーズ以降で実装する。

---

## 課金商品情報（Play Console で後で作成するもの）

| プラン | 商品種別 | 商品ID | 予定価格 |
|--------|----------|--------|----------|
| Basic  | 定期購入（月額） | `room_manager_basic_monthly` | 月額 500円 |
| Pro    | 定期購入（月額） | `room_manager_pro_monthly`   | 月額 900円 |

### 注意事項

- 商品IDはアプリコード（`BillingProductConfig`）と一致させること
- Play Console での商品種別は「**定期購入（サブスクリプション）**」を選択すること
- 商品IDは一度公開すると変更困難なため、確定後は慎重に扱うこと

---

## コード定義

```dart
// lib/config/billing_product_config.dart
BillingProductConfig.basicMonthlyProductId  // 'room_manager_basic_monthly'
BillingProductConfig.proMonthlyProductId    // 'room_manager_pro_monthly'
```

---

## 次フェーズ（Phase 9C以降）で行う作業

1. `in_app_purchase` パッケージを `pubspec.yaml` に追加
2. Play Console で定期購入商品を上記IDで作成
3. `BillingService` または相当クラスを実装（商品照会・購入・復元）
4. `PurchaseEntitlement` に実購入情報を詰めて `resolveCurrentMonetizationPlan` に接続
5. 購入状態の永続化（SharedPreferences または Firestore）
6. `adsRemoved` と広告表示制御を接続（Phase 9D 以降）

---

## フラグ関係

| フラグ | 意味 |
|--------|------|
| `MONETIZATION_ENABLED=true` | 収益化機能全体を有効化 |
| `SUBSCRIPTION_ENABLED=true` | サブスク課金を有効化（これが false だと basicActive でも free 扱い） |
| `PRO_PLAN_ENABLED=true` | Pro プランを有効化（false だと pro は basic にクランプ） |
| `FREE_PLAN_LIMITS_ENABLED=true` | 無料版制限を強制適用 |
| `ADS_ENABLED=true` | 広告表示を有効化 |
