import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';

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

  static RakutenItemPageUrlParseResult tryParseItemRakutenPageUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return RakutenItemPageUrlParseFailure(messageNeedIchibaProductPageUrl);
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

  /// [items]（通常は管理 Provider の一覧）と照合し、UI 表示優先順位:
  /// コレ済 → コレ候補 → 未登録。
  static RakutenUrlRegistryClassification classifyAgainstManagedProducts({
    required List<RakutenManagedProduct> items,
    required String itemCode,
  }) {
    final id = itemCode.trim();
    if (id.isEmpty) return RakutenUrlRegistryClassification.unregistered;
    RakutenManagedProduct? found;
    for (final e in items) {
      if (e.productId.trim() == id) {
        found = e;
        break;
      }
    }
    if (found == null) return RakutenUrlRegistryClassification.unregistered;
    if (RakutenManagedProduct.isMemberForStatusTab(
      found,
      RakutenManagedProductStatus.done,
    )) {
      return RakutenUrlRegistryClassification.collectedDone;
    }
    if (RakutenManagedProduct.isMemberForStatusTab(
      found,
      RakutenManagedProductStatus.candidate,
    )) {
      return RakutenUrlRegistryClassification.candidate;
    }
    return RakutenUrlRegistryClassification.unregistered;
  }

  static RakutenItemPageUrlParseResult _parseItemHost(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) {
      return RakutenItemPageUrlParseFailure(messageNonProductPagesNotSupported);
    }
    final shop = segments[0].trim();
    final itemSeg = segments[1].trim();
    if (!_isValidShopCodeSegment(shop) || !_isNumericItemId(itemSeg)) {
      return RakutenItemPageUrlParseFailure(messageCouldNotConfirmProductUrl);
    }
    final itemCode = '$shop:$itemSeg';
    if (!kRakutenIchibaApiItemCodePattern.hasMatch(itemCode)) {
      return RakutenItemPageUrlParseFailure(messageCouldNotConfirmProductUrl);
    }
    return RakutenItemPageUrlParseSuccess(
      shopCode: shop,
      itemId: itemSeg,
      itemCode: itemCode,
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

  static bool _isNumericItemId(String s) => RegExp(r'^[0-9]+$').hasMatch(s);
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
  });

  final String shopCode;
  final String itemId;

  /// `shopCode:itemId`（API itemCode）。
  final String itemCode;
}

final class RakutenItemPageUrlParseFailure extends RakutenItemPageUrlParseResult {
  const RakutenItemPageUrlParseFailure(this.userMessage);

  final String userMessage;
}
