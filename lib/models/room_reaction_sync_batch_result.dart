import 'room_reaction_sync_top_product.dart';

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
    this.itemsChecked = 0,
    this.pagesFetched = 0,
    this.durationMs = 0,
    this.stopReason,
    this.likeIncreasedItems = 0,
    this.commentIncreasedItems = 0,
    this.unchangedItems = 0,
    this.topReactedProducts = const [],
    this.uiSummaryMessage = '',
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
  final int itemsChecked;
  final int pagesFetched;
  final int durationMs;
  final String? stopReason;

  /// 反応が増えた商品数（いいね）。
  final int likeIncreasedItems;

  /// 反応が増えた商品数（コメント）。
  final int commentIncreasedItems;

  /// 確認したが反応に変更がなかった件数。
  final int unchangedItems;

  /// 反応の増分が大きい順（最大3件）。
  final List<RoomReactionSyncTopProduct> topReactedProducts;

  /// SnackBar 等にそのまま使える短文。
  final String uiSummaryMessage;

  bool get hasFatalError =>
      fatalErrorMessage != null && fatalErrorMessage!.trim().isNotEmpty;
}
