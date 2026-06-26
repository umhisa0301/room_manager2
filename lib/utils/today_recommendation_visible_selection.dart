import 'package:flutter/foundation.dart';

import '../models/today_recommendation.dart';
import 'recommendation_diversity_utils.dart';
import 'today_recommendation_policy.dart';

/// 画面上に表示可能なおすすめ候補数を [visibleDisplayCap] 件に揃える。
abstract final class TodayRecommendationVisibleSelection {
  static const int visibleCap = TodayRecommendationPolicy.visibleDisplayCap;

  static bool isEntryVisible(
    TodayRecommendationEntry entry,
    int savedShopCount,
  ) {
    if (entry.section == TodayRecommendationSection.sellable &&
        savedShopCount < 1) {
      return false;
    }
    return true;
  }

  static int visibleCount(
    List<TodayRecommendationEntry> entries,
    int savedShopCount,
  ) {
    return TodayRecommendationSectionVisibility.visibleEntries(
      entries: entries,
      savedShopCount: savedShopCount,
    ).length;
  }

  /// 表示可能候補を [cap] 件まで確保する。非表示セクションの候補は除外し、
  /// [backfillPool] から補完する。
  static ({
    List<TodayRecommendationEntry> entries,
    String? fallbackReason,
  }) ensureVisibleCap({
    required List<TodayRecommendationEntry> entries,
    required int savedShopCount,
    required Iterable<TodayRecommendationEntry> backfillPool,
    int cap = visibleCap,
  }) {
    var visible = entries
        .where((e) => isEntryVisible(e, savedShopCount))
        .toList(growable: true);
    final usedIds = visible.map((e) => e.item.productId.trim()).toSet();
    String? fallbackReason;

    bool allowDuplicateShop = false;

    void tryBackfill() {
      for (final candidate in backfillPool) {
        if (visible.length >= cap) break;
        if (!isEntryVisible(candidate, savedShopCount)) continue;
        final id = candidate.item.productId.trim();
        if (id.isEmpty || usedIds.contains(id)) continue;
        if (!RecommendationDiversityUtils.passesDiversityGate(
          item: candidate.item,
          picked: visible,
          allowDuplicateShop: allowDuplicateShop,
        )) {
          continue;
        }
        visible.add(candidate);
        usedIds.add(id);
      }
    }

    tryBackfill();

    if (visible.length < cap) {
      final beforeSecondPass = visible.length;
      allowDuplicateShop = true;
      tryBackfill();
      if (visible.length > beforeSecondPass) {
        fallbackReason ??= 'duplicateShopAllowed';
      }
    }

    if (visible.length < cap) {
      fallbackReason ??= 'insufficientVisibleCandidates';
      if (kDebugMode) {
        debugPrint(
          '[TODAY_RECOMMEND_VISIBLE_CAP] visible=${visible.length} '
          'cap=$cap fallbackReason=$fallbackReason',
        );
      }
    }

    return (
      entries: visible.take(cap).toList(growable: false),
      fallbackReason: fallbackReason,
    );
  }
}
