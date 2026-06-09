/// ホーム表示後の自動反応確認（1回のみ）の判定ポリシー。
abstract final class HomeAutoReactionSyncPolicy {
  const HomeAutoReactionSyncPolicy._();

  /// 前回反応確認からの最小間隔。
  static const Duration autoReactionSyncMinInterval = Duration(hours: 4);

  /// ホーム表示後、自動実行を試みるまでの遅延（3〜5秒の中央値）。
  static const Duration autoReactionSyncStartDelay = Duration(seconds: 4);

  /// 実行可能なら `null`、スキップ時はログ用 reason 文字列を返す。
  static String? skipReason({
    required bool isOnHomeTab,
    required bool hasRoomUrl,
    required int postedProductCount,
    required bool importRunning,
    required bool metadataEnriching,
    required bool reactionSyncRunning,
    required bool bulkCandidateRegistering,
    required DateTime? lastSyncAtUtc,
    required DateTime nowUtc,
  }) {
    if (!isOnHomeTab) return 'notOnHome';
    if (!hasRoomUrl) return 'noRoomUrl';
    if (postedProductCount <= 0) return 'noPostedProducts';
    if (importRunning ||
        metadataEnriching ||
        reactionSyncRunning ||
        bulkCandidateRegistering) {
      return 'busy';
    }
    if (lastSyncAtUtc == null) return 'noHistory';
    if (nowUtc.difference(lastSyncAtUtc) < autoReactionSyncMinInterval) {
      return 'recentSync';
    }
    return null;
  }
}
