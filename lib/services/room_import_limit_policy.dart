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

  /// 取り込みバッチ完了後に **自動で走らせる** メタデータ補完の楽天API試行上限（1セッション）。
  /// 0 で自動補完オフ。体感速度・429回避のため既定は小さめ。
  static const int postBatchAutoEnrichMaxApiCalls = 3;

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
