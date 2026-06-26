import 'today_recommendation_policy.dart';

/// おすすめ最終選定用の候補（テスト可能な最小データ）。
class TodayRecommendPickCandidate {
  const TodayRecommendPickCandidate({
    required this.productId,
    required this.score,
    required this.sourceGenreId,
    required this.itemGenreId,
    required this.shopCode,
    required this.mainTopicKey,
    required this.titleToken,
    required this.priceBand,
  });

  final String productId;
  final double score;
  final String sourceGenreId;
  final String itemGenreId;
  final String shopCode;
  final String mainTopicKey;
  final String titleToken;
  final String priceBand;
}

/// ジャンル分散付き最終選定（保存ジャンル sourceGenreId 基準）。
abstract final class TodayRecommendationGenreDistribution {
  static const int displayCap = TodayRecommendationPolicy.displayCap;

  /// 保存ジャンル数に応じた目標件数（合計 [total]）。
  static Map<String, int> computeTargetQuotas({
    required List<String> favoriteGenreIds,
    required int total,
  }) {
    final ids = favoriteGenreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty || total <= 0) return {};
    final n = ids.length;
    final base = total ~/ n;
    var rem = total % n;
    final out = <String, int>{};
    for (final id in ids) {
      out[id] = base + (rem > 0 ? 1 : 0);
      if (rem > 0) rem--;
    }
    return out;
  }

  /// 1ジャンルあたりのハード上限（他ジャンルに候補がある場合）。
  static int maxPerSourceGenre(int favoriteGenreCount) {
    if (favoriteGenreCount <= 1) return displayCap;
    if (favoriteGenreCount == 2) return 6;
    return 6;
  }

  /// [productId] のリスト（入力順・スコア降順想定）を、保存ジャンル分散で最大 [cap] 件選ぶ。
  static List<String> pickProductIds({
    required List<TodayRecommendPickCandidate> candidates,
    required List<String> favoriteGenreIds,
    int cap = displayCap,
    int maxPerShop = TodayRecommendationPolicy.maxPerShopInTop,
  }) {
    if (candidates.isEmpty || cap <= 0) return const [];

    final favIds = favoriteGenreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final quotas = computeTargetQuotas(favoriteGenreIds: favIds, total: cap);
    final maxGenre = maxPerSourceGenre(favIds.length);

    final bySource = <String, List<TodayRecommendPickCandidate>>{};
    final others = <TodayRecommendPickCandidate>[];
    for (final c in candidates) {
      final src = c.sourceGenreId.trim();
      if (src.isNotEmpty && favIds.contains(src)) {
        bySource.putIfAbsent(src, () => []).add(c);
      } else {
        others.add(c);
      }
    }
    for (final list in bySource.values) {
      list.sort((a, b) => b.score.compareTo(a.score));
    }
    others.sort((a, b) => b.score.compareTo(a.score));

    final picked = <String>[];
    final pickedSet = <String>{};
    final sourceCounts = <String, int>{};
    final shopCounts = <String, int>{};
    final genreCounts = <String, int>{};
    final tokenCounts = <String, int>{};
    final mainTopicCounts = <String, int>{};
    final priceBandCounts = <String, int>{};

    bool canTakeGenre(String sourceGenreId) {
      if (favIds.length <= 1) return true;
      final current = sourceCounts[sourceGenreId] ?? 0;
      if (current < maxGenre) return true;
      final othersHaveRoom = favIds.any((gid) {
        if (gid == sourceGenreId) return false;
        final bucket = bySource[gid];
        if (bucket == null || bucket.isEmpty) return false;
        return (sourceCounts[gid] ?? 0) < (quotas[gid] ?? 0);
      });
      return !othersHaveRoom;
    }

    double adjustedScore(TodayRecommendPickCandidate c) {
      var score = c.score;
      if (c.mainTopicKey.isNotEmpty &&
          (mainTopicCounts[c.mainTopicKey] ?? 0) >= 2) {
        score -= 40;
      }
      if (c.titleToken.isNotEmpty && (tokenCounts[c.titleToken] ?? 0) >= 2) {
        score -= 35;
      }
      final genre = c.itemGenreId.trim();
      if (genre.isNotEmpty &&
          (genreCounts[genre] ?? 0) >=
              TodayRecommendationPolicy.maxPerGenreInTop) {
        score -= 80;
      }
      final shop = c.shopCode.trim();
      if (shop.isNotEmpty &&
          (shopCounts[shop] ?? 0) >= maxPerShop) {
        score -= 80;
      }
      if ((priceBandCounts[c.priceBand] ?? 0) >= 4) {
        score -= 18;
      }
      return score;
    }

    void mark(TodayRecommendPickCandidate c) {
      final shop = c.shopCode.trim();
      final genre = c.itemGenreId.trim();
      final src = c.sourceGenreId.trim();
      if (shop.isNotEmpty) shopCounts[shop] = (shopCounts[shop] ?? 0) + 1;
      if (genre.isNotEmpty) genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      if (src.isNotEmpty) {
        sourceCounts[src] = (sourceCounts[src] ?? 0) + 1;
      }
      priceBandCounts[c.priceBand] = (priceBandCounts[c.priceBand] ?? 0) + 1;
      if (c.titleToken.isNotEmpty) {
        tokenCounts[c.titleToken] = (tokenCounts[c.titleToken] ?? 0) + 1;
      }
      if (c.mainTopicKey.isNotEmpty) {
        mainTopicCounts[c.mainTopicKey] =
            (mainTopicCounts[c.mainTopicKey] ?? 0) + 1;
      }
    }

    bool tryPickFrom(List<TodayRecommendPickCandidate> list) {
      TodayRecommendPickCandidate? best;
      var bestScore = double.negativeInfinity;
      for (final c in list) {
        if (pickedSet.contains(c.productId)) continue;
        final src = c.sourceGenreId.trim();
        if (src.isNotEmpty && favIds.contains(src) && !canTakeGenre(src)) {
          continue;
        }
        final shop = c.shopCode.trim();
        if (shop.isNotEmpty &&
            (shopCounts[shop] ?? 0) >= maxPerShop) {
          continue;
        }
        final genre = c.itemGenreId.trim();
        if (genre.isNotEmpty &&
            (genreCounts[genre] ?? 0) >=
                TodayRecommendationPolicy.maxPerGenreInTop) {
          continue;
        }
        final s = adjustedScore(c);
        if (s > bestScore) {
          bestScore = s;
          best = c;
        }
      }
      if (best == null) return false;
      picked.add(best.productId);
      pickedSet.add(best.productId);
      mark(best);
      return true;
    }

    // 1) 保存ジャンルごとの目標件数を round-robin で確保
    if (favIds.isNotEmpty) {
      var progressed = true;
      while (picked.length < cap && progressed) {
        progressed = false;
        for (final gid in favIds) {
          if (picked.length >= cap) break;
          final target = quotas[gid] ?? 0;
          if ((sourceCounts[gid] ?? 0) >= target) continue;
          final bucket = bySource[gid];
          if (bucket == null || bucket.isEmpty) continue;
          if (tryPickFrom(bucket)) progressed = true;
        }
      }
    }

    // 2) 残りを全体から補完（他ジャンルに候補が無ければ偏り許容）
    final remaining = [
      ...bySource.values.expand((e) => e),
      ...others,
    ]..sort((a, b) => b.score.compareTo(a.score));
    while (picked.length < cap) {
      if (!tryPickFrom(remaining)) break;
    }

    return picked;
  }

  static Map<String, int> distributionBySourceGenre({
    required List<String> pickedProductIds,
    required Map<String, String> sourceGenreByProductId,
    required List<String> favoriteGenreIds,
  }) {
    final out = <String, int>{};
    for (final gid in favoriteGenreIds) {
      final t = gid.trim();
      if (t.isNotEmpty) out[t] = 0;
    }
    for (final id in pickedProductIds) {
      final src = (sourceGenreByProductId[id] ?? '').trim();
      if (src.isEmpty) continue;
      out[src] = (out[src] ?? 0) + 1;
    }
    return out;
  }

  static bool isGenreSkewed({
    required Map<String, int> distribution,
    required int favoriteGenreCount,
    required int finalCount,
  }) {
    if (favoriteGenreCount <= 1 || finalCount <= 0) return false;
    if (distribution.isEmpty) return false;
    final max = distribution.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (favoriteGenreCount >= 3 && max >= 7) return true;
    if (favoriteGenreCount == 2 && max >= 8) return true;
    return false;
  }
}
