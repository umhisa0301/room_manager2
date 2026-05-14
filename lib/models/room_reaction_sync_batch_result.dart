/// [RoomSyncService.syncPostedRoomReactionsOnly] の1バッチ結果。
class RoomReactionSyncBatchResult {
  const RoomReactionSyncBatchResult({
    required this.updated,
    required this.latestPageUpdated,
    required this.resumedUpdated,
    this.nextCursor,
    required this.cursorAction,
    this.fatalErrorMessage,
    this.latestPageChecked = false,
    this.resumeCursorUsed = false,
  });

  final int updated;
  final int latestPageUpdated;
  final int resumedUpdated;
  final String? nextCursor;

  /// `save` / `clear`
  final String cursorAction;

  final String? fatalErrorMessage;
  final bool latestPageChecked;
  final bool resumeCursorUsed;

  bool get hasFatalError =>
      fatalErrorMessage != null && fatalErrorMessage!.trim().isNotEmpty;
}
