/// ROOM collects API の探索モード（通常の高速取り込み / 古い投稿の深掘り）。
enum RoomImportCollectsExploreMode {
  /// 先頭から最大 [normalMaxCollectPages] ページまで。連続既知打ち切りあり。
  normal,

  /// 保存カーソル以降を含め最大 [deepMaxCollectPages] ページまで深掘り。
  deep,
}

/// collects ページング・早期終了の定数（ROOM 取り込み prepare 用）。
abstract final class RoomImportCollectsPolicy {
  /// 通常モードで取得する collects の最大ページ数。
  static const int normalMaxCollectPages = 3;

  /// 深掘りモードで取得する collects の最大ページ数（従来上限に合わせる）。
  static const int deepMaxCollectPages = 40;

  /// 通常モードのみ: 同期済みキーがこの件数連続したら探索打ち切り。
  static const int consecutiveKnownLimitForNormalStop = 30;
}
