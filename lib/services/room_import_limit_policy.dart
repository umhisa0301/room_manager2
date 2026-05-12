/// ROOM 投稿取り込み（内部 [RoomSyncService]）のバッチ上限を将来の課金・広告と切り離すための集約。
///
/// TODO: Billing / AdMob 連携後に [effectiveBatchLimit] を実装し、
/// `RewardedAdGate`・`SubscriptionTier` から上限を決定する。
abstract final class RoomImportLimitPolicy {
  /// 無料版：1回あたりの取り込み件数（現行仕様）。
  static const int freeBatchLimit = 10;

  /// 広告視聴後に追加で許可する件数（プレースホルダー）。
  static const int rewardedAdBonusBatchLimit = 10;

  /// Pro 相当のまとめ取り込み上限（プレースホルダー）。全件は別フラグで表現予定。
  static const int proBatchLimit = 50;

  /// 取り込みバッチ完了後に **自動で走らせる** メタデータ補完の楽天API試行上限（1回あたり）。
  /// 0 で自動補完オフ。429 回避のため **1 件**に固定。
  static const int postBatchAutoEnrichMaxApiCalls = 1;

  /// マイページ「情報を補完」1回あたりの API 試行上限。
  static const int manualEnrichMaxApiCallsPerRun = 1;

  /// 連続する楽天商品検索 API 呼び出しの最小間隔（ミリ秒）。
  static const int enrichMinDelayMsBetweenCalls = 2000;

  /// 429 検知後、自動・手動いずれの補完も控えるクールダウン（分）。
  static const int enrichCooldownAfter429Minutes = 15;

  /// shopCode+itemCode 検索が 400 のとき、その方式を再試行しない期間（時間）。
  static const int enrichShopItemBlockHoursAfterHttp400 = 48;

  /// タイトルキーワード検索が noItems のときの再試行抑止（分）。
  static const int enrichTitleKeywordBlockMinutesAfterNoItems = 360;

  /// productId のみキーワード検索が noItems のときの再試行抑止（分）。
  static const int enrichProductIdKeywordBlockMinutesAfterNoItems = 720;

  /// 400 / noItems / 例外後に **同一商品** を先頭に戻さないための短い待ち（分）。
  static const int enrichBackoffMinutesAfterAttemptFailure = 5;

  /// タイトル由来キーワードに使う最小文字数（ノイズ除外）。
  static const int enrichTitleKeywordMinChars = 8;

  /// 現状は無料のみ。将来 `hasPro` / `rewardedGranted` を参照して返す。
  static int effectiveBatchLimit({
    bool hasPro = false,
    bool rewardedGranted = false,
  }) {
    // TODO: SubscriptionsRepository.isProActive 等
    if (hasPro) return proBatchLimit;
    // TODO: RewardedAdGate.consumeBonusImportSlots()
    if (rewardedGranted) {
      return freeBatchLimit + rewardedAdBonusBatchLimit;
    }
    return freeBatchLimit;
  }
}
