import '../models/rakuten_search_item.dart';
import '../models/room_recommendation_profile.dart';
import '../models/today_recommendation.dart';
import '../services/recommendation_reason_builder.dart';
import '../services/recommendation_scoring_service.dart';
import '../utils/today_recommendation_policy.dart';

/// 診断プロファイルとおすすめコレ生成の橋渡し。
abstract final class ProfileRecommendationIntegration {
  ProfileRecommendationIntegration._();

  static const int profileDisplayCap = 3;

  /// 初回生成で実行するプロファイル検索クエリ数（V1: 厳選3件優先）。
  static const int maxInitialSearchQueries = 3;

  /// 診断プロファイルからキーワード検索プランを生成。
  static List<RecommendSearchPlanSpec> buildSearchPlans(
    RoomRecommendationProfile profile,
  ) {
    final queries = profile.searchKeywordPresets
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(maxInitialSearchQueries)
        .toList(growable: false);
    return queries
        .map(
          (q) => RecommendSearchPlanSpec(
            phase: 'profile',
            relaxLevel: 0,
            source: 'profileKeyword',
            keyword: q,
            sort: TodayRecommendationPolicy.defaultApiSort,
          ),
        )
        .toList(growable: false);
  }

  /// プロファイルベースのスコアを既存スコアに加算。
  static ({
    double blendedScore,
    RecommendationScoreResult profileScore,
  }) blendScore({
    required RakutenSearchItem item,
    required RoomRecommendationProfile profile,
    required double baseScore,
    Set<String> excludeProductIds = const {},
    Set<String> recentlyShownProductIds = const {},
    Set<String> collectedProductIds = const {},
  }) {
    final profileScore = RecommendationScoringService.score(
      item: item,
      profile: profile,
      excludeProductIds: excludeProductIds,
      recentlyShownProductIds: recentlyShownProductIds,
      collectedProductIds: collectedProductIds,
    );
    if (profileScore.totalScore == double.negativeInfinity) {
      return (blendedScore: double.negativeInfinity, profileScore: profileScore);
    }
    return (
      blendedScore: baseScore + profileScore.totalScore,
      profileScore: profileScore,
    );
  }

  /// 診断済み向けに上位3件を役割付きで選定。
  static List<TodayRecommendationEntry> pickTopThreeWithRoles({
    required List<({
      RakutenSearchItem item,
      double score,
      double priceScore,
      TodayRecommendationSection section,
      RecommendationScoreResult profileScore,
    })> candidates,
    required RoomRecommendationProfile profile,
  }) {
    final valid = candidates
        .where((e) => e.score != double.negativeInfinity)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (valid.isEmpty) return const [];

    final picked = <TodayRecommendationEntry>[];
    final usedIds = <String>{};

    TodayRecommendationEntry? takeFirstWhere(
      bool Function(({
        RakutenSearchItem item,
        double score,
        double priceScore,
        TodayRecommendationSection section,
        RecommendationScoreResult profileScore,
      }) e) test,
      RecommendationSlotRole role,
      TodayRecommendationSection section,
    ) {
      for (final c in valid) {
        final id = c.item.productId.trim();
        if (id.isEmpty || usedIds.contains(id)) continue;
        if (!test(c)) continue;
        usedIds.add(id);
        return TodayRecommendationEntry(
          item: c.item,
          reason: RecommendationReasonBuilder.build(
            profile: profile,
            item: c.item,
            scoreResult: c.profileScore,
            slot: role,
          ),
          section: section,
          score: c.score,
          priceScore: c.priceScore,
        );
      }
      return null;
    }

    final personal = takeFirstWhere(
      (c) => c.profileScore.categoryScore > 0 && c.profileScore.priorityScore > 0,
      RecommendationSlotRole.personalFit,
      TodayRecommendationSection.sellable,
    );
    if (personal != null) picked.add(personal);

    final trusted = takeFirstWhere(
      (c) =>
          c.item.reviewCount >= 15 &&
          c.item.reviewAverage >= 3.9 &&
          c.item.itemPrice >= 500,
      RecommendationSlotRole.trustedPick,
      TodayRecommendationSection.popular,
    );
    if (trusted != null) picked.add(trusted);

    final primaryCategoryId = profile.interestCategoryIds.isNotEmpty
        ? profile.interestCategoryIds.first
        : '';
    final discovery = takeFirstWhere(
      (c) {
        if (c.profileScore.categoryScore <= 0) return false;
        final cats = c.profileScore.matchedCategoryIds;
        if (cats.isEmpty) return false;
        if (primaryCategoryId.isNotEmpty &&
            cats.length == 1 &&
            cats.first == primaryCategoryId) {
          return false;
        }
        return cats.any((id) => id != primaryCategoryId);
      },
      RecommendationSlotRole.discovery,
      TodayRecommendationSection.fresh,
    ) ??
        takeFirstWhere(
          (c) =>
              c.profileScore.categoryScore > 0 &&
              c.profileScore.priorityScore <= 0,
          RecommendationSlotRole.discovery,
          TodayRecommendationSection.fresh,
        );
    if (discovery != null) picked.add(discovery);

    for (final c in valid) {
      if (picked.length >= profileDisplayCap) break;
      final id = c.item.productId.trim();
      if (id.isEmpty || usedIds.contains(id)) continue;
      usedIds.add(id);
      picked.add(
        TodayRecommendationEntry(
          item: c.item,
          reason: RecommendationReasonBuilder.build(
            profile: profile,
            item: c.item,
            scoreResult: c.profileScore,
            slot: RecommendationSlotRole.personalFit,
          ),
          section: c.section,
          score: c.score,
          priceScore: c.priceScore,
        ),
      );
    }

    return picked;
  }
}
