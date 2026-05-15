/// ホーム / マイページの ROOM 同期カードで共有する文言。
abstract final class RoomSyncCardCopy {
  static const title = 'ROOM同期';

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
