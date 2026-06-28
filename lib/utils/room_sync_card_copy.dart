/// Home / MyPage のメンテナンス系 UI（高度な操作・無料枠注記など）は、
/// **この定数が true のときだけ**表示する。通常の debug 実行でもユーザー画面としては非表示のまま。
const bool showRoomSyncMaintenanceDebugUi = false;

/// 取り込み中 UI のフェーズ（件数ではなくタスク単位で表示）。
enum RoomImportUiPhase {
  checkingTargets,
  importingPosts,
  checkingProductInfo,
  checkingReactions,
  finished,
}

/// ホーム / マイページの ROOM 同期カードで共有する文言。
abstract final class RoomSyncCardCopy {
  static const title = '投稿・反応の更新';

  static const subtitle =
      'ROOM投稿を取り込み、いいね・コメントを確認します。';

  static const emptyImportHint = '過去のROOM投稿をコレ済に追加します';

  static const analysisTabHint = '反応があった商品は分析タブで確認できます';

  /// 手動反応確認（補助導線・自動確認と区別しやすい文言）。
  static const manualReactionCheckLabel = '今すぐ反応を確認';

  /// 同期中（自動／手動いずれも）の反応ボタン表示。
  static const reactionCheckBusyLabel = '反応を確認中…';

  /// 投稿・反応の更新セクション内の自動確認説明（1行）。
  static const autoReactionCheckHint =
      '反応は一定時間ごとに自動で確認します。必要なときは手動でも確認できます。';

  static String importPhaseLabel(RoomImportUiPhase phase) {
    switch (phase) {
      case RoomImportUiPhase.checkingTargets:
        return '取り込む投稿を確認しています';
      case RoomImportUiPhase.importingPosts:
        return '投稿を取り込んでいます';
      case RoomImportUiPhase.checkingProductInfo:
        return '商品情報を確認しています';
      case RoomImportUiPhase.checkingReactions:
        return '反応を確認しています';
      case RoomImportUiPhase.finished:
        return '完了しました';
    }
  }

  static double importPhaseProgress(RoomImportUiPhase phase) {
    switch (phase) {
      case RoomImportUiPhase.checkingTargets:
        return 0.2;
      case RoomImportUiPhase.importingPosts:
        return 0.4;
      case RoomImportUiPhase.checkingProductInfo:
        return 0.6;
      case RoomImportUiPhase.checkingReactions:
        return 0.8;
      case RoomImportUiPhase.finished:
        return 1.0;
    }
  }

  /// 主・副ボタンの下に置く補足（候補・反応の両方を示す一文）。
  static const combinedFooterHint =
      '取り込みと反応確認は、それぞれボタンから実行できます。';

  static const maintenanceTileTitle = 'メンテナンス';

  static const maintenanceTileSubtitle = '高度な操作（通常は不要）';

  static String freeTierLine({required int limit}) =>
      '無料版は各操作$limit件ずつです';
}
