import '../config/product_catalog_config.dart';
import '../models/catalog_product.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/product_catalog_repository.dart';
import '../services/genre_master_service.dart';
import '../utils/catalog_product_keys.dart';
import '../utils/app_debug_log.dart';
import '../utils/catalog_product_mapper.dart';
import '../utils/product_safety_filter.dart';
import '../utils/search_result_quality_filter.dart';
import '../utils/today_recommendation_exposure_policy.dart';
import '../utils/today_recommendation_policy.dart';

/// おすすめ生成向けカタログ候補の収集結果。
class TodayRecommendCatalogCollectResult {
  const TodayRecommendCatalogCollectResult({
    required this.catalogCount,
    required this.catalogCandidates,
    required this.catalogAccepted,
    required this.catalogRejectedStale,
    required this.catalogRejectedQuality,
    required this.catalogRejectedManaged,
    required this.catalogRejectedGenre,
    required this.catalogRejectedTrust,
    required this.catalogRejectedDuplicate,
    required this.sourceGenreIds,
  });

  const TodayRecommendCatalogCollectResult.empty()
    : catalogCount = 0,
      catalogCandidates = 0,
      catalogAccepted = 0,
      catalogRejectedStale = 0,
      catalogRejectedQuality = 0,
      catalogRejectedManaged = 0,
      catalogRejectedGenre = 0,
      catalogRejectedTrust = 0,
      catalogRejectedDuplicate = 0,
      sourceGenreIds = const {};

  final int catalogCount;
  final int catalogCandidates;
  final int catalogAccepted;
  final int catalogRejectedStale;
  final int catalogRejectedQuality;
  final int catalogRejectedManaged;
  final int catalogRejectedGenre;
  final int catalogRejectedTrust;
  final int catalogRejectedDuplicate;

  /// 採用候補の sourceGenreId（保存ジャンル ID）。
  final Set<String> sourceGenreIds;
}

/// カタログ由来候補で API を省略できるかの判定。
abstract final class TodayRecommendationCatalogPolicy {
  static bool shouldSkipAllApiPlans({
    required TodayRecommendCatalogCollectResult catalog,
    required Set<String> favoriteGenreIds,
    int displayCap = TodayRecommendationPolicy.displayCap,
  }) {
    if (catalog.catalogAccepted < displayCap) return false;
    final fav = favoriteGenreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (fav.isEmpty) return false;
    final represented = catalog.sourceGenreIds
        .where((id) => fav.contains(id))
        .toSet();
    final requiredGenres = fav.length >= 3 ? 3 : fav.length;
    return represented.length >= requiredGenres;
  }
}

/// おすすめ生成前の共通商品カタログ参照。
abstract final class TodayRecommendationCatalog {
  /// 保存ジャンル配下か（完全一致または親子判定）。
  static String? resolveSourceFavoriteGenreId({
    required String productGenreId,
    required Set<String> favoriteGenreIds,
  }) {
    final gid = productGenreId.trim();
    if (gid.isEmpty || favoriteGenreIds.isEmpty) return null;
    if (favoriteGenreIds.contains(gid)) return gid;
    var cursor = gid;
    final seen = <String>{};
    while (seen.add(cursor)) {
      final parent = GenreMasterService.instance.getParentGenreId(cursor);
      if (parent == null) break;
      if (favoriteGenreIds.contains(parent)) return parent;
      cursor = parent;
    }
    return null;
  }

  /// カタログから候補を [pool] に投入（[ProductCatalogConfig.kProductCatalogEnabled] 時のみ）。
  static TodayRecommendCatalogCollectResult collectIntoPool({
    required ProductCatalogRepository repository,
    required Map<String, RakutenSearchItem> pool,
    required void Function(String productId, String sourceGenreId) onAcceptMeta,
    required Set<String> favoriteGenreIds,
    required Set<String> excludeIds,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required Map<String, TodayRecommendExposureRecord> exposureRecords,
    required DateTime now,
  }) {
    if (!ProductCatalogConfig.kProductCatalogEnabled) {
      return const TodayRecommendCatalogCollectResult.empty();
    }

    final products = repository.getAll();
    final catalogCount = products.length;
    if (catalogCount == 0) {
      return TodayRecommendCatalogCollectResult(
        catalogCount: 0,
        catalogCandidates: 0,
        catalogAccepted: 0,
        catalogRejectedStale: 0,
        catalogRejectedQuality: 0,
        catalogRejectedManaged: 0,
        catalogRejectedGenre: 0,
        catalogRejectedTrust: 0,
        catalogRejectedDuplicate: 0,
        sourceGenreIds: const {},
      );
    }

    var candidates = 0;
    var accepted = 0;
    var rejectedStale = 0;
    var rejectedQuality = 0;
    var rejectedManaged = 0;
    var rejectedGenre = 0;
    var rejectedTrust = 0;
    var rejectedDuplicate = 0;
    final sourceGenreIds = <String>{};
    final seenUrls = <String>{
      for (final item in pool.values)
        if (CatalogProductKeys.normalizeItemUrl(item.itemUrl).isNotEmpty)
          CatalogProductKeys.normalizeItemUrl(item.itemUrl),
    };

    for (final product in products) {
      final reject = _catalogRejectReason(
        product: product,
        repository: repository,
        favoriteGenreIds: favoriteGenreIds,
        excludeIds: excludeIds,
        doneItems: doneItems,
        candidateItems: candidateItems,
        exposureRecords: exposureRecords,
        pool: pool,
        seenUrls: seenUrls,
        now: now,
      );
      if (reject != null) {
        switch (reject) {
          case _CatalogReject.stale:
            rejectedStale++;
          case _CatalogReject.quality:
            rejectedQuality++;
          case _CatalogReject.managed:
            rejectedManaged++;
          case _CatalogReject.genre:
            rejectedGenre++;
          case _CatalogReject.trust:
            rejectedTrust++;
          case _CatalogReject.duplicate:
            rejectedDuplicate++;
        }
        continue;
      }

      candidates++;
      final sourceGenreId = resolveSourceFavoriteGenreId(
        productGenreId: product.genreId,
        favoriteGenreIds: favoriteGenreIds,
      )!;

      final item = catalogProductToSearchItem(product);
      final id = item.productId.trim();
      if (id.isEmpty) {
        rejectedQuality++;
        continue;
      }

      pool[id] = item;
      onAcceptMeta(id, sourceGenreId);
      sourceGenreIds.add(sourceGenreId);
      accepted++;

      final normUrl = CatalogProductKeys.normalizeItemUrl(item.itemUrl);
      if (normUrl.isNotEmpty) seenUrls.add(normUrl);
    }

    productCatalogStaleBatchSummaryLog(
      source: 'todayRecommendation',
      products: products,
      now: now,
    );

    return TodayRecommendCatalogCollectResult(
      catalogCount: catalogCount,
      catalogCandidates: candidates,
      catalogAccepted: accepted,
      catalogRejectedStale: rejectedStale,
      catalogRejectedQuality: rejectedQuality,
      catalogRejectedManaged: rejectedManaged,
      catalogRejectedGenre: rejectedGenre,
      catalogRejectedTrust: rejectedTrust,
      catalogRejectedDuplicate: rejectedDuplicate,
      sourceGenreIds: sourceGenreIds,
    );
  }
}

enum _CatalogReject { stale, quality, managed, genre, trust, duplicate }

_CatalogReject? _catalogRejectReason({
  required CatalogProduct product,
  required ProductCatalogRepository repository,
  required Set<String> favoriteGenreIds,
  required Set<String> excludeIds,
  required List<RakutenManagedProduct> doneItems,
  required List<RakutenManagedProduct> candidateItems,
  required Map<String, TodayRecommendExposureRecord> exposureRecords,
  required Map<String, RakutenSearchItem> pool,
  required Set<String> seenUrls,
  required DateTime now,
}) {
  if (repository.isStale(product, now: now)) return _CatalogReject.stale;

  if (product.sourceTrust == CatalogProductSourceTrust.low) {
    return _CatalogReject.trust;
  }

  final q = product.qualityStatus;
  if (!q.safe ||
      !q.hasImage ||
      !q.hasPrice ||
      !q.hasValidUrl ||
      product.reviewCount <= 0 ||
      product.reviewAverage <= 0) {
    return _CatalogReject.quality;
  }

  if (TodayRecommendationCatalog.resolveSourceFavoriteGenreId(
        productGenreId: product.genreId,
        favoriteGenreIds: favoriteGenreIds,
      ) ==
      null) {
    return _CatalogReject.genre;
  }

  final item = catalogProductToSearchItem(product);
  final id = item.productId.trim();
  if (id.isEmpty) return _CatalogReject.quality;

  if (item.reviewCount <= 0 || item.reviewAverage <= 0) {
    return _CatalogReject.quality;
  }

  if (!SearchResultQualityFilter.passesDisplayQuality(item)) {
    return _CatalogReject.quality;
  }

  if (excludeIds.contains(id)) return _CatalogReject.managed;

  if (pool.containsKey(id)) return _CatalogReject.duplicate;

  final normUrl = CatalogProductKeys.normalizeItemUrl(item.itemUrl);
  if (normUrl.isNotEmpty && seenUrls.contains(normUrl)) {
    return _CatalogReject.duplicate;
  }

  for (final existing in pool.values) {
    if (existing.productId.trim() == id) return _CatalogReject.duplicate;
    final existingUrl = CatalogProductKeys.normalizeItemUrl(existing.itemUrl);
    if (normUrl.isNotEmpty &&
        existingUrl.isNotEmpty &&
        normUrl == existingUrl) {
      return _CatalogReject.duplicate;
    }
  }

  final exposureReason = TodayRecommendExposurePolicy.exclusionReason(
    productId: id,
    itemUrl: item.itemUrl,
    recordsById: exposureRecords,
    now: now,
  );
  if (exposureReason != null) return _CatalogReject.managed;

  if (ProductSafetyFilter.isBlockedProduct(
    itemName: item.itemName,
    shopName: item.shopName,
    genreName: item.genreName,
    itemUrl: item.itemUrl,
    affiliateUrl: item.affiliateUrl,
  )) {
    return _CatalogReject.quality;
  }

  if (doneItems.any((e) => e.productId.trim() == id) ||
      candidateItems.any((e) => e.productId.trim() == id)) {
    return _CatalogReject.managed;
  }

  return null;
}
