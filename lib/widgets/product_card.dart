import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../models/product_search_hit.dart';

/// 商品一覧用カード。左に画像・右に詳細の横並び（楽天・Amazon検索結果風）。
/// 白カード＋角丸＋やわらかい影で一覧の視認性を優先。
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.matchKinds = const [],
    this.highlightSearchState = false,
  });

  final Product product;
  final VoidCallback? onTap;
  final List<ProductMatchKind> matchKinds;
  final bool highlightSearchState;

  static const double _thumbnailSize = 80;
  static const double _cardPadding = 12;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 2),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(),
              const SizedBox(width: 10),
              Expanded(child: _buildDetails(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: _thumbnailSize,
        height: _thumbnailSize,
        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
            ? Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.productName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          product.displayUrlOrShop,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (matchKinds.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildMatchKinds(context),
        ],
        if (product.tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildTags(context),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStatusChip(context),
            if (product.quickComment != null &&
                product.quickComment!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.quickComment!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const SizedBox(width: 18, height: 18),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchKinds(BuildContext context) {
    final labels = matchKinds.take(2).map((e) => e.label).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accentPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: product.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentLightest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tag,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.accentPrimary,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final status = product.status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: highlightSearchState
            ? Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.45))
            : null,
      ),
      child: Text(
        highlightSearchState ? '状態: ${status.label}' : status.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _statusFg(status),
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _statusBg(ProductStatus s) {
    switch (s) {
      case ProductStatus.collected:
        return AppColors.accentLight;
      case ProductStatus.archived:
        return AppColors.surfaceVariant;
      default:
        return AppColors.accentLightest;
    }
  }

  Color _statusFg(ProductStatus s) {
    switch (s) {
      case ProductStatus.archived:
        return AppColors.textSecondary;
      default:
        return AppColors.accentPrimary;
    }
  }
}
