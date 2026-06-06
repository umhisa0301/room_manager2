import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../utils/rakuten_ichiba_url_parse.dart';
import '../utils/rakuten_product_url_support.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';

/// 楽天市場 **商品ページ** URL から [RakutenManagedProduct.productId] 形式の itemCode を取り出す。
///
/// 永続化・API の `itemCode` は **`shopCode:数字ID`**（例: `soukaidrink:4901085161999`）と一致させる。
///
/// 将来、短縮URLやROOMアプリ共有URLの **リダイレクト解決** を
/// VPS / Firebase Functions などに逃がす場合は、
/// [RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl] の前段に
/// 「解決済み canonical URL を返すバックエンド」を差し込む設計にできる（本クラスは純関数のまま）。
abstract final class RakutenItemPageUrlItemCodeService {
  RakutenItemPageUrlItemCodeService._();

  /// ユーザー向け（重大エラーは BottomSheet 内表示用）。
  static const String messageCouldNotConfirmProductUrl = '商品URLを確認できませんでした';

  static const String messageNeedIchibaProductPageUrl =
      '楽天市場の商品ページURLを貼り付けてください';

  static const String messageNonProductPagesNotSupported =
      '検索結果・ショップトップ・カテゴリページは登録できません';

  static const String messageUnsupportedRakutenServiceUrl =
      RakutenProductUrlSupport.messageUnsupportedRakutenServiceUrl;

  static RakutenItemPageUrlParseResult tryParseItemRakutenPageUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return RakutenItemPageUrlParseFailure(messageNeedIchibaProductPageUrl);
    }

    final unsupported = RakutenProductUrlSupport.detectUnsupported(trimmed);
    if (unsupported != null) {
      urlSearchUnsupportedLog(
        'inputUrl=${_logTrimUrl(trimmed)} reason=${unsupported.reason} '
        'host=${unsupported.host} service=${unsupported.serviceTag}',
      );
      urlSearchResultLog(
        'success=false reason=unsupportedUrlType host=${unsupported.host}',
      );
      return RakutenItemPageUrlParseFailure(
        unsupported.userMessage,
        unsupportedReason: unsupported.reason,
        host: unsupported.host,
      );
    }

    final normalizedUrl =
        RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl(trimmed);
    if (normalizedUrl != null && normalizedUrl.trim().isNotEmpty) {
      final normUri = Uri.tryParse(normalizedUrl.trim());
      if (normUri != null && normUri.hasAuthority) {
        return _parseItemHost(normUri, normalizedUrl: normalizedUrl.trim());
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) {
      return RakutenItemPageUrlParseFailure(messageNeedIchibaProductPageUrl);
    }

    final host = uri.host.toLowerCase();

    if (!_hostIsRakuten(host)) {
      return RakutenItemPageUrlParseFailure(messageNeedIchibaProductPageUrl);
    }

    if (_isExcludedNonProductRakutenPage(uri)) {
      return RakutenItemPageUrlParseFailure(messageNonProductPagesNotSupported);
    }

    if (host == 'item.rakuten.co.jp' || host.endsWith('.item.rakuten.co.jp')) {
      return _parseItemHost(uri);
    }

    // 楽天だが item.rakuten の商品パターンではない（他サービス・フロント入口など）
    return RakutenItemPageUrlParseFailure(messageNeedIchibaProductPageUrl);
  }

  /// [items] から URL 解析結果に一致する行を返す（ROOM 取り込みの slug productId も照合）。
  static RakutenManagedProduct? findManagedProductForParsedUrl({
    required List<RakutenManagedProduct> items,
    required RakutenItemPageUrlParseSuccess parsed,
  }) {
    final composite = parsed.itemCode.trim();
    final slug = parsed.itemId.trim();
    final shop = parsed.shopCode.trim();
    if (composite.isEmpty) return null;
    for (final e in items) {
      final pid = e.productId.trim();
      if (pid.isEmpty) continue;
      if (pid == composite) return e;
      if (slug.isNotEmpty && shop.isNotEmpty && pid == slug) {
        if (e.shopCode.trim() == shop) return e;
      }
    }
    return null;
  }

  /// [items]（通常は管理 Provider の一覧）と照合し、UI 表示優先順位:
  /// コレ済 → コレ候補 → 未登録。
  static RakutenUrlRegistryClassification classifyAgainstManagedProducts({
    required List<RakutenManagedProduct> items,
    required String itemCode,
  }) {
    final id = itemCode.trim();
    if (id.isEmpty) return RakutenUrlRegistryClassification.unregistered;
    final colon = id.indexOf(':');
    RakutenItemPageUrlParseSuccess? synthetic;
    if (colon > 0 && colon < id.length - 1) {
      synthetic = RakutenItemPageUrlParseSuccess(
        shopCode: id.substring(0, colon).trim(),
        itemId: id.substring(colon + 1).trim(),
        itemCode: id,
        isApiStyleItemCode: rakutenIchibaUrlLooksLikeApiItemCode(id),
      );
    }
    final found = synthetic != null
        ? findManagedProductForParsedUrl(items: items, parsed: synthetic)
        : null;
    RakutenManagedProduct? resolved = found;
    if (resolved == null) {
      for (final e in items) {
        if (e.productId.trim() == id) {
          resolved = e;
          break;
        }
      }
    }
    if (resolved == null) return RakutenUrlRegistryClassification.unregistered;
    if (RakutenManagedProduct.isMemberForStatusTab(
      resolved,
      RakutenManagedProductStatus.done,
    )) {
      return RakutenUrlRegistryClassification.collectedDone;
    }
    if (RakutenManagedProduct.isMemberForStatusTab(
      resolved,
      RakutenManagedProductStatus.candidate,
    )) {
      return RakutenUrlRegistryClassification.candidate;
    }
    return RakutenUrlRegistryClassification.unregistered;
  }

  static RakutenItemPageUrlParseResult _parseItemHost(
    Uri uri, {
    String? normalizedUrl,
  }) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) {
      return RakutenItemPageUrlParseFailure(messageNonProductPagesNotSupported);
    }
    final shop = segments[0].trim();
    final itemSeg = segments[1].trim();
    if (!_isValidShopCodeSegment(shop) || !_isValidItemPathSegment(itemSeg)) {
      return RakutenItemPageUrlParseFailure(messageCouldNotConfirmProductUrl);
    }
    final itemCode = '$shop:$itemSeg';
    return RakutenItemPageUrlParseSuccess(
      shopCode: shop,
      itemId: itemSeg,
      itemCode: itemCode,
      isApiStyleItemCode: rakutenIchibaUrlLooksLikeApiItemCode(itemCode),
      normalizedUrl: normalizedUrl ??
          RoomRakutenUrlNormalize.canonicalItemRakutenUrl(
            shopCode: shop,
            itemPathSegment: itemSeg,
          ),
    );
  }

  static bool _hostIsRakuten(String hostLower) {
    return hostLower == 'rakuten.co.jp' ||
        hostLower.endsWith('.rakuten.co.jp') ||
        hostLower.endsWith('.rakuten.ne.jp');
  }

  /// 検索・カテゴリ・ショップトップ等（商品詳細の item.rakuten 2セグメント形式以外）。
  static bool _isExcludedNonProductRakutenPage(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (host.contains('search.rakuten')) return true;

    if (host == 'www.rakuten.co.jp' || host == 'rakuten.co.jp') {
      if (segments.isEmpty) return false;
      final head = segments.first.toLowerCase();
      const nonProductHeads = {
        'search',
        'category',
        's',
        'ranking',
        'event',
        'basket',
        'my',
        'order',
      };
      if (nonProductHeads.contains(head)) return true;
    }

    return false;
  }

  /// [rakuten_ichiba_url_parse] の店舗パス相当と整合。
  static bool _isValidShopCodeSegment(String s) {
    final t = s.trim();
    if (t.isEmpty || t.length > 160) return false;
    return RegExp(r'^[0-9A-Za-z\-_%]+$').hasMatch(t);
  }

  static bool _isValidItemPathSegment(String s) {
    final t = s.trim();
    if (t.isEmpty || t.length > 160) return false;
    return RegExp(r'^[0-9A-Za-z\-_%]+$').hasMatch(t);
  }

  static String _logTrimUrl(String s, {int max = 180}) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}

/// [RakutenProductSearchCondition.itemCode] / 保存 [RakutenManagedProduct.productId] と同型か。
@visibleForTesting
final RegExp kRakutenIchibaApiItemCodePattern = RegExp(r'^[^:\s]+:[0-9]+$');

/// URL から抽出後の一覧照合結果。
enum RakutenUrlRegistryClassification {
  collectedDone,
  candidate,
  unregistered,
}

sealed class RakutenItemPageUrlParseResult {
  const RakutenItemPageUrlParseResult();
}

final class RakutenItemPageUrlParseSuccess extends RakutenItemPageUrlParseResult {
  const RakutenItemPageUrlParseSuccess({
    required this.shopCode,
    required this.itemId,
    required this.itemCode,
    this.isApiStyleItemCode = false,
    this.normalizedUrl = '',
  });

  final String shopCode;
  final String itemId;

  /// `shopCode:itemId`（API itemCode または URL スラッグ composite）。
  final String itemCode;

  /// 楽天 Item Search の direct itemCode 形式（`shop:数字`）か。
  final bool isApiStyleItemCode;

  /// 正規化済み item.rakuten URL（ログ・API 照合用）。
  final String normalizedUrl;
}

final class RakutenItemPageUrlParseFailure extends RakutenItemPageUrlParseResult {
  const RakutenItemPageUrlParseFailure(
    this.userMessage, {
    this.unsupportedReason = '',
    this.host = '',
  });

  final String userMessage;

  /// 対象外 URL のとき `unsupportedRakutenService` 等。
  final String unsupportedReason;

  final String host;

  bool get isUnsupportedUrlType => unsupportedReason.isNotEmpty;
}
