import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../state/saved_shop_provider.dart';
import 'analytics_unknown_label.dart';
import 'room_reaction_analytics.dart';
import 'shop_display_resolve.dart';

/// 分析タブから「反応が多いショップ」検索へ遷移する。
abstract final class AnalyticsShopSearchLauncher {
  static ({String shopCode, String shopName, int score})? topReactedShop(
    List<RakutenManagedProduct> items,
  ) {
    final reacted = items
        .where(roomReactionAnalyticsIsEligible)
        .where(roomReactionAnalyticsHasReaction)
        .toList(growable: false);
    if (reacted.isEmpty) return null;

    final scores = <String, ({String shopName, int score})>{};
    for (final p in reacted) {
      if (!roomReactionAnalyticsShopTrendEligible(p)) continue;
      final code = p.shopCode.trim();
      if (code.isEmpty) continue;
      final name = p.shopName.trim();
      final sum = roomReactionAnalyticsReactionSum(p);
      final prev = scores[code];
      scores[code] = (
        shopName: name.isNotEmpty ? name : (prev?.shopName ?? ''),
        score: (prev?.score ?? 0) + sum,
      );
    }
    if (scores.isEmpty) return null;

    final top = scores.entries.reduce((a, b) => a.value.score >= b.value.score ? a : b);
    return (
      shopCode: top.key,
      shopName: top.value.shopName,
      score: top.value.score,
    );
  }

  static Future<void> launchShopSearch(
    BuildContext context, {
    required String shopCode,
    required String shopName,
    String screen = 'analytics',
  }) async {
    final code = shopCode.trim();
    if (code.isEmpty) return;
    await _openSearch(
      context,
      shopCode: code,
      shopName: shopName,
      screen: screen,
    );
  }

  static Future<void> launchTopShopSearch(
    BuildContext context, {
    required List<RakutenManagedProduct> items,
    String screen = 'analytics',
  }) async {
    final top = topReactedShop(items);
    if (top == null) {
      if (kDebugMode) {
        debugPrint(
          '[ANALYTICS_SHOP_SEARCH_CTA] screen=$screen launched=false reason=noEligibleShop',
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ショップ名が確認できた商品がまだありません'),
          ),
        );
      }
      return;
    }

    await _openSearch(
      context,
      shopCode: top.shopCode,
      shopName: top.shopName,
      screen: screen,
    );
  }

  static Future<void> _openSearch(
    BuildContext context, {
    required String shopCode,
    required String shopName,
    required String screen,
  }) async {
    final displayName = ShopDisplayResolve.resolveDisplayShopName(
      shopName: shopName,
      shopCode: shopCode,
      screen: screen,
    );
    if (kDebugMode) {
      debugPrint(
        '[ANALYTICS_SHOP_NAME_RESOLVE] shopCode=$shopCode '
        'shopName=${shopName.isEmpty ? '-' : shopName} '
        'displayName=$displayName resolved=${displayName != ShopDisplayResolve.unknownShopLabel}',
      );
    }
    if (displayName == ShopDisplayResolve.unknownShopLabel ||
        AnalyticsUnknownLabel.isUnknownShopLabel(
          shopName,
          shopCode: shopCode,
        )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ショップ名を確認中のため、検索はあとでお試しください'),
          ),
        );
      }
      return;
    }

    final saved = context.read<SavedShopProvider>();
    final isSaved = saved.isSaved(shopCode);
    if (kDebugMode) {
      debugPrint(
        '[ANALYTICS_SHOP_SEARCH_CTA] screen=$screen launched=true '
        'shopCode=$shopCode shopName=$displayName mode=${isSaved ? 'savedShop' : 'productShopScope'}',
      );
    }

    if (isSaved) {
      await openRakutenSearchScreen(
        context,
        savedShopKeywordEntry: true,
        initialSavedShopCode: shopCode,
      );
      return;
    }

    await openRakutenSearchScreen(
      context,
      initialScopedShopCode: shopCode,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$displayName」で商品を探せます。保存ショップに追加すると次回から選びやすくなります'),
      ),
    );
  }
}
