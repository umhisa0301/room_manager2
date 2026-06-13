import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'monetization_ad_placement.dart';

/// 配置種別に応じた広告プレースホルダー（実広告 SDK 未導入時の見た目確認用）。
class AdPlaceholderSlot extends StatelessWidget {
  const AdPlaceholderSlot({super.key, required this.placement});

  final MonetizationAdPlacement placement;

  @override
  Widget build(BuildContext context) {
    switch (placement) {
      case MonetizationAdPlacement.homeBottomBanner:
      case MonetizationAdPlacement.todayRecommendationSummaryBanner:
        return MonetizationBannerPlaceholder(placement: placement);
      case MonetizationAdPlacement.rakutenSearchNativeList:
        return MonetizationNativePlaceholder(placement: placement);
      case MonetizationAdPlacement.rewardedRecommendationRefresh:
        return const SizedBox.shrink();
    }
  }
}

/// バナー広告枠プレースホルダー（高さ 50〜70px 目安）。
class MonetizationBannerPlaceholder extends StatelessWidget {
  const MonetizationBannerPlaceholder({super.key, required this.placement});

  final MonetizationAdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final copy = _BannerCopy.forPlacement(placement, debugMode: kDebugMode);
    return Semantics(
      label: '広告',
      container: true,
      child: IgnorePointer(
        child: Container(
          key: Key('monetization_ad_slot_${placement.name}'),
          width: double.infinity,
          height: 60,
          margin: _marginForPlacement(placement),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.65),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _AdLabelChip(debugMode: kDebugMode),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        copy.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (copy.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          copy.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _marginForPlacement(MonetizationAdPlacement placement) {
    switch (placement) {
      case MonetizationAdPlacement.homeBottomBanner:
        return EdgeInsets.zero;
      case MonetizationAdPlacement.todayRecommendationSummaryBanner:
        return const EdgeInsets.fromLTRB(20, 2, 20, 8);
      case MonetizationAdPlacement.rakutenSearchNativeList:
      case MonetizationAdPlacement.rewardedRecommendationRefresh:
        return EdgeInsets.zero;
    }
  }
}

/// ネイティブ風広告枠プレースホルダー（高さ 88〜120px 目安）。
class MonetizationNativePlaceholder extends StatelessWidget {
  const MonetizationNativePlaceholder({super.key, required this.placement});

  final MonetizationAdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final copy = _NativeCopy.forPlacement(placement, debugMode: kDebugMode);
    return Semantics(
      label: '広告',
      container: true,
      child: IgnorePointer(
        child: Container(
          key: Key('monetization_ad_slot_${placement.name}'),
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.75),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 28,
                    color: AppColors.textTertiary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdLabelChip(debugMode: kDebugMode),
                      const SizedBox(height: 6),
                      Text(
                        copy.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (copy.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          copy.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdLabelChip extends StatelessWidget {
  const _AdLabelChip({required this.debugMode});

  final bool debugMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Text(
        '広告',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BannerCopy {
  const _BannerCopy({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  static _BannerCopy forPlacement(
    MonetizationAdPlacement placement, {
    required bool debugMode,
  }) {
    if (debugMode) {
      return switch (placement) {
        MonetizationAdPlacement.homeBottomBanner => const _BannerCopy(
          title: '広告枠',
          subtitle: 'Sponsored placeholder',
        ),
        MonetizationAdPlacement.todayRecommendationSummaryBanner =>
          const _BannerCopy(
            title: '広告枠',
            subtitle: '広告が表示されます',
          ),
        MonetizationAdPlacement.rakutenSearchNativeList ||
        MonetizationAdPlacement.rewardedRecommendationRefresh =>
          const _BannerCopy(title: '広告枠'),
      };
    }
    return switch (placement) {
      MonetizationAdPlacement.homeBottomBanner => const _BannerCopy(
        title: '広告が表示されます',
      ),
      MonetizationAdPlacement.todayRecommendationSummaryBanner =>
        const _BannerCopy(
          title: '広告が表示されます',
        ),
      MonetizationAdPlacement.rakutenSearchNativeList ||
      MonetizationAdPlacement.rewardedRecommendationRefresh =>
        const _BannerCopy(title: '広告が表示されます'),
    };
  }
}

class _NativeCopy {
  const _NativeCopy({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  static _NativeCopy forPlacement(
    MonetizationAdPlacement placement, {
    required bool debugMode,
  }) {
    if (debugMode) {
      return const _NativeCopy(
        title: '広告枠',
        subtitle: 'Sponsored placeholder',
      );
    }
    return const _NativeCopy(
      title: '広告が表示されます',
    );
  }
}
