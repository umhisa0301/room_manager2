import 'dart:math' as math;

import '../models/rakuten_search_item.dart';
import '../models/shop_discovery_summary.dart';

/// 商品検索結果をショップ単位に集約し、発掘用ランキングへ変換する。
abstract final class ShopDiscoveryAggregator {
  static List<ShopDiscoverySummary> aggregate(
    List<RakutenSearchItem> items, {
    required int shopLimit,
    required int itemsPerShop,
  }) {
    final grouped = <String, List<RakutenSearchItem>>{};
    for (final item in items) {
      final key = _shopKey(item);
      grouped.putIfAbsent(key, () => <RakutenSearchItem>[]).add(item);
    }

    final summaries = <ShopDiscoverySummary>[];
    grouped.forEach((key, list) {
      if (list.isEmpty) return;
      final shopName = list.first.shopName.trim().isNotEmpty
          ? list.first.shopName.trim()
          : 'ショップ名不明';
      final shopUrl = list.first.shopUrl.trim();
      final hitCount = list.length;
      var maxReviewCount = 0;
      var sumReviewAverage = 0.0;
      for (final e in list) {
        if (e.reviewCount > maxReviewCount) {
          maxReviewCount = e.reviewCount;
        }
        sumReviewAverage += e.reviewAverage;
      }
      final avgReview = hitCount > 0 ? sumReviewAverage / hitCount : 0.0;
      final score = _scoreOf(
        hitItemCount: hitCount,
        maxReviewCount: maxReviewCount,
        avgReviewAverage: avgReview,
      );
      final representative = list
          .take(itemsPerShop)
          .map(
            (e) => ShopRepresentativeItem(
              itemName: e.itemName,
              imageUrl: e.imageUrl,
              itemUrl: e.browserLaunchUrl,
            ),
          )
          .toList(growable: false);
      summaries.add(
        ShopDiscoverySummary(
          shopKey: key,
          shopName: shopName,
          shopUrl: shopUrl,
          hitItemCount: hitCount,
          maxReviewCount: maxReviewCount,
          avgReviewAverage: avgReview,
          discoveryScore: score,
          representativeItems: representative,
        ),
      );
    });

    summaries.sort((a, b) {
      final byScore = b.discoveryScore.compareTo(a.discoveryScore);
      if (byScore != 0) return byScore;
      return b.hitItemCount.compareTo(a.hitItemCount);
    });

    final limit = shopLimit.clamp(1, 10).toInt();
    return summaries.take(limit).toList(growable: false);
  }

  static double _scoreOf({
    required int hitItemCount,
    required int maxReviewCount,
    required double avgReviewAverage,
  }) {
    final hitScore = hitItemCount * 18.0;
    final reviewVolumeScore = math.log(maxReviewCount + 1) * 12.0;
    final ratingScore = avgReviewAverage * 22.0;
    return hitScore + reviewVolumeScore + ratingScore;
  }

  static String _shopKey(RakutenSearchItem item) {
    if (item.shopCode.trim().isNotEmpty) return item.shopCode.trim();
    if (item.shopName.trim().isNotEmpty) return item.shopName.trim();
    return 'unknown';
  }
}
