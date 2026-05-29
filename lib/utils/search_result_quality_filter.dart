import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import 'product_safety_filter.dart';
import 'room_import_product_image.dart';

/// 検索結果の品質ゲートで除外した理由（ログ・under100分類用）。
enum SearchQualityExcludeReason {
  noName,
  noImage,
  noPrice,
  noUrl,
  safety,
  reviewCount,
  reviewAverage,
}

/// 探すタブ向け: ROOM 投稿候補として弱い商品を除外する判定。
abstract final class SearchResultQualityFilter {
  static const _placeholderItemName = '（商品名なし）';

  /// 商品名が空、またはマッピング時のプレースホルダのみ。
  static bool hasDisplayableName(RakutenSearchItem item) {
    final name = item.itemName.trim();
    if (name.isEmpty) return false;
    if (name == _placeholderItemName) return false;
    return true;
  }

  /// 有効な http(s) 商品画像 URL。
  static bool hasDisplayableImage(RakutenSearchItem item) {
    final url = item.imageUrl.trim();
    if (url.isEmpty) return false;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      return false;
    }
    if (RoomImportProductImage.isRejectedProductImageUrl(url)) {
      return false;
    }
    return true;
  }

  /// 価格が 0 以下は「価格なし」扱い。
  static bool hasDisplayablePrice(RakutenSearchItem item) => item.itemPrice > 0;

  /// 商品ページ URL（アフィリエイトのみは不可）。
  static bool hasDisplayableProductUrl(RakutenSearchItem item) {
    return item.itemUrl.trim().isNotEmpty &&
        RegExp(r'^https?://', caseSensitive: false)
            .hasMatch(item.itemUrl.trim());
  }

  /// 条件・安全・品質を通過するか。除外理由があれば返す。
  static SearchQualityExcludeReason? exclusionReason(
    RakutenSearchItem item, {
    RakutenProductSearchCondition? condition,
    bool checkSafety = true,
  }) {
    if (!hasDisplayableName(item)) {
      return SearchQualityExcludeReason.noName;
    }
    if (!hasDisplayableProductUrl(item)) {
      return SearchQualityExcludeReason.noUrl;
    }
    if (!hasDisplayableImage(item)) {
      return SearchQualityExcludeReason.noImage;
    }
    if (!hasDisplayablePrice(item)) {
      return SearchQualityExcludeReason.noPrice;
    }
    if (checkSafety &&
        ProductSafetyFilter.isBlockedProduct(
          itemName: item.itemName,
          shopName: item.shopName,
          genreName: item.genreName,
          itemUrl: item.itemUrl,
          affiliateUrl: item.affiliateUrl,
        )) {
      return SearchQualityExcludeReason.safety;
    }
    if (condition != null) {
      final c = condition.normalized();
      final thresholdComment = c.minCommentCount;
      final thresholdReview = c.minReviewCount;
      final requiredReviewCount = switch ((thresholdComment, thresholdReview)) {
        (null, null) => null,
        (final n?, null) => n,
        (null, final n?) => n,
        (final a?, final b?) => a > b ? a : b,
      };
      if (requiredReviewCount != null &&
          item.reviewCount < requiredReviewCount) {
        return SearchQualityExcludeReason.reviewCount;
      }
      if (c.minReviewAverage != null &&
          item.reviewAverage < c.minReviewAverage!) {
        return SearchQualityExcludeReason.reviewAverage;
      }
    }
    return null;
  }

  static bool passesDisplayQuality(
    RakutenSearchItem item, {
    RakutenProductSearchCondition? condition,
    bool checkSafety = true,
  }) {
    return exclusionReason(
          item,
          condition: condition,
          checkSafety: checkSafety,
        ) ==
        null;
  }
}

