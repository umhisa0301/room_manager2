import 'package:flutter/material.dart';

import '../models/rakuten_search_item.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../utils/product_price_display.dart';

/// 投稿準備モーダル内の商品サマリー（サムネ・名前・価格・評価）。
class RoomPostPrepareProductSummary extends StatelessWidget {
  const RoomPostPrepareProductSummary({
    super.key,
    required this.item,
  });

  final RakutenSearchItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'room_post_prepare_product_summary',
      child: KeyedSubtree(
        key: const Key('room_post_prepare_product_summary'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: AppColors.surfaceVariant,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.imageUrl.trim().isEmpty
                      ? const Icon(
                          Icons.image_outlined,
                          color: AppColors.textTertiary,
                        )
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: HomeScreenColors.homeTextPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ProductPriceDisplay.formatYen(item.itemPrice),
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w900,
                      color: HomeScreenColors.homeTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'レビュー ${item.reviewAverage.toStringAsFixed(2)} / '
                    '${item.reviewCount}件',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: HomeScreenColors.homeTextSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
