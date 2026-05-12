// ROOM 取り込みメタ補完で、保存済み productId と楽天API商品を URL で突き合わせる。
// 画像URL（mediumImageUrls / imageUrl）は商品ページパスとして信頼しない。
// itemUrl / affiliateUrl 系および API 生マップのモバイル系アフィリエイトのみ見る。

import '../models/rakuten_search_item.dart';

/// `soukaidrink:4901085161999` → `4901085161999` のように、URLパス照合に使うセグメント。
String roomImportUrlPathMatchSegment(String storedProductId) {
  final t = storedProductId.trim();
  if (t.isEmpty) return '';
  if (t.contains(':')) {
    final r = t.substring(t.lastIndexOf(':') + 1).trim();
    return r.isNotEmpty ? r : t;
  }
  return t;
}

bool _urlContainsSegment(String? url, String segmentLower) {
  final u = (url ?? '').trim().toLowerCase();
  if (u.isEmpty) return false;
  return u.contains(segmentLower);
}

/// 楽天 Item Search の1件と ROOM 保存 `productId` が同一商品か、**商品URLのパス**で判定する。
bool roomImportSearchItemUrlsMatchStoredProduct({
  required RakutenSearchItem item,
  Map<String, dynamic>? rawItemMap,
  required String storedProductId,
}) {
  final seg = roomImportUrlPathMatchSegment(storedProductId);
  if (seg.isEmpty) return false;
  final sl = seg.toLowerCase();

  if (_urlContainsSegment(item.itemUrl, sl)) return true;
  if (_urlContainsSegment(item.affiliateUrl, sl)) return true;

  final m = rawItemMap;
  if (m == null) return false;

  if (_urlContainsSegment(m['affiliateUrlMobile']?.toString(), sl)) return true;
  if (_urlContainsSegment(m['mobileUrl']?.toString(), sl)) return true;
  if (_urlContainsSegment(m['affiliateURL']?.toString(), sl)) return true;
  if (_urlContainsSegment(m['itemUrl']?.toString(), sl)) return true;

  return false;
}
