import 'package:flutter/material.dart';

import '../models/shop_discovery_summary.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

class ShopDiscoveryCard extends StatelessWidget {
  const ShopDiscoveryCard({
    super.key,
    required this.summary,
    required this.rank,
    required this.isSaved,
    required this.onOpenShop,
    required this.onSave,
  });

  final ShopDiscoverySummary summary;
  final int rank;
  final bool isSaved;
  final VoidCallback onOpenShop;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeScreenColors.roomMetricTileFill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: HomeScreenColors.roomMetricTileBorder),
        boxShadow: HomeScreenColors.roomMetricTileShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HomeScreenColors.flowStepBadgeFill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '#$rank',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: HomeScreenColors.statusAccentStrong,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  summary.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              if (isSaved)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HomeScreenColors.subActionRowFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: HomeScreenColors.deckOutline),
                  ),
                  child: Text(
                    '保存済み',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: HomeScreenColors.groupedSectionBody,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              _ScorePill(score: summary.discoveryScore),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfo(label: 'ヒット商品数', value: '${summary.hitItemCount}件'),
              _MiniInfo(label: '最大評価数', value: '${summary.maxReviewCount}'),
              _MiniInfo(
                label: '平均評価点',
                value: summary.avgReviewAverage.toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ThumbStrip(items: summary.representativeItems.take(3).toList()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenShop,
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('商品を見て候補登録'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSave,
                  icon: Icon(
                    isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                    size: 18,
                  ),
                  label: Text(isSaved ? '保存済み' : '保存する'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '売れ筋度 ${score.toStringAsFixed(1)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: HomeScreenColors.roomContentWellFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeScreenColors.deckOutline),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.metricTileCaptionColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.items});
  final List<ShopRepresentativeItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        '代表商品がありません',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: _ThumbItem(item: items[i])),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ThumbItem extends StatelessWidget {
  const _ThumbItem({required this.item});
  final ShopRepresentativeItem item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 58,
        color: HomeScreenColors.candidateThumbPlaceholder.withValues(alpha: 0.35),
        child: item.imageUrl.trim().isEmpty
            ? Icon(
                Icons.image_outlined,
                color: HomeScreenColors.footnoteMuted,
              )
            : Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: HomeScreenColors.footnoteMuted,
                ),
              ),
      ),
    );
  }
}
