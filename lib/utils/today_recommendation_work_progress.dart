import '../models/rakuten_managed_product.dart';
import '../models/today_recommendation.dart';
import 'today_recommendation_policy.dart';

/// ホーム「今日やること」のおすすめ確認進捗（表示対象のみ）。
abstract final class TodayRecommendationWorkProgress {
  static String localDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// 画面上に表示されるおすすめ候補（最大 [cap] 件）。
  static List<TodayRecommendationEntry> visibleTargets({
    required List<TodayRecommendationEntry> entries,
    required int savedShopCount,
    int cap = TodayRecommendationPolicy.visibleDisplayCap,
  }) {
    final visible = TodayRecommendationSectionVisibility.visibleEntries(
      entries: entries,
      savedShopCount: savedShopCount,
    );
    return visible.take(cap).toList(growable: false);
  }

  /// 仕訳済み: スキップ / 候補追加 / コレ済み（投稿済み）。
  static bool isEntryProcessed({
    required TodayRecommendationEntry entry,
    required Set<String> collectedProductIds,
  }) {
    final productId = entry.item.productId.trim();
    if (productId.isNotEmpty && collectedProductIds.contains(productId)) {
      return true;
    }
    return entry.decision != TodayRecommendationDecision.pending;
  }

  static Set<String> collectedProductIdsFrom(
    Iterable<RakutenManagedProduct> managedItems,
  ) {
    return managedItems
        .where(
          (e) => RakutenManagedProduct.isMemberForStatusTab(
            e,
            RakutenManagedProductStatus.done,
          ),
        )
        .map((e) => e.productId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static int processedVisibleCount({
    required TodayRecommendationBundle? bundle,
    required int savedShopCount,
    required Set<String> collectedProductIds,
    DateTime? now,
    int cap = TodayRecommendationPolicy.visibleDisplayCap,
  }) {
    final targets = _todayVisibleTargetsOrEmpty(
      bundle: bundle,
      savedShopCount: savedShopCount,
      now: now,
      cap: cap,
    );
    if (targets == null) return 0;
    return targets
        .where(
          (e) => isEntryProcessed(
            entry: e,
            collectedProductIds: collectedProductIds,
          ),
        )
        .length;
  }

  /// 表示対象のおすすめをすべて仕訳済みなら `true`。
  static bool isVisibleReviewComplete({
    required TodayRecommendationBundle? bundle,
    required int savedShopCount,
    required Set<String> collectedProductIds,
    required bool isLoading,
    DateTime? now,
    int cap = TodayRecommendationPolicy.visibleDisplayCap,
  }) {
    if (isLoading) return false;
    final targets = _todayVisibleTargetsOrEmpty(
      bundle: bundle,
      savedShopCount: savedShopCount,
      now: now,
      cap: cap,
    );
    if (targets == null || targets.isEmpty) return false;
    return targets.every(
      (e) => isEntryProcessed(
        entry: e,
        collectedProductIds: collectedProductIds,
      ),
    );
  }

  static List<TodayRecommendationEntry>? _todayVisibleTargetsOrEmpty({
    required TodayRecommendationBundle? bundle,
    required int savedShopCount,
    DateTime? now,
    required int cap,
  }) {
    if (bundle == null || bundle.entries.isEmpty) return null;
    if (bundle.localDateKey != localDateKey(now)) return null;
    return visibleTargets(
      entries: bundle.entries,
      savedShopCount: savedShopCount,
      cap: cap,
    );
  }
}
