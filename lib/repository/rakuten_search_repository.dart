import '../models/rakuten_search_item.dart';
import '../services/rakuten_api_service.dart';

/// APIレスポンスをアプリ用モデルへ変換する責務。
class RakutenSearchRepository {
  RakutenSearchRepository({required RakutenApiService apiService})
      : _apiService = apiService;

  final RakutenApiService _apiService;

  Future<List<RakutenSearchItem>> search({
    required String keyword,
  }) async {
    final raw = await _apiService.searchItems(keyword: keyword);
    final items = raw['Items'];
    if (items is! List) return [];

    final results = <RakutenSearchItem>[];
    for (final entry in items) {
      final map = _unwrapItem(entry);
      final item = _mapToModel(map);
      if (item != null) results.add(item);
    }
    return results;
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
    final affiliateUrl = (json['affiliateUrl'] ?? '').toString().trim();
    final imageUrl = _extractImageUrl(json);

    return RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
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
}

