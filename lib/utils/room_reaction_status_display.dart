import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import 'room_sync_log.dart';

/// ROOM コレ商品の反応チップ表示（いいね・コメントから統一判定）。
abstract final class RoomReactionStatusDisplay {
  static bool hasPositiveReaction({
    required int? roomLikeCount,
    required int? roomCommentCount,
  }) {
    return (roomLikeCount != null && roomLikeCount > 0) ||
        (roomCommentCount != null && roomCommentCount > 0);
  }

  /// `反応あり` / `ROOM投稿済み` / `未確認` / `未取り込み`（ROOM未紐付けのみ）。
  static String chipLabelForProduct(RakutenManagedProduct product) {
    final lc = product.roomLikeCount;
    final cc = product.roomCommentCount;
    if (hasPositiveReaction(roomLikeCount: lc, roomCommentCount: cc)) {
      return '反応あり';
    }
    final roomLinked = product.roomUrl.trim().isNotEmpty ||
        product.coredActivitySource == RakutenCoredActivitySource.roomImport;
    if (roomLinked) {
      if (lc == null && cc == null) return '未確認';
      return 'ROOM投稿済み';
    }
    return '未取り込み';
  }

  static String reactionStatusKeyForProduct(RakutenManagedProduct product) {
    final label = chipLabelForProduct(product);
    switch (label) {
      case '反応あり':
        return 'hasReaction';
      case 'ROOM投稿済み':
        return 'roomPosted';
      case '未確認':
        return 'unknown';
      default:
        return 'notImported';
    }
  }

  static void logSave({
    required String productId,
    required int? roomLikeCount,
    required int? roomCommentCount,
  }) {
    final status = hasPositiveReaction(
          roomLikeCount: roomLikeCount,
          roomCommentCount: roomCommentCount,
        )
        ? 'hasReaction'
        : (roomLikeCount == null && roomCommentCount == null
            ? 'unknown'
            : 'roomPosted');
    final chip = status == 'hasReaction'
        ? '反応あり'
        : (status == 'unknown' ? '未確認' : 'ROOM投稿済み');
    reactionStatusSaveLog(
      'productId=$productId roomLikeCount=${roomLikeCount ?? '-'} '
      'roomCommentCount=${roomCommentCount ?? '-'} reactionStatus=$status chipLabel=$chip',
    );
  }

  static void logRender({
    required String productId,
    required int? roomLikeCount,
    required int? roomCommentCount,
    required String chipLabel,
    String source = 'computed',
  }) {
    if (!kDebugMode) return;
    reactionStatusRenderLog(
      'productId=$productId roomLikeCount=${roomLikeCount ?? '-'} '
      'roomCommentCount=${roomCommentCount ?? '-'} chipLabel=$chipLabel source=$source',
    );
  }
}
