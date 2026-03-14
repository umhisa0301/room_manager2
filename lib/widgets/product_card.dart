import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product_item.dart';

/// 商品一覧用のカード。楽天ROOM風の白カード＋角丸＋やさしい影。
/// 画像エリア・商品名・ショップ/URL・タグ・ステータス・コメント余白を表示。
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final ProductItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageArea(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingMd,
                  AppDimensions.spacingSm,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      item.shopOrUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.tags.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingSm),
                      _buildTags(context),
                    ],
                    const SizedBox(height: AppDimensions.spacingSm),
                    Row(
                      children: [
                        _buildStatusChip(context),
                        const Spacer(),
                        // コメント有無用の余白（将来アイコン等を表示）
                        if (item.hasComment)
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: AppColors.accentPrimary.withValues(alpha: 0.8),
                          )
                        else
                          const SizedBox(width: 18, height: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    const double imageHeight = 140;
    return Container(
      height: imageHeight,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderImage(imageHeight),
            )
          : _buildPlaceholderImage(imageHeight),
    );
  }

  Widget _buildPlaceholderImage(double height) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: AppColors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: item.tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentLightest,
                borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accentPrimary,
                      fontSize: 11,
                    ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusBackgroundColor(item.status),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      ),
      child: Text(
        item.status,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _statusTextColor(item.status),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
      ),
    );
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'コレ済':
        return AppColors.accentLight;
      case 'アーカイブ':
        return AppColors.surfaceVariant;
      default:
        return AppColors.accentLightest;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'コレ済':
      case '候補':
        return AppColors.accentPrimary;
      case 'アーカイブ':
        return AppColors.textSecondary;
      default:
        return AppColors.textPrimary;
    }
  }
}
