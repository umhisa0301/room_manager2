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
  static const title = 'ROOM同期';

  static String importPhaseLabel(RoomImportUiPhase phase) {
    switch (phase) {
      case RoomImportUiPhase.checkingTargets:
        return '取り込み対象を確認しています';
      case RoomImportUiPhase.importingPosts:
        return '新しい投稿を取り込んでいます';
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

  static const subtitle =
      '投稿を取り込み、反応を確認して次の運用に活かします。';

  /// 主・副ボタンの下に置く補足（候補・反応の両方を示す一文）。
  static const combinedFooterHint =
      '新しいROOM投稿を取り込み、いいね・コメントの反応を確認できます。';

  static const maintenanceTileTitle = 'メンテナンス';

  static const maintenanceTileSubtitle = '高度な操作（通常は不要）';

  static String freeTierLine({required int limit}) =>
      '無料版は各操作$limit件ずつです';
}
