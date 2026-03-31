import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../services/rakuten_api_service.dart';

/// APIレスポンスをアプリ用モデルへ変換する責務。
class RakutenSearchRepository {
  RakutenSearchRepository({required RakutenApiService apiService})
      : _apiService = apiService;

  final RakutenApiService _apiService;

  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
  }) async {
    final normalized = condition.normalized();
    final results = <RakutenSearchItem>[];
    // 最大5ページ分（約100件）を取得
    for (var page = 1; page <= 5; page++) {
      final raw = await _apiService.searchItems(
        condition: normalized,
        page: page,
        hits: 20,
      );
      final items = raw['Items'];
      if (items is! List || items.isEmpty) {
        break;
      }
      for (final entry in items) {
        final map = _unwrapItem(entry);
        final item = _mapToModel(map);
        if (item != null) results.add(item);
      }
      // API側で総ページ数などを見て早期終了してもよいが、現在は空ページでbreakする前提。
    }
    return _applyAppSideFilters(results, normalized);
  }

  Map<String, dynamic>? _unwrapItem(dynamic entry) {
    if (entry is Map<String, dynamic>) {
      // API仕様で "Item": {...} の場合とフラットな場合を吸収
      final nested = entry['Item'];
      if (nested is Map<String, dynamic>) return nested;
      return entry;
    }
    return null;
  }

  RakutenSearchItem? _mapToModel(Map<String, dynamic>? json) {
    if (json == null) return null;
    final productId = (json['itemCode'] ?? '').toString().trim();
    final itemName = (json['itemName'] ?? '').toString().trim();
    final itemUrl = (json['itemUrl'] ?? '').toString().trim();
    if (productId.isEmpty || itemName.isEmpty || itemUrl.isEmpty) return null;

    final itemPrice = (json['itemPrice'] as num?)?.toInt() ?? 0;
    final shopName = (json['shopName'] ?? '').toString().trim();
    final reviewCount = (json['reviewCount'] as num?)?.toInt() ?? 0;
    final reviewAverage = (json['reviewAverage'] as num?)?.toDouble() ?? 0;
    final affiliateUrl = (json['affiliateUrl'] ?? '').toString().trim();
    final shopCode = (json['shopCode'] ?? '').toString().trim();
    final shopUrl = (json['shopUrl'] ?? '').toString().trim();
    final genreId = (json['genreId'] ?? '').toString().trim();
    final imageUrl = _extractImageUrl(json);

    return RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
    );
  }

  String _extractImageUrl(Map<String, dynamic> json) {
    final medium = json['mediumImageUrls'];
    if (medium is List && medium.isNotEmpty) {
      final first = medium.first;
      if (first is Map<String, dynamic>) {
        return (first['imageUrl'] ?? '').toString();
      }
      return first.toString();
    }

    final small = json['smallImageUrls'];
    if (small is List && small.isNotEmpty) {
      final first = small.first;
      if (first is Map<String, dynamic>) {
        return (first['imageUrl'] ?? '').toString();
      }
      return first.toString();
    }

    return '';
  }

  List<RakutenSearchItem> _applyAppSideFilters(
    List<RakutenSearchItem> source,
    RakutenProductSearchCondition condition,
  ) {
    final thresholdComment = condition.minCommentCount;
    final thresholdReview = condition.minReviewCount;
    final requiredReviewCount = switch ((thresholdComment, thresholdReview)) {
      (null, null) => null,
      (final c?, null) => c,
      (null, final r?) => r,
      (final c?, final r?) => c > r ? c : r,
    };

    return source.where((item) {
      if (requiredReviewCount != null && item.reviewCount < requiredReviewCount) {
        return false;
      }
      if (condition.minReviewAverage != null &&
          item.reviewAverage < condition.minReviewAverage!) {
        return false;
      }
      if (condition.shopCode != null &&
          item.shopCode.trim() != condition.shopCode!.trim()) {
        return false;
      }
      if (condition.genreId != null &&
          !item.genreId.trim().contains(condition.genreId!.trim())) {
        return false;
      }
      return true;
    }).toList();
  }
}

