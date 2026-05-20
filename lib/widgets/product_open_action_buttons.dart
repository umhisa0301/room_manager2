import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import 'app_button.dart';

/// 商品カード共通：ROOM / 楽天の小型アウトラインボタン。
class ProductOpenActionButtons extends StatelessWidget {
  const ProductOpenActionButtons({
    super.key,
    required this.product,
    this.compact = true,
    this.screen = 'productCard',
    this.logStyleAudit = false,
  });

  final RakutenManagedProduct product;
  final bool compact;
  final String screen;
  final bool logStyleAudit;

  @override
  Widget build(BuildContext context) {
    if (logStyleAudit && kDebugMode) {
      debugPrint(
        '[ANALYTICS_REACTION_PRODUCT_BUTTON_STYLE] screen=$screen '
        'compact=$compact usesOutlineButton=true height=${compact ? 36 : 40}',
      );
    }

    final roomUrl = product.roomUrl.trim();
    final rakutenUrl = product.rakutenOpenUrl.trim();
    final height = compact ? 36.0 : 40.0;
    const gap = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 280;
        final itemWidth = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemWidth,
              child: AppOutlineButton(
                label: '楽天で見る',
                icon: const Icon(Icons.open_in_new, size: 16),
                height: height,
                expand: true,
                onPressed: rakutenUrl.isEmpty
                    ? null
                    : () => _openRakuten(context),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: AppOutlineButton(
                label: 'ROOMで見る',
                icon: const Icon(Icons.open_in_new, size: 16),
                height: height,
                expand: true,
                onPressed: roomUrl.isEmpty
                    ? null
                    : () => unawaited(
                          AppActionService.openUrl(context, url: roomUrl),
                        ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openRakuten(BuildContext context) async {
    if (kDebugMode) {
      debugPrint(
        '[PRODUCT_CARD_AFFILIATE_TAP_TARGET] screen=$screen '
        'productId=${product.productId.trim()} target=rakutenButton',
      );
    }
    final err = await context
        .read<RakutenManagedProductProvider>()
        .openRakutenItemPage(context, product.productId);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }
}
