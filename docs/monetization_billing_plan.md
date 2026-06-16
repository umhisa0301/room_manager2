# Monetization Billing Plan

## 概要

このドキュメントは Google Play Billing 導入に関する課金商品情報と、フェーズごとの作業を整理する。

**Phase 9C 時点で `in_app_purchase` による商品照会を導入済み。**  
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

### Phase 9C で追加したサービス

```dart
// lib/services/billing_product_service.dart
BillingProductService().queryProducts()  // 商品照会のみ（購入処理なし）
```

- `BillingProductConfig.allProductIds` を `queryProductDetails` で照会
- 取得結果は `BillingProductQueryResult` としてプラン画面に渡す
- 購入ボタンは有効化していない（「近日対応予定」のまま）

---

## Play Console 側の作業（コード外・次に必要）

1. **定期購入商品を作成する**
   - Basic monthly product ID: `room_manager_basic_monthly`
   - Pro monthly product ID: `room_manager_pro_monthly`
   - 商品種別: 定期購入（サブスクリプション）
2. 内部テスト / クローズドテストトラックへ公開
3. ライセンステスト用アカウントを設定

### 商品未作成時の挙動

- 商品照会は空または `notFoundIDs` になる可能性がある
- アプリはクラッシュせず、予定価格（月額500円・900円（予定））へフォールバックする
- 「現在準備中です」「近日対応予定」表示を維持する
- 実購入テストは次フェーズ以降

---

## 次フェーズ（Phase 9D以降）で行う作業

1. サブスク購入処理（`buyNonConsumable` 等）の実装
2. 購入復元処理
3. `PurchaseDetails` から `PurchaseEntitlement` への反映
4. `resolveCurrentMonetizationPlan` への実購入状態接続
5. 購入状態の永続化（SharedPreferences または Firestore）
6. レシート検証・サーバー検証
7. `adsRemoved` と広告表示制御を接続

---

## フラグ関係

| フラグ | 意味 |
|--------|------|
| `MONETIZATION_ENABLED=true` | 収益化機能全体を有効化 |
| `SUBSCRIPTION_ENABLED=true` | サブスク課金を有効化（これが false だと basicActive でも free 扱い） |
| `PRO_PLAN_ENABLED=true` | Pro プランを有効化（false だと pro は basic にクランプ） |
| `FREE_PLAN_LIMITS_ENABLED=true` | 無料版制限を強制適用 |
| `ADS_ENABLED=true` | 広告表示を有効化 |
