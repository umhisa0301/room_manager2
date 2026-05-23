import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/debug_log_flags.dart';
import '../services/app_action_service.dart';

/// 商品カードから楽天（アフィリエイト優先）を開く共通処理。
abstract final class ProductCardRakutenOpen {
  static void auditCard({
    required String screen,
    required String cardType,
  }) {
    if (!kDebugMode || !DebugLogFlags.kVerboseItemLogsEnabled) return;
    debugPrint(
      '[PRODUCT_CARD_TAP_TARGET_AUDIT] screen=$screen cardType=$cardType '
      'imageTapOpensRakuten=true titleTapOpensRakuten=true usesAffiliateUrl=true '
      'fallback=itemUrl|none',
    );
  }

  static Future<void> open({
    required BuildContext context,
    required String? affiliateUrl,
    required String? itemUrl,
    required String screen,
    required String productId,
    required String source,
  }) async {
    final aff = affiliateUrl?.trim() ?? '';
    final item = itemUrl?.trim() ?? '';
    final url = aff.isNotEmpty ? aff : item;
    final hasAffiliate = aff.isNotEmpty;
    final hasItem = item.isNotEmpty;
    if (kDebugMode) {
      debugPrint(
        '[PRODUCT_OPEN_RAKUTEN] source=$source screen=$screen '
        'productId=$productId hasAffiliateUrl=$hasAffiliate '
        'hasItemUrl=$hasItem opened=${url.isNotEmpty}',
      );
    }
    if (url.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('楽天の商品ページURLが見つかりませんでした')),
      );
      return;
    }
    await AppActionService.openUrl(context, url: url);
  }
}
