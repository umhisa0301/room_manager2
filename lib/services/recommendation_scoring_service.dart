import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/rakuten_search_item.dart';
import '../models/room_recommendation_profile.dart';

/// 診断プロファイルに基づく商品スコアリング結果。
class RecommendationScoreResult {
  const RecommendationScoreResult({
    required this.totalScore,
    required this.categoryScore,
    required this.priorityScore,
    required this.reviewScore,
    required this.typeScore,
    required this.priceScore,
    required this.noveltyScore,
    required this.weakKeywordScore,
    required this.matchedKeywords,
    required this.matchedCategoryIds,
  });

  final double totalScore;
  final double categoryScore;
  final double priorityScore;
  final double reviewScore;
  final double typeScore;
  final double priceScore;
  final double noveltyScore;
  final double weakKeywordScore;
  final List<String> matchedKeywords;
  final List<String> matchedCategoryIds;
}

/// 診断プロファイルに基づく候補商品スコアリング。
abstract final class RecommendationScoringService {
  RecommendationScoringService._();

  static const double maxCategory = 25;
  static const double maxPriority = 20;
  static const double maxReview = 15;
  static const double maxType = 15;
  static const double maxPrice = 10;
  static const double maxNovelty = 10;
  static const double maxWeak = 3;
  static const double recentExposurePenalty = -30;

  static RecommendationScoreResult score({
    required RakutenSearchItem item,
    required RoomRecommendationProfile profile,
    Set<String> excludeProductIds = const {},
    Set<String> recentlyShownProductIds = const {},
    Set<String> collectedProductIds = const {},
  }) {
    final productId = item.productId.trim();
    if (productId.isNotEmpty &&
        (excludeProductIds.contains(productId) ||
            collectedProductIds.contains(productId))) {
      return const RecommendationScoreResult(
        totalScore: double.negativeInfinity,
        categoryScore: 0,
        priorityScore: 0,
        reviewScore: 0,
        typeScore: 0,
        priceScore: 0,
        noveltyScore: 0,
        weakKeywordScore: 0,
        matchedKeywords: [],
        matchedCategoryIds: [],
      );
    }

    final text = _itemText(item);
    final matchedKeywords = <String>[];
    final matchedCategoryIds = <String>[];

    var categoryScore = 0.0;
    for (final catId in profile.interestCategoryIds) {
      final cat = InterestCategoryDefinitions.byId(catId);
      if (cat == null) continue;
      final hit = cat.searchTerms.any((t) => text.contains(t)) ||
          text.contains(cat.displayName);
      if (hit) {
        matchedCategoryIds.add(catId);
        categoryScore += maxCategory / profile.interestCategoryIds.length;
      }
    }
    categoryScore = categoryScore.clamp(0, maxCategory);

    var priorityScore = 0.0;
    for (final ruleId in profile.priorityRuleIds) {
      final rule = PriorityRuleDefinitions.byId(ruleId);
      if (rule == null) continue;
      final hits = rule.boostKeywords
          .where((w) => _isUsableBoost(w) && text.contains(w))
          .toList();
      if (hits.isNotEmpty) {
        matchedKeywords.addAll(hits);
        priorityScore += maxPriority / profile.priorityRuleIds.length;
      }
    }
    priorityScore = priorityScore.clamp(0, maxPriority);

    // カテゴリと優先条件の両方一致でボーナス。
    if (matchedCategoryIds.isNotEmpty && matchedKeywords.isNotEmpty) {
      priorityScore = (priorityScore + 5).clamp(0, maxPriority);
    }

    var reviewScore = 0.0;
    if (profile.priorityRuleIds.contains('review_trust')) {
      if (item.reviewCount >= 50 && item.reviewAverage >= 4.0) {
        reviewScore = maxReview;
      } else if (item.reviewCount >= 20 && item.reviewAverage >= 3.8) {
        reviewScore = maxReview * 0.7;
      } else if (item.reviewCount >= 10) {
        reviewScore = maxReview * 0.4;
      }
    } else if (item.reviewAverage >= 4.0 && item.reviewCount >= 10) {
      reviewScore = maxReview * 0.5;
    }

    var typeScore = 0.0;
    final type = RoomTypeDefinitions.byId(profile.primaryTypeId);
    if (type != null) {
      final typeHits = type.searchDirectionKeywords.where(text.contains).length;
      if (typeHits > 0) {
        typeScore = (maxType * (typeHits / type.searchDirectionKeywords.length))
            .clamp(0, maxType);
      }
    }

    var priceScore = 0.0;
    if (profile.primaryTypeId == 'value_balance' ||
        profile.priorityRuleIds.contains('value_balance')) {
      if (item.itemPrice >= 500 && item.itemPrice <= 5000) {
        priceScore = maxPrice;
      } else if (item.itemPrice <= 10000) {
        priceScore = maxPrice * 0.6;
      }
    } else if (item.itemPrice >= 500 && item.itemPrice <= 15000) {
      priceScore = maxPrice * 0.5;
    }

    const noveltyScore = maxNovelty * 0.5;

    var weakScore = 0.0;
    for (final weak in PriorityRuleDefinitions.weakBoostKeywords) {
      if (text.contains(weak)) {
        weakScore += 1;
      }
    }
    weakScore = weakScore.clamp(0, maxWeak);

    var total = categoryScore +
        priorityScore +
        reviewScore +
        typeScore +
        priceScore +
        noveltyScore +
        weakScore;

    if (recentlyShownProductIds.contains(productId)) {
      total += recentExposurePenalty;
    }

    return RecommendationScoreResult(
      totalScore: total,
      categoryScore: categoryScore,
      priorityScore: priorityScore,
      reviewScore: reviewScore,
      typeScore: typeScore,
      priceScore: priceScore,
      noveltyScore: noveltyScore,
      weakKeywordScore: weakScore,
      matchedKeywords: matchedKeywords.toSet().toList(growable: false),
      matchedCategoryIds: matchedCategoryIds,
    );
  }

  static String _itemText(RakutenSearchItem item) =>
      '${item.itemName} ${item.genreName}';

  static bool _isUsableBoost(String word) {
    if (PriorityRuleDefinitions.bannedKeywords.contains(word)) return false;
    return word.trim().isNotEmpty;
  }
}
