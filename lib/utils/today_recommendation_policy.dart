import '../models/rakuten_managed_product.dart';
import '../models/saved_shop.dart';
import '../services/rakuten_genre_master_service.dart';
import 'favorite_genre_pref.dart';

/// 今日のおすすめコレの生成ポリシー（API 回数・表示件数・sort）。
abstract final class TodayRecommendationPolicy {
  /// 1 回の生成で表示する最大件数。
  static const int displayCap = 10;

  /// 1 回の生成での楽天 API 呼び出し上限（ページングなし・1 プラン = 1 回）。
  static const int maxApiCallsPerGeneration = 4;

  /// 保存ジャンル検索プランの上限（= おすすめで使うジャンル数上限）。
  static const int maxGenreSearchPlans = 3;

  /// 補助プラン（反応・保存ショップ・履歴ジャンル）の上限。
  static const int maxAssistSearchPlans = 1;

  /// フォールバック（保存ジャンルなし等）の上限。
  static const int maxFallbackSearchPlans = 1;

  /// 楽天 Ichiba Item Search の既定 sort。
  static const String defaultApiSort = '-reviewCount';

  /// 上位 [displayCap] 件における同一ショップの最大件数。
  static const int maxPerShopInTop = 2;

  /// 上位 [displayCap] 件における同一ジャンルの最大件数。
  static const int maxPerGenreInTop = 4;

  /// おすすめ生成の sort（スタイルに関わらずレビュー件数順）。
  static String apiSortForPostStyles(Set<String> postStyles) => defaultApiSort;
}

/// おすすめ用検索プラン（テスト・組み立て用の値オブジェクト）。
class RecommendSearchPlanSpec {
  const RecommendSearchPlanSpec({
    required this.phase,
    required this.relaxLevel,
    required this.source,
    required this.keyword,
    this.genreId,
    this.shopCode,
    this.sort = TodayRecommendationPolicy.defaultApiSort,
  });

  final String phase;
  final int relaxLevel;
  final String source;
  final String keyword;
  final String? genreId;
  final String? shopCode;
  final String sort;

  String get planKey =>
      '${genreId ?? ''}|${shopCode ?? ''}|$sort|${keyword.trim()}';
}

/// 今日のおすすめ向けの検索プラン組み立て（API 回数を抑える）。
abstract final class TodayRecommendationPlanBuilder {
  /// 保存ジャンル必須プラン・補助・フォールバックに分割したセット。
  static ({
    List<RecommendSearchPlanSpec> favoriteGenrePlans,
    RecommendSearchPlanSpec? assistPlan,
    RecommendSearchPlanSpec? fallbackPlan,
  })
  buildPlanSet({
    required List<String> favoriteGenreIds,
    required List<SavedShop> savedShops,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required List<String> keywords,
    required Set<String> reactionCommentGenreIds,
    required Set<String> reactionLikeGenreIds,
    required Set<String> reactionCommentShopIds,
    required Set<String> reactionLikeShopIds,
    required List<String> historyGenreIdsFiltered,
  }) {
    final favList = favoriteGenreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(TodayRecommendationPolicy.maxGenreSearchPlans)
        .toList(growable: false);
    final favSet = favList.toSet();
    final fallbackKeyword =
        keywords.isEmpty ? '人気' : keywords.first.trim();

    final favoriteGenrePlans = <RecommendSearchPlanSpec>[];
    for (final gid in favList) {
      favoriteGenrePlans.add(
        RecommendSearchPlanSpec(
          phase: 'personal',
          relaxLevel: 0,
          source: 'genre',
          keyword: _keywordForFavoriteGenre(gid, fallbackKeyword),
          genreId: gid,
          sort: TodayRecommendationPolicy.defaultApiSort,
        ),
      );
    }

    final assist = _pickAssistPlan(
      favoriteGenreIds: favSet,
      savedShops: savedShops,
      reactionCommentGenreIds: reactionCommentGenreIds,
      reactionLikeGenreIds: reactionLikeGenreIds,
      reactionCommentShopIds: reactionCommentShopIds,
      reactionLikeShopIds: reactionLikeShopIds,
      historyGenreIds: historyGenreIdsFiltered,
      keyword: fallbackKeyword,
      existingPlans: favoriteGenrePlans,
    );

    RecommendSearchPlanSpec? fallback;
    if (favList.isEmpty) {
      fallback = RecommendSearchPlanSpec(
        phase: 'fallback',
        relaxLevel: 1,
        source: 'fallback',
        keyword: fallbackKeyword,
        sort: TodayRecommendationPolicy.defaultApiSort,
      );
    }

    return (
      favoriteGenrePlans: favoriteGenrePlans,
      assistPlan: assist,
      fallbackPlan: fallback,
    );
  }

  static String _keywordForFavoriteGenre(String genreId, String fallbackKeyword) {
    final name = FavoriteGenrePref.resolveGenreNameForId(genreId).trim();
    if (name.isNotEmpty &&
        name != RakutenGenreMasterService.unknownGenreDisplayLabel) {
      return name;
    }
    return fallbackKeyword.isEmpty ? '人気' : fallbackKeyword;
  }

  static List<RecommendSearchPlanSpec> build({
    required List<String> favoriteGenreIds,
    required List<SavedShop> savedShops,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required List<String> keywords,
    required Set<String> reactionCommentGenreIds,
    required Set<String> reactionLikeGenreIds,
    required Set<String> reactionCommentShopIds,
    required Set<String> reactionLikeShopIds,
    required List<String> historyGenreIdsFiltered,
  }) {
    final set = buildPlanSet(
      favoriteGenreIds: favoriteGenreIds,
      savedShops: savedShops,
      doneItems: doneItems,
      candidateItems: candidateItems,
      keywords: keywords,
      reactionCommentGenreIds: reactionCommentGenreIds,
      reactionLikeGenreIds: reactionLikeGenreIds,
      reactionCommentShopIds: reactionCommentShopIds,
      reactionLikeShopIds: reactionLikeShopIds,
      historyGenreIdsFiltered: historyGenreIdsFiltered,
    );
    return [
      ...set.favoriteGenrePlans,
      if (set.assistPlan != null) set.assistPlan!,
      if (set.fallbackPlan != null) set.fallbackPlan!,
    ];
  }

  static RecommendSearchPlanSpec? _pickAssistPlan({
    required Set<String> favoriteGenreIds,
    required List<SavedShop> savedShops,
    required Set<String> reactionCommentGenreIds,
    required Set<String> reactionLikeGenreIds,
    required Set<String> reactionCommentShopIds,
    required Set<String> reactionLikeShopIds,
    required List<String> historyGenreIds,
    required String keyword,
    required List<RecommendSearchPlanSpec> existingPlans,
  }) {
    final existingKeys = existingPlans.map((e) => e.planKey).toSet();

    bool isDuplicate(RecommendSearchPlanSpec p) =>
        existingKeys.contains(p.planKey);

    RecommendSearchPlanSpec? tryAdd(RecommendSearchPlanSpec p) {
      if (isDuplicate(p)) return null;
      return p;
    }

    for (final gid in reactionCommentGenreIds) {
      if (gid.isEmpty || favoriteGenreIds.contains(gid)) continue;
      final p = tryAdd(
        RecommendSearchPlanSpec(
          phase: 'personal',
          relaxLevel: 0,
          source: 'reactionGenre',
          keyword: keyword,
          genreId: gid,
          sort: TodayRecommendationPolicy.defaultApiSort,
        ),
      );
      if (p != null) return p;
    }
    for (final gid in reactionLikeGenreIds) {
      if (gid.isEmpty || favoriteGenreIds.contains(gid)) continue;
      final p = tryAdd(
        RecommendSearchPlanSpec(
          phase: 'personal',
          relaxLevel: 0,
          source: 'reactionGenre',
          keyword: keyword,
          genreId: gid,
          sort: TodayRecommendationPolicy.defaultApiSort,
        ),
      );
      if (p != null) return p;
    }
    for (final sid in reactionCommentShopIds) {
      if (sid.isEmpty) continue;
      final p = tryAdd(
        RecommendSearchPlanSpec(
          phase: 'personal',
          relaxLevel: 0,
          source: 'reactionShop',
          keyword: keyword,
          shopCode: sid,
          sort: TodayRecommendationPolicy.defaultApiSort,
        ),
      );
      if (p != null) return p;
    }
    for (final shop in savedShops) {
      final sid = shop.shopId.trim();
      if (sid.isEmpty) continue;
      final p = tryAdd(
        RecommendSearchPlanSpec(
          phase: 'personal',
          relaxLevel: 0,
          source: 'savedShop',
          keyword: keyword,
          shopCode: sid,
          sort: TodayRecommendationPolicy.defaultApiSort,
        ),
      );
      if (p != null) return p;
    }
    for (final gid in historyGenreIds) {
      if (gid.isEmpty || favoriteGenreIds.contains(gid)) continue;
      final p = tryAdd(
        RecommendSearchPlanSpec(
          phase: 'personal',
          relaxLevel: 0,
          source: 'historyGenre',
          keyword: keyword,
          genreId: gid,
          sort: TodayRecommendationPolicy.defaultApiSort,
        ),
      );
      if (p != null) return p;
    }
    return null;
  }

  /// 理論上の最大プラン数（API 上限で打ち切り）。
  static int maxPlanCount({
    required int favoriteGenreCount,
    required bool hasAssist,
    required bool needsFallback,
  }) {
    final genrePlans = favoriteGenreCount.clamp(
      0,
      TodayRecommendationPolicy.maxGenreSearchPlans,
    );
    final assist = hasAssist ? TodayRecommendationPolicy.maxAssistSearchPlans : 0;
    final fallback =
        needsFallback ? TodayRecommendationPolicy.maxFallbackSearchPlans : 0;
    return genrePlans + assist + fallback;
  }
}

/// 今日のおすすめの API 実行順序（保存ジャンル網羅を優先）。
abstract final class TodayRecommendationExecutionPolicy {
  /// 保存ジャンル必須プランを、件数が足りていても打ち切らない。
  static bool shouldSkipMandatoryGenrePlan({
    required int apiCallsSoFar,
    int maxApi = TodayRecommendationPolicy.maxApiCallsPerGeneration,
  }) {
    return apiCallsSoFar >= maxApi;
  }

  /// 保存ジャンル検索の後に補助プランを実行するか。
  static bool shouldRunAssistPlan({
    required int finalizedEntryCount,
    required bool hasAssistPlan,
    required int apiCallsSoFar,
    int displayCap = TodayRecommendationPolicy.displayCap,
    int maxApi = TodayRecommendationPolicy.maxApiCallsPerGeneration,
  }) {
    if (!hasAssistPlan) return false;
    if (apiCallsSoFar >= maxApi) return false;
    return finalizedEntryCount < displayCap;
  }
}
