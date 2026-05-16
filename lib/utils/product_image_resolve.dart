import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';

/// 商品画像 URL の表示用解決（ROOM / API / 空）。
abstract final class ProductImageResolve {
  static String displayImageUrlForManaged(RakutenManagedProduct product) {
    final api = product.imageUrl.trim();
    if (_isHttpUrl(api)) {
      _log(
        productId: product.productId,
        screen: 'managed',
        hasRoomImage: false,
        hasApiImage: true,
        selected: api,
        reason: 'api',
      );
      return api;
    }
    _log(
      productId: product.productId,
      screen: 'managed',
      hasRoomImage: false,
      hasApiImage: false,
      selected: '',
      reason: 'empty',
    );
    return '';
  }

  static String displayImageUrlForSearchItem(RakutenSearchItem item) {
    final url = item.imageUrl.trim();
    if (_isHttpUrl(url)) return url;
    return '';
  }

  static void logForScreen({
    required RakutenManagedProduct product,
    required String screen,
  }) {
    final selected = displayImageUrlForManaged(product);
    final hasApi = product.imageUrl.trim().isNotEmpty;
    _log(
      productId: product.productId,
      screen: screen,
      hasRoomImage: false,
      hasApiImage: hasApi,
      selected: selected,
      reason: selected.isEmpty ? 'empty' : 'api',
    );
  }

  static bool _isHttpUrl(String url) {
    final u = url.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  static void _log({
    required String productId,
    required String screen,
    required bool hasRoomImage,
    required bool hasApiImage,
    required String selected,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[PRODUCT_IMAGE_RESOLVE] productId=$productId screen=$screen '
      'hasRoomImage=$hasRoomImage hasApiImage=$hasApiImage '
      'selectedImageUrl=${selected.isEmpty ? '(empty)' : selected} reason=$reason',
    );
  }
}
