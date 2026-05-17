import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';

/// 商品画像 URL の表示用解決（保存済み imageUrl を正とする）。
abstract final class ProductImageResolve {
  static String displayImageUrlForManaged(RakutenManagedProduct product) {
    final url = product.imageUrl.trim();
    if (_isHttpUrl(url)) {
      return url;
    }
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
    final hasValid = _isHttpUrl(selected);
    final source = hasValid ? 'stored' : 'placeholder';
    _log(
      productId: product.productId,
      screen: screen,
      selectedSource: source,
      hasValidUrl: hasValid,
      selected: selected,
    );
  }

  static bool _isHttpUrl(String url) {
    final u = url.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  static void _log({
    required String productId,
    required String screen,
    required String selectedSource,
    required bool hasValidUrl,
    required String selected,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[PRODUCT_IMAGE_RESOLVE] screen=$screen productId=$productId '
      'selectedSource=$selectedSource hasValidUrl=$hasValidUrl '
      'selectedUrl=${selected.isEmpty ? '(empty)' : selected}',
    );
  }
}
