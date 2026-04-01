import 'package:flutter/foundation.dart';

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
    // 最大5ページ分（約100件）を取得 — 逐次・1ページ失敗時は可能な範囲で継続
    for (var page = 1; page <= 5; page++) {
      try {
        if (page > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        final raw = await _apiService.searchItems(
          condition: normalized,
          page: page,
          hits: 20,
        );
        final items = raw['Items'];
        if (items is! List || items.isEmpty) {
          if (kDebugMode) {
            debugPrint('[Rakuten] page=$page empty Items — stop pagination');
          }
          break;
        }
        var parsedOnPage = 0;
        for (final entry in items) {
          try {
            final map = _unwrapItem(entry);
            final item = _mapToModel(map);
            if (item != null) {
              results.add(item);
              parsedOnPage++;
            }
          } catch (e, st) {
            if (kDebugMode) {
              debugPrint('[Rakuten] item map/parse skipped page=$page: $e');
              debugPrint('$st');
            }
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] page=$page parsedItems=$parsedOnPage / raw=${items.length}',
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Rakuten] page fetch failed page=$page: $e');
          debugPrint('$st');
        }
        if (page == 1) {
          rethrow;
        }
        break;
      }
    }
    if (kDebugMode) {
      debugPrint('[Rakuten] repository search total mapped=${results.length}');
    }
    try {
      return _applyAppSideFilters(results, normalized);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Rakuten] app-side filter failed: $e');
        debugPrint('$st');
      }
      return results;
    }
  }

  Map<String, dynamic>? _unwrapItem(dynamic entry) {
    if (entry is! Map) return null;
    final flat = Map<String, dynamic>.from(entry);
    final nested = flat['Item'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return flat;
  }

  RakutenSearchItem? _mapToModel(Map<String, dynamic>? json) {
    if (json == null) return null;

    var productId = _stringField(json['itemCode']).trim();
    var itemName = _stringField(json['itemName']).trim();
    var affiliateUrl = _stringField(json['affiliateUrl']).trim();
    var itemUrl = _stringField(json['itemUrl']).trim();
    if (itemUrl.isEmpty && affiliateUrl.isNotEmpty) {
      itemUrl = affiliateUrl;
    }
    if (itemName.isEmpty) {
      itemName = '（商品名なし）';
    }
    if (productId.isEmpty) {
      if (itemUrl.isNotEmpty) {
        productId = itemUrl;
      } else if (itemName.isNotEmpty) {
        productId = 'noid:${itemName.hashCode}';
      } else {
        return null;
      }
    }
    if (itemUrl.isEmpty) {
      return null;
    }

    final itemPrice = _parseIntLoose(json['itemPrice']);
    var shopName = _stringField(json['shopName']).trim();
    if (shopName.isEmpty) {
      shopName = 'ショップ名不明';
    }
    final reviewCount = _parseIntLoose(json['reviewCount']);
    final reviewAverage = _parseDoubleLoose(json['reviewAverage']);
    final shopCode = _stringField(json['shopCode']).trim();
    final shopUrl = _stringField(json['shopUrl']).trim();
    final genreId = _stringField(json['genreId']).trim();
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

  String _stringField(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  int _parseIntLoose(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
  }

  double _parseDoubleLoose(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  String _extractImageUrl(Map<String, dynamic> json) {
    String fromList(dynamic list) {
      if (list is! List || list.isEmpty) return '';
      final first = list.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        return _stringField(m['imageUrl']).trim();
      }
      return _stringField(first).trim();
    }

    final medium = fromList(json['mediumImageUrls']);
    if (medium.isNotEmpty) return medium;

    final small = fromList(json['smallImageUrls']);
    if (small.isNotEmpty) return small;

    final single = _stringField(json['imageUrl']).trim();
    if (single.isNotEmpty) return single;

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
