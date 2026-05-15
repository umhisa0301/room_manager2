// ROOM 取り込みメタ補完で、ROOM 側 shopCode / urlProductCode と楽天API候補を突き合わせる。
// 画像URL（mediumImageUrls / imageUrl）は商品ページパスとして信頼しない。
// itemUrl / affiliateUrl 系および API 生マップのモバイル系アフィリエイトのみ見る。

import '../models/rakuten_search_item.dart';
import 'room_import_learned_api_code.dart';

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

/// API 候補と ROOM 保存商品の同一性評価結果（ログ・採用判定用）。
class RoomImportApiCandidateMatch {
  const RoomImportApiCandidateMatch({
    required this.shopMatched,
    required this.priceMatched,
    required this.urlSlugMatched,
    required this.mobileItemLearned,
    required this.matched,
    required this.reason,
    this.decodedPcUrl = '',
    this.decodedMobileUrl = '',
  });

  final bool shopMatched;
  final bool priceMatched;
  final bool urlSlugMatched;
  final bool mobileItemLearned;
  final bool matched;
  final String reason;
  final String decodedPcUrl;
  final String decodedMobileUrl;
}

bool _urlContainsSegment(String? url, String segmentLower) {
  final u = (url ?? '').trim().toLowerCase();
  if (u.isEmpty) return false;
  return u.contains(segmentLower);
}

bool roomImportUrlContainsShopAndSlug({
  required String? url,
  required String roomShopCode,
  required String roomUrlProductCode,
}) {
  final shop = roomShopCode.trim().toLowerCase();
  final slug = roomUrlProductCode.trim().toLowerCase();
  if (shop.isEmpty || slug.isEmpty) return false;
  final u = (url ?? '').trim().toLowerCase();
  if (u.isEmpty) return false;
  return u.contains('/$shop/$slug/') || u.contains('/$shop/$slug?');
}

String? _decodeAffiliatePcUrl(String? affiliateUrl) {
  final t = (affiliateUrl ?? '').trim();
  if (t.isEmpty) return null;
  try {
    final u = Uri.parse(t);
    final pc = u.queryParameters['pc'] ?? u.queryParameters['PC'];
    if (pc == null || pc.trim().isEmpty) return null;
    return Uri.decodeComponent(pc.trim());
  } catch (_) {
    return null;
  }
}

String? _decodeAffiliateMobileUrl(String? affiliateUrl) {
  final t = (affiliateUrl ?? '').trim();
  if (t.isEmpty) return null;
  try {
    final u = Uri.parse(t);
    final mRaw = u.queryParameters['m'] ?? u.queryParameters['M'];
    if (mRaw == null || mRaw.trim().isEmpty) return null;
    return Uri.decodeComponent(mRaw.trim());
  } catch (_) {
    return null;
  }
}

bool _mobileItemLearnedMatchesShop({
  required RakutenSearchItem item,
  required String roomShopCode,
}) {
  final learned = RoomImportLearnedApiCode.tryParseFromSearchItem(item);
  if (learned == null) return false;
  final composite = learned.$1.trim();
  final idx = composite.indexOf(':');
  if (idx <= 0) return false;
  final shop = composite.substring(0, idx).trim();
  return shop.isNotEmpty && shop == roomShopCode.trim();
}

/// 楽天 Item Search の1件が ROOM 保存商品と同一か評価する。
///
/// 必須: API 候補の [shopCode] が ROOM 側 [roomShopCode] と一致。
/// さらに URL スラッグ一致またはモバイル URL からの itemCode 学習のいずれか。
/// 価格一致のみでは同一商品としない。
RoomImportApiCandidateMatch roomImportEvaluateApiCandidateMatch({
  required RakutenSearchItem item,
  Map<String, dynamic>? rawItemMap,
  required String roomShopCode,
  required String roomUrlProductCode,
  int? roomPrice,
}) {
  final shop = roomShopCode.trim();
  final slug = roomUrlProductCode.trim();
  final candidateShop = item.shopCode.trim();
  final shopMatched = shop.isNotEmpty && candidateShop == shop;

  final rp = roomPrice;
  final priceMatched = rp != null &&
      rp > 0 &&
      item.itemPrice > 0 &&
      item.itemPrice == rp;

  var urlSlugMatched = false;
  if (shopMatched && slug.isNotEmpty) {
    if (roomImportUrlContainsShopAndSlug(
      url: item.itemUrl,
      roomShopCode: shop,
      roomUrlProductCode: slug,
    )) {
      urlSlugMatched = true;
    }
    final pc = _decodeAffiliatePcUrl(item.affiliateUrl);
    if (!urlSlugMatched &&
        roomImportUrlContainsShopAndSlug(
          url: pc,
          roomShopCode: shop,
          roomUrlProductCode: slug,
        )) {
      urlSlugMatched = true;
    }
    final m = rawItemMap;
    if (!urlSlugMatched && m != null) {
      for (final k in const [
        'itemUrl',
        'affiliateUrl',
        'affiliateUrlMobile',
        'mobileUrl',
        'affiliateURL',
      ]) {
        final raw = m[k]?.toString();
        if (roomImportUrlContainsShopAndSlug(
          url: raw,
          roomShopCode: shop,
          roomUrlProductCode: slug,
        )) {
          urlSlugMatched = true;
          break;
        }
        final pcRaw = _decodeAffiliatePcUrl(raw);
        if (roomImportUrlContainsShopAndSlug(
          url: pcRaw,
          roomShopCode: shop,
          roomUrlProductCode: slug,
        )) {
          urlSlugMatched = true;
          break;
        }
      }
    }
    if (!urlSlugMatched) {
      final sl = slug.toLowerCase();
      if (_urlContainsSegment(item.itemUrl, sl) ||
          _urlContainsSegment(item.affiliateUrl, sl)) {
        urlSlugMatched = roomImportUrlContainsShopAndSlug(
          url: item.itemUrl,
          roomShopCode: shop,
          roomUrlProductCode: slug,
        ) ||
            roomImportUrlContainsShopAndSlug(
              url: _decodeAffiliatePcUrl(item.affiliateUrl),
              roomShopCode: shop,
              roomUrlProductCode: slug,
            );
      }
    }
  }

  final mobileItemLearned =
      shopMatched && slug.isNotEmpty && _mobileItemLearnedMatchesShop(
        item: item,
        roomShopCode: shop,
      );

  final decodedPcUrl = _decodeAffiliatePcUrl(item.affiliateUrl) ?? '';
  final decodedMobileUrl = _decodeAffiliateMobileUrl(item.affiliateUrl) ?? '';

  if (!shopMatched) {
    return RoomImportApiCandidateMatch(
      shopMatched: false,
      priceMatched: priceMatched,
      urlSlugMatched: urlSlugMatched,
      mobileItemLearned: false,
      matched: false,
      reason: 'shopMismatch',
      decodedPcUrl: decodedPcUrl,
      decodedMobileUrl: decodedMobileUrl,
    );
  }

  if (urlSlugMatched) {
    return RoomImportApiCandidateMatch(
      shopMatched: true,
      priceMatched: priceMatched,
      urlSlugMatched: true,
      mobileItemLearned: mobileItemLearned,
      matched: true,
      reason: 'shopAndPriceAndUrlSlugMatched',
      decodedPcUrl: decodedPcUrl,
      decodedMobileUrl: decodedMobileUrl,
    );
  }

  if (mobileItemLearned) {
    return RoomImportApiCandidateMatch(
      shopMatched: true,
      priceMatched: priceMatched,
      urlSlugMatched: false,
      mobileItemLearned: true,
      matched: true,
      reason: 'shopAndMobileItemLearned',
      decodedPcUrl: decodedPcUrl,
      decodedMobileUrl: decodedMobileUrl,
    );
  }

  if (priceMatched) {
    return RoomImportApiCandidateMatch(
      shopMatched: true,
      priceMatched: true,
      urlSlugMatched: false,
      mobileItemLearned: false,
      matched: false,
      reason: 'priceMatchedButUrlMismatch',
      decodedPcUrl: decodedPcUrl,
      decodedMobileUrl: decodedMobileUrl,
    );
  }

  return RoomImportApiCandidateMatch(
    shopMatched: true,
    priceMatched: priceMatched,
    urlSlugMatched: false,
    mobileItemLearned: false,
    matched: false,
    reason: slug.isEmpty ? 'noUrlProductCode' : 'noUrlMatch',
    decodedPcUrl: decodedPcUrl,
    decodedMobileUrl: decodedMobileUrl,
  );
}

/// 楽天 Item Search の1件と ROOM 保存 `productId` が同一商品か、**商品URLのパス**で判定する。
bool roomImportSearchItemUrlsMatchStoredProduct({
  required RakutenSearchItem item,
  Map<String, dynamic>? rawItemMap,
  required String storedProductId,
  String? urlPathMatchSegment,
  String? roomShopCode,
}) {
  final overrideSeg = (urlPathMatchSegment ?? '').trim();
  final seg = overrideSeg.isNotEmpty
      ? overrideSeg
      : roomImportUrlPathMatchSegment(storedProductId);
  if (seg.isEmpty) return false;

  final shop = (roomShopCode ?? '').trim();
  if (shop.isNotEmpty) {
    final eval = roomImportEvaluateApiCandidateMatch(
      item: item,
      rawItemMap: rawItemMap,
      roomShopCode: shop,
      roomUrlProductCode: seg,
    );
    return eval.matched;
  }

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
