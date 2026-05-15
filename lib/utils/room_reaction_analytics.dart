import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_reaction_sync_history_entry.dart';
import '../models/room_reaction_sync_top_product.dart';

/// ROOM 反応分析の対象・スコア・ログの単一情報源。

bool roomReactionAnalyticsHasFetchedCounts(RakutenManagedProduct e) {
  return e.roomLikeCount != null || e.roomCommentCount != null;
}

int _like(RakutenManagedProduct e) => e.roomLikeCount ?? 0;

int _comment(RakutenManagedProduct e) => e.roomCommentCount ?? 0;

/// `status == done`・[RakutenManagedProduct.roomUrl] あり・いいね/コメントのいずれか取得済み。
bool roomReactionAnalyticsIsEligible(RakutenManagedProduct e) {
  if (!RakutenManagedProduct.isMemberForStatusTab(
        e,
        RakutenManagedProductStatus.done,
      ) ||
      e.roomUrl.trim().isEmpty) {
    return false;
  }
  return roomReactionAnalyticsHasFetchedCounts(e);
}

/// 内部並び用: いいね + コメント×3
int roomReactionAnalyticsReactionScore(RakutenManagedProduct e) {
  return _like(e) + _comment(e) * 3;
}

/// ジャンル/ショップ集計用: いいね + コメント
int roomReactionAnalyticsReactionSum(RakutenManagedProduct e) {
  return _like(e) + _comment(e);
}

bool roomReactionAnalyticsHasReaction(RakutenManagedProduct e) {
  return _like(e) > 0 || _comment(e) > 0;
}

bool roomReactionAnalyticsHomeShowCta(List<RakutenManagedProduct> items) {
  for (final e in items) {
    if (roomReactionAnalyticsIsEligible(e) &&
        roomReactionAnalyticsHasReaction(e)) {
      return true;
    }
  }
  return false;
}

List<RakutenManagedProduct> roomReactionAnalyticsEligibleItems(
  List<RakutenManagedProduct> items,
) {
  return items
      .where(roomReactionAnalyticsIsEligible)
      .toList(growable: false);
}

String roomReactionAnalyticsGenreBucket(RakutenManagedProduct e) {
  final g = e.genreName.trim();
  return g.isEmpty ? 'ジャンル未確認' : g;
}

/// 集計キー（shopName 優先、空なら shopCode）
({String key, String label}) roomReactionAnalyticsShopBucket(
  RakutenManagedProduct e,
) {
  final name = e.shopName.trim();
  final code = e.shopCode.trim();
  if (name.isNotEmpty) {
    return (key: name, label: name);
  }
  if (code.isNotEmpty) {
    return (key: 'code:$code', label: code);
  }
  return (key: '', label: '—');
}

Map<String, RoomReactionSyncTopProduct> roomReactionAnalyticsDeltaMap(
  RoomReactionSyncHistoryEntry? latest,
) {
  if (latest == null) return {};
  final out = <String, RoomReactionSyncTopProduct>{};
  for (final p in latest.topReactedProducts) {
    final id = p.productId.trim();
    if (id.isEmpty) continue;
    out[id] = p;
  }
  return out;
}

void logRoomReactionAnalyticsSource({
  required int totalDoneRoomItems,
  required int itemsWithReaction,
  required int itemsWithComment,
  required int genresAggregated,
  required int shopsAggregated,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_SOURCE] '
    'totalDoneRoomItems=$totalDoneRoomItems '
    'itemsWithReaction=$itemsWithReaction '
    'itemsWithComment=$itemsWithComment '
    'genresAggregated=$genresAggregated '
    "shopsAggregated=$shopsAggregated'",
  );
}

void logRoomReactionAnalyticsTopProduct({
  required int rank,
  required String productId,
  required String title,
  required int like,
  required int comment,
  required int reactionScore,
  required String shopName,
  required String genreName,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_TOP_PRODUCT] '
    'rank=$rank '
    'productId=$productId '
    'title=${_oneLine(title)} '
    'like=$like '
    'comment=$comment '
    'reactionScore=$reactionScore '
    'shopName=${_oneLine(shopName)} '
    'genreName=${_oneLine(genreName)}',
  );
}

void logRoomReactionAnalyticsNavigation({
  required String from,
  required String to,
  required String reason,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_NAVIGATION] '
    'from=$from to=$to reason=$reason',
  );
}

String _oneLine(String s) {
  return s.trim().replaceAll(RegExp(r'\s+'), ' ');
}
