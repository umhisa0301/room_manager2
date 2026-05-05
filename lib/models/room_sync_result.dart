/// [RoomSyncService] の1バッチあたりの集計（全件同期・履歴への拡張前提）。
class RoomSyncResult {
  const RoomSyncResult({
    required this.processedCount,
    required this.newlyCollectedCount,
    required this.roomUrlAddedCount,
    required this.skippedCount,
    required this.failedCount,
    this.failedRoomUrls = const [],
    this.fatalErrorMessage,
  });

  /// 実際に1件ずつ確認した ROOM 商品ページ数（最大10など）。
  final int processedCount;

  /// コレ済として新規行を追加した件数。
  final int newlyCollectedCount;

  /// 既存行に roomUrl（等）を追記した件数。
  final int roomUrlAddedCount;

  /// 同期不要（既に roomUrl 済み・同一商品に別ROOM紐付け済み等）でスキップした件数。
  final int skippedCount;

  /// 取得・解析・永続化に失敗した件数。
  final int failedCount;

  final List<String> failedRoomUrls;

  /// 一覧ページ取得など、バッチ全体を続行できないときのメッセージ（null なら致命的ではない）。
  final String? fatalErrorMessage;

  bool get hasFatalError =>
      fatalErrorMessage != null && fatalErrorMessage!.trim().isNotEmpty;
}
