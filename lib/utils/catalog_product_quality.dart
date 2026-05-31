import '../models/catalog_product.dart';
import '../models/rakuten_search_item.dart';
import 'product_safety_filter.dart';
import 'room_import_product_image.dart';
import 'search_result_quality_filter.dart';

/// [CatalogProduct] 向け品質判定（既存フィルタのラッパー）。
abstract final class CatalogProductQuality {
  static CatalogProductQualityStatus evaluate(CatalogProduct product) {
    final hasValidUrl = _hasValidUrl(product.itemUrl);
    final hasImage = _hasImage(product.imageUrl);
    final hasPrice = product.itemPrice > 0;
    final reasons = ProductSafetyFilter.blockedReasons(
      itemName: product.itemName,
      itemCaption: product.itemCaption,
      shopName: product.shopName,
      genreName: product.genreName,
      itemUrl: product.itemUrl,
      affiliateUrl: product.affiliateUrl,
    );
    final safe = reasons.isEmpty;
    final blockedReason = safe
        ? ''
        : ProductSafetyFilter.primaryLogReason(reasons);

    return CatalogProductQualityStatus(
      hasImage: hasImage,
      hasPrice: hasPrice,
      hasValidUrl: hasValidUrl,
      safe: safe,
      blockedReason: blockedReason,
    );
  }

  /// [RakutenSearchItem] と同等基準の表示品質（安全判定含む）。
  static bool passesDisplayQuality(CatalogProduct product) {
    final item = _asSearchItem(product);
    return SearchResultQualityFilter.passesDisplayQuality(item);
  }

  static RakutenSearchItem _asSearchItem(CatalogProduct product) {
    return RakutenSearchItem(
      productId: product.productId.isNotEmpty
          ? product.productId
          : product.canonicalId,
      itemName: product.itemName,
      itemPrice: product.itemPrice,
      itemUrl: product.itemUrl,
      affiliateUrl: product.affiliateUrl,
      imageUrl: product.imageUrl,
      shopName: product.shopName,
      reviewCount: product.reviewCount,
      reviewAverage: product.reviewAverage,
      shopCode: product.shopCode,
      shopUrl: product.shopUrl,
      genreId: product.genreId,
      genreName: product.genreName,
    );
  }

  static bool _hasValidUrl(String url) {
    final t = url.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^https?://', caseSensitive: false).hasMatch(t);
  }

  static bool _hasImage(String imageUrl) {
    final url = imageUrl.trim();
    if (url.isEmpty) return false;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      return false;
    }
    if (RoomImportProductImage.isRejectedProductImageUrl(url)) {
      return false;
    }
    return true;
  }
}
