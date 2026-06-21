# Monetization Billing Plan

## 概要

このドキュメントは Google Play Billing 導入に関する課金商品情報と、フェーズごとの作業を整理する。

**Phase 9C 時点で `in_app_purchase` による商品照会を導入済み。**  
**Phase 9D 時点で Basic プランの購入処理・復元・簡易永続化を実装済み。**  
Pro 購入・サーバー検証・広告非表示接続・無料版制限解除接続は未実施。

---

## Phase 9D（Basic 購入処理）

### 実装内容

- `BillingPurchaseService` — Basic 商品の購入フロー、`purchaseStream` 購読、復元
- `SubscriptionEntitlementStore` — SharedPreferences による簡易購入状態保存（purchaseToken / レシートは保存しない）
- `resolveCurrentMonetizationPlan` — 保存済み Basic entitlement 経由で `MonetizationPlan.basic` に解決可能
- プラン画面 — Basic 商品取得後「Basicを開始」、購入成功後「Basic利用中」、「購入を復元」ボタン

### 今回の購入対象

| プラン | 購入 | 備考 |
|--------|------|------|
| Basic  | **可** | `room_manager_basic_monthly` |
| Pro    | **不可** | 「今後追加予定」のまま |

### 未接続（Phase 9F / 9G 以降）

- 広告非表示（`adsRemoved` はモデル上 true だが AdMob 表示制御には未接続）
- 無料版制限解除の本格接続
- サーバー検証 / Firebase / Firestore
- レシート送信

### Play Console / 実機テスト前提

1. **Play ストア経由インストール**が必要（`installerPackageName=com.android.vending`）
2. Billing Library 入り AAB を **内部テスト / クローズドテスト** トラックへアップロード済みであること
3. Play Console で **定期購入商品**（Basic）が作成・有効化されていること
4. **ライセンステスター** アカウントを設定すること
5. テスト購入では **テスト支払い方法** を使用（実課金されない）
6. 本番公開前に **購入検証方針**（サーバー検証の要否等）を再確認すること

### ログ確認

```powershell
adb logcat -c
adb logcat | Select-String -Pattern "BILLING_PRODUCT|BILLING_PURCHASE|InAppPurchase|Flutter"
```

- purchaseToken / レシート / 商品IDの過剰出力はしない

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
- 購入ボタン: Basic 商品取得後は「Basicを開始」（Phase 9D）。未取得時は「近日対応予定」

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

## 次フェーズ（Phase 9E以降）で行う作業

1. ~~サブスク購入処理（`buyNonConsumable` 等）の実装~~ → **Basic は Phase 9D で実装済み**
2. ~~購入復元処理~~ → **Basic は Phase 9D で実装済み**
3. ~~`PurchaseDetails` から `PurchaseEntitlement` への反映~~ → **Phase 9D で実装済み**
4. ~~`resolveCurrentMonetizationPlan` への実購入状態接続~~ → **Phase 9D で実装済み**
5. ~~購入状態の永続化（SharedPreferences）~~ → **Phase 9D で簡易実装済み**
6. Pro 購入処理
7. レシート検証・サーバー検証
8. `adsRemoved` と広告表示制御を接続
9. 無料版制限解除の本格接続

---

## フラグ関係

| フラグ | 意味 |
|--------|------|
| `MONETIZATION_ENABLED=true` | 収益化機能全体を有効化 |
| `SUBSCRIPTION_ENABLED=true` | サブスク課金を有効化（これが false だと basicActive でも free 扱い） |
| `PRO_PLAN_ENABLED=true` | Pro プランを有効化（false だと pro は basic にクランプ） |
| `FREE_PLAN_LIMITS_ENABLED=true` | 無料版制限を強制適用 |
| `ADS_ENABLED=true` | 広告表示を有効化 |
