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

/// ショップ名・コードとも空のときの集計キー（他名称と衝突しないプレフィクス）。
const String roomReactionAnalyticsUnknownShopKey = '!unknownShop';

/// 集計キー（shopName 優先、空なら shopCode、とも空なら [roomReactionAnalyticsUnknownShopKey]）
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
  return (key: roomReactionAnalyticsUnknownShopKey, label: 'ショップ未確認');
}

Map<String, RoomReactionSyncTopProduct> roomReactionAnalyticsDeltaMap(
  RoomReactionSyncHistoryEntry? latest,
) {
  if (latest == null) return {};
  final out = <String, RoomReactionSyncTopProduct>{};
  for (final p in latest.topReactedProducts) {
    final id = p.productId.trim();
    if (id.isEmpty) continue;
    if (p.deltaLike <= 0 && p.deltaComment <= 0) continue;
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
  bool scrollToRoomReactionSection = false,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_NAVIGATION] '
    'from=$from to=$to scrollToRoomReactionSection=$scrollToRoomReactionSection '
    'reason=$reason',
  );
}

int roomReactionAnalyticsEligibleWithReactionCount(
  List<RakutenManagedProduct> items,
) {
  var n = 0;
  for (final e in items) {
    if (roomReactionAnalyticsIsEligible(e) &&
        roomReactionAnalyticsHasReaction(e)) {
      n++;
    }
  }
  return n;
}

/// ホーム CTA 表示制御と同一条件の件数（実機確認用ログの揺れ防止）。
int roomReactionAnalyticsHomeCtaCount(List<RakutenManagedProduct> items) {
  return roomReactionAnalyticsEligibleWithReactionCount(items);
}

int? _lastHomeCtaLogSig;

/// visible / itemsWithReaction / reason が変わったときだけ出力。
void logRoomReactionAnalyticsHomeCtaIfChanged({
  required bool listLoading,
  required List<RakutenManagedProduct> items,
}) {
  if (!kDebugMode) return;
  final itemsWithReaction = roomReactionAnalyticsHomeCtaCount(items);
  final visible = itemsWithReaction > 0;
  final reason =
      listLoading ? 'loading' : (visible ? 'hasReaction' : 'noReaction');
  final sig = Object.hash(visible, itemsWithReaction, reason, listLoading);
  if (_lastHomeCtaLogSig == sig) return;
  _lastHomeCtaLogSig = sig;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_HOME_CTA] visible=$visible '
    'itemsWithReaction=$itemsWithReaction reason=$reason',
  );
}

int? _lastSectionRenderSig;

void logRoomReactionAnalyticsSectionRenderIfChanged({
  required int itemsWithReaction,
  required int itemsWithComment,
  required String topGenres,
  required String topShops,
  required bool historyLoaded,
}) {
  if (!kDebugMode) return;
  final sig = Object.hash(
    itemsWithReaction,
    itemsWithComment,
    topGenres,
    topShops,
    historyLoaded,
  );
  if (_lastSectionRenderSig == sig) return;
  _lastSectionRenderSig = sig;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_SECTION_RENDER] '
    'itemsWithReaction=$itemsWithReaction '
    'itemsWithComment=$itemsWithComment '
    'topGenres=$topGenres '
    'topShops=$topShops '
    'historyLoaded=$historyLoaded',
  );
}

int? _lastHistoryLogSig;

void logRoomReactionAnalyticsHistoryIfChanged({
  required bool loaded,
  required int topReactedProducts,
  required int deltaLikeItems,
  required int deltaCommentItems,
}) {
  if (!kDebugMode) return;
  final sig = Object.hash(
    loaded,
    topReactedProducts,
    deltaLikeItems,
    deltaCommentItems,
  );
  if (_lastHistoryLogSig == sig) return;
  _lastHistoryLogSig = sig;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_HISTORY] loaded=$loaded '
    'topReactedProducts=$topReactedProducts '
    'deltaLikeItems=$deltaLikeItems '
    'deltaCommentItems=$deltaCommentItems',
  );
}

int? _lastNoSideEffectSig;

/// 反応分析が商品・イベントを変更しないことのスナップショット（表示用集計のみ）。
void logRoomReactionAnalyticsNoSideEffectIfChanged({
  required int candidateCount,
  required int doneCount,
  required int todayAppCollectCount,
  required int todayRoomImportCount,
  required int importedFromRoomCount,
}) {
  if (!kDebugMode) return;
  final sig = Object.hash(
    candidateCount,
    doneCount,
    todayAppCollectCount,
    todayRoomImportCount,
    importedFromRoomCount,
  );
  if (_lastNoSideEffectSig == sig) return;
  _lastNoSideEffectSig = sig;
  debugPrint(
    '[ROOM_REACTION_ANALYTICS_NO_SIDE_EFFECT] candidateCount=$candidateCount '
    'doneCount=$doneCount '
    'todayAppCollectCount=$todayAppCollectCount '
    'todayRoomImportCount=$todayRoomImportCount '
    'importedFromRoomCount=$importedFromRoomCount '
    'message=noMutation',
  );
}

int? _lastRoomColleReactionFilterSig;

void logRoomColleReactionFilterIfChanged({
  required bool enabled,
  required int totalDone,
  required int matched,
  required int excludedNoReaction,
  required int excludedUnknown,
}) {
  if (!kDebugMode) return;
  final sig = Object.hash(
    enabled,
    totalDone,
    matched,
    excludedNoReaction,
    excludedUnknown,
  );
  if (_lastRoomColleReactionFilterSig == sig) return;
  _lastRoomColleReactionFilterSig = sig;
  debugPrint(
    '[ROOM_COLLE_REACTION_FILTER] enabled=$enabled totalDone=$totalDone '
    'matched=$matched excludedNoReaction=$excludedNoReaction '
    'excludedUnknown=$excludedUnknown',
  );
}

String roomReactionAnalyticsShopDisplayLine(RakutenManagedProduct e) {
  return roomReactionAnalyticsShopBucket(e).label;
}

void logRoomColleReactionFilterFromItemsIfChanged({
  required bool enabled,
  required List<RakutenManagedProduct> items,
}) {
  var totalDone = 0;
  var matched = 0;
  var excludedUnknown = 0;
  var excludedNoReaction = 0;
  for (final e in items) {
    if (!RakutenManagedProduct.isMemberForStatusTab(
          e,
          RakutenManagedProductStatus.done,
        )) {
      continue;
    }
    totalDone++;
    final lc = e.roomLikeCount;
    final cc = e.roomCommentCount;
    final unknown = lc == null && cc == null;
    final hasPositive = (lc ?? 0) > 0 || (cc ?? 0) > 0;
    if (unknown) {
      excludedUnknown++;
    } else if (!hasPositive) {
      excludedNoReaction++;
    }
    if (hasPositive) {
      matched++;
    }
  }
  logRoomColleReactionFilterIfChanged(
    enabled: enabled,
    totalDone: totalDone,
    matched: enabled ? matched : totalDone,
    excludedNoReaction: excludedNoReaction,
    excludedUnknown: excludedUnknown,
  );
}

String _oneLine(String s) {
  return s.trim().replaceAll(RegExp(r'\s+'), ' ');
}
