import '../constants/shop_pool_fallback_keyword_synonyms.dart';
import '../models/catalog_product.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';

enum ShopPoolKeywordMatchLevel { strong, medium, weak, none }

/// fallback 品質ログ用（検索意図との一致度）。
enum ShopPoolFallbackRelevanceQuality { excellent, good, weak, insufficient }

class ShopPoolKeywordRelevanceResult {
  const ShopPoolKeywordRelevanceResult({
    required this.level,
    required this.matchedBy,
    required this.relevanceScore,
    required this.isUnknownGenre,
  });

  final ShopPoolKeywordMatchLevel level;
  final String matchedBy;
  final int relevanceScore;
  final bool isUnknownGenre;

  static const none = ShopPoolKeywordRelevanceResult(
    level: ShopPoolKeywordMatchLevel.none,
    matchedBy: 'none',
    relevanceScore: 0,
    isUnknownGenre: false,
  );
}

abstract final class ShopPoolKeywordRelevance {
  ShopPoolKeywordRelevance._();

  static ShopPoolKeywordRelevanceResult evaluate({
    required ProductCatalogRepository? repository,
    required String keyword,
    required ShopPoolCandidate candidate,
  }) {
    final tokens = ShopPoolFallbackKeywordSynonyms.tokensFor(keyword);
    if (tokens.isEmpty) return ShopPoolKeywordRelevanceResult.none;

    final unknownGenre = isUnknownGenre(candidate);
    final normalizedTokens = tokens
        .map(_normalize)
        .where((e) => e.isNotEmpty)
        .toSet();

    if (normalizedTokens.isEmpty) {
      return ShopPoolKeywordRelevanceResult(
        level: ShopPoolKeywordMatchLevel.none,
        matchedBy: 'none',
        relevanceScore: 0,
        isUnknownGenre: unknownGenre,
      );
    }

    final products = _productsForCandidate(repository, candidate);
    var strongHits = 0;
    for (final p in products) {
      if (_containsAnyToken(_normalize(p.itemName), normalizedTokens)) {
        strongHits++;
      }
    }

    if (strongHits > 0) {
      return ShopPoolKeywordRelevanceResult(
        level: ShopPoolKeywordMatchLevel.strong,
        matchedBy: 'itemName',
        relevanceScore: strongHits,
        isUnknownGenre: unknownGenre,
      );
    }

    final genreTexts = <String>[
      candidate.primaryGenreName,
      ...candidate.sourceGenres,
      for (final p in products) p.genreName,
    ];
    for (final raw in genreTexts) {
      if (_containsAnyToken(_normalize(raw), normalizedTokens)) {
        return ShopPoolKeywordRelevanceResult(
          level: ShopPoolKeywordMatchLevel.medium,
          matchedBy: 'genreName',
          relevanceScore: 1,
          isUnknownGenre: unknownGenre,
        );
      }
    }

    final shopTexts = <String>[
      candidate.shopName,
      for (final p in products) p.shopName,
    ];
    for (final raw in shopTexts) {
      if (_containsAnyToken(_normalize(raw), normalizedTokens)) {
        return ShopPoolKeywordRelevanceResult(
          level: ShopPoolKeywordMatchLevel.weak,
          matchedBy: 'shopName',
          relevanceScore: 1,
          isUnknownGenre: unknownGenre,
        );
      }
    }

    return ShopPoolKeywordRelevanceResult(
      level: ShopPoolKeywordMatchLevel.none,
      matchedBy: 'none',
      relevanceScore: 0,
      isUnknownGenre: unknownGenre,
    );
  }

  static bool isUnknownGenre(ShopPoolCandidate candidate) {
    final name = candidate.primaryGenreName.trim();
    if (name.isEmpty) return true;
    final lower = name.toLowerCase();
    if (lower == 'unknown' || lower == '不明') return true;
    return false;
  }

  static ShopPoolFallbackRelevanceQuality evaluateRelevanceQuality({
    required int fallbackCount,
    required int strongCount,
    required int mediumCount,
    required int weakCount,
    required int noMatchCount,
  }) {
    if (fallbackCount <= 2 || (strongCount + mediumCount) == 0) {
      return ShopPoolFallbackRelevanceQuality.insufficient;
    }
    final strongMedium = strongCount + mediumCount;
    if (fallbackCount >= 10 && strongMedium >= 7) {
      return ShopPoolFallbackRelevanceQuality.excellent;
    }
    if (fallbackCount >= 5 && strongMedium >= 3) {
      return ShopPoolFallbackRelevanceQuality.good;
    }
    if (fallbackCount >= 3) {
      if (noMatchCount >= fallbackCount) {
        return ShopPoolFallbackRelevanceQuality.insufficient;
      }
      return ShopPoolFallbackRelevanceQuality.weak;
    }
    return ShopPoolFallbackRelevanceQuality.insufficient;
  }

  static List<CatalogProduct> _productsForCandidate(
    ProductCatalogRepository? repository,
    ShopPoolCandidate candidate,
  ) {
    if (repository == null) return const <CatalogProduct>[];
    final ids = <String>{
      ...candidate.sourceProductIds,
      ...candidate.sampleProductIds,
    };
    return repository.getByCanonicalIds(ids, touch: false);
  }

  static String _normalize(String raw) => raw.trim().toLowerCase();

  static bool _containsAnyToken(String haystack, Set<String> tokens) {
    if (haystack.isEmpty) return false;
    for (final token in tokens) {
      if (token.isNotEmpty && haystack.contains(token)) return true;
    }
    return false;
  }
}
