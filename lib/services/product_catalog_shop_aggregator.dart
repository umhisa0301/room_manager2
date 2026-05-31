import '../models/catalog_product.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';
import '../utils/product_safety_filter.dart';
import '../utils/shop_display_resolve.dart';
import 'shop_pool_scoring.dart';

/// ProductCatalog から shopCode 単位の ShopPool を集計する。
abstract final class ProductCatalogShopAggregator {
  static ShopPoolAggregateResult aggregate({
    required ProductCatalogRepository repository,
    Set<String> excludeSavedShopCodes = const {},
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final products = repository.getAll();
    if (products.isEmpty) {
      return const ShopPoolAggregateResult(
        candidates: [],
        stats: ShopPoolAggregateStats.empty,
      );
    }

    var staleExcluded = 0;
    var lowTrustExcluded = 0;
    var unsafeExcluded = 0;
    var emptyShopCodeExcluded = 0;
    var savedExcluded = 0;

    final savedExclude = excludeSavedShopCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final byShop = <String, List<CatalogProduct>>{};
    final shopCodesSeen = <String>{};

    for (final product in products) {
      final code = product.shopCode.trim();
      if (code.isEmpty) {
        emptyShopCodeExcluded++;
        continue;
      }
      shopCodesSeen.add(code);

      if (repository.isStale(product, now: t)) {
        staleExcluded++;
        continue;
      }
      if (product.sourceTrust == CatalogProductSourceTrust.low) {
        lowTrustExcluded++;
        continue;
      }
      if (!product.qualityStatus.safe ||
          ProductSafetyFilter.isBlockedProduct(
            itemName: product.itemName,
            itemCaption: product.itemCaption,
            shopName: product.shopName,
            genreName: product.genreName,
            itemUrl: product.itemUrl,
            affiliateUrl: product.affiliateUrl,
          )) {
        unsafeExcluded++;
        continue;
      }

      byShop.putIfAbsent(code, () => []).add(product);
    }

    final candidates = <ShopPoolCandidate>[];

    for (final entry in byShop.entries) {
      final shopCode = entry.key;
      if (savedExclude.contains(shopCode)) {
        savedExcluded++;
        continue;
      }

      final items = entry.value;
      if (items.isEmpty) continue;

      final candidate = _buildCandidate(shopCode: shopCode, products: items);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    return ShopPoolAggregateResult(
      candidates: candidates,
      stats: ShopPoolAggregateStats(
        catalogProducts: products.length,
        catalogShops: shopCodesSeen.length,
        poolCandidates: candidates.length,
        savedExcluded: savedExcluded,
        staleExcluded: staleExcluded,
        lowTrustExcluded: lowTrustExcluded,
        unsafeExcluded: unsafeExcluded,
        emptyShopCodeExcluded: emptyShopCodeExcluded,
      ),
    );
  }

  static ShopPoolCandidate? _buildCandidate({
    required String shopCode,
    required List<CatalogProduct> products,
  }) {
    if (products.isEmpty) return null;

    final genreCounts = <String, int>{};
    var safeItemCount = 0;
    var itemsWithImage = 0;
    var itemsWithPrice = 0;
    var reviewSum = 0.0;
    var reviewSamples = 0;
    var maxReviewCount = 0;
    var priceSum = 0;
    var priceSamples = 0;
    var minPrice = 0;
    var maxPrice = 0;
    final sourceGenres = <String>{};
    final sourceProductIds = <String>[];
    String? shopName;
    String? shopUrl;
    String? representativeImageUrl;

    for (final p in products) {
      safeItemCount++;
      if (p.qualityStatus.hasImage) itemsWithImage++;
      if (p.qualityStatus.hasPrice) itemsWithPrice++;
      if (p.reviewAverage > 0) {
        reviewSum += p.reviewAverage;
        reviewSamples++;
      }
      if (p.reviewCount > maxReviewCount) maxReviewCount = p.reviewCount;
      if (p.itemPrice > 0) {
        priceSum += p.itemPrice;
        priceSamples++;
        if (minPrice <= 0 || p.itemPrice < minPrice) minPrice = p.itemPrice;
        if (p.itemPrice > maxPrice) maxPrice = p.itemPrice;
      }

      final gid = p.genreId.trim();
      if (gid.isNotEmpty) {
        genreCounts[gid] = (genreCounts[gid] ?? 0) + 1;
        sourceGenres.add(gid);
      }

      final pid = p.canonicalId.trim();
      if (pid.isNotEmpty && sourceProductIds.length < 5) {
        sourceProductIds.add(pid);
      }

      if (_isUsableShopDisplayName(p.shopName, shopCode)) {
        shopName ??= ShopDisplayResolve.resolveDisplayShopName(
          shopName: p.shopName,
          shopCode: shopCode,
        );
      }
      if (shopUrl == null || shopUrl.isEmpty) {
        final url = p.shopUrl.trim();
        if (url.isNotEmpty) shopUrl = url;
      }

      if (p.qualityStatus.hasImage && p.imageUrl.trim().isNotEmpty) {
        final imageScore = _productImagePriority(p);
        final currentScore = representativeImageUrl == null
            ? -1
            : _productImagePriority(
                products.firstWhere(
                  (e) => e.imageUrl.trim() == representativeImageUrl,
                  orElse: () => p,
                ),
              );
        if (representativeImageUrl == null || imageScore > currentScore) {
          representativeImageUrl = p.imageUrl.trim();
        }
      }
    }

    shopName ??= ShopDisplayResolve.unknownShopLabel;
    if (shopName.isEmpty) {
      shopName = ShopDisplayResolve.unknownShopLabel;
    }

    String primaryGenreId = '';
    var primaryGenreCount = 0;
    for (final e in genreCounts.entries) {
      if (e.value > primaryGenreCount) {
        primaryGenreCount = e.value;
        primaryGenreId = e.key;
      }
    }
    String primaryGenreName = '';
    if (primaryGenreId.isNotEmpty) {
      for (final p in products) {
        if (p.genreId.trim() == primaryGenreId && p.genreName.trim().isNotEmpty) {
          primaryGenreName = p.genreName.trim();
          break;
        }
      }
    }

    final itemCount = products.length;
    final averageReviewAverage =
        reviewSamples <= 0 ? 0.0 : reviewSum / reviewSamples;
    final averagePrice =
        priceSamples <= 0 ? 0.0 : priceSum / priceSamples;

    final score = ShopPoolScoring.compute(
      itemCount: itemCount,
      safeItemCount: safeItemCount,
      maxReviewCount: maxReviewCount,
      averageReviewAverage: averageReviewAverage,
      primaryGenreItemCount: primaryGenreCount,
    );

    return ShopPoolCandidate(
      shopCode: shopCode,
      shopName: shopName,
      shopUrl: shopUrl ?? '',
      representativeImageUrl: representativeImageUrl ?? '',
      primaryGenreId: primaryGenreId,
      primaryGenreName: primaryGenreName,
      itemCount: itemCount,
      safeItemCount: safeItemCount,
      itemsWithImage: itemsWithImage,
      itemsWithPrice: itemsWithPrice,
      averageReviewAverage: averageReviewAverage,
      maxReviewCount: maxReviewCount,
      averagePrice: averagePrice,
      minPrice: minPrice,
      maxPrice: maxPrice,
      score: score,
      sampleProductIds: List<String>.from(sourceProductIds),
      sourceGenres: sourceGenres.toList(growable: false),
      sourceProductIds: List<String>.from(sourceProductIds),
    );
  }

  static bool _isUsableShopDisplayName(String rawName, String shopCode) {
    final resolved = ShopDisplayResolve.resolveDisplayShopName(
      shopName: rawName,
      shopCode: shopCode,
    );
    return resolved != ShopDisplayResolve.unknownShopLabel;
  }

  static int _productImagePriority(CatalogProduct p) {
    var score = 0;
    if (p.qualityStatus.hasImage) score += 4;
    if (p.qualityStatus.hasPrice) score += 2;
    if (p.qualityStatus.hasValidUrl) score += 1;
    if (p.imageUrl.trim().isNotEmpty) score += 1;
    return score;
  }
}
