import 'package:flutter/material.dart';

import '../../config/monetization_config.dart';
import 'ad_placeholder_slot.dart';
import 'admob_banner_ad_slot.dart';
import 'monetization_ad_content_resolver.dart';
import 'monetization_ad_placement.dart';

export 'monetization_ad_placement.dart';

/// 収益化広告枠の共通入口。`ADS_ENABLED=false` では [SizedBox.shrink] を返す。
class MonetizationAdSlot extends StatelessWidget {
  const MonetizationAdSlot({
    super.key,
    required this.placement,
    this.adsEnabledOverride,
    this.loadAdMobForTesting,
  });

  final MonetizationAdPlacement placement;

  /// テスト用。未指定時は [MonetizationFlags.isAdsEnabled] を参照する。
  final bool? adsEnabledOverride;

  /// テスト用。`false` のとき [AdMobBannerAdSlot] の広告ロードをスキップする。
  final bool? loadAdMobForTesting;

  static Key keyForPlacement(MonetizationAdPlacement placement) {
    return Key('monetization_ad_slot_${placement.name}');
  }

  bool get _isVisible => adsEnabledOverride ?? MonetizationFlags.isAdsEnabled;

  @override
  Widget build(BuildContext context) {
    final content = resolveMonetizationAdContent(
      placement: placement,
      adsEnabled: _isVisible,
    );
    switch (content) {
      case MonetizationAdContentKind.none:
        return const SizedBox.shrink();
      case MonetizationAdContentKind.admobBanner:
        return AdMobBannerAdSlot(
          placement: placement,
          loadAdForTesting: loadAdMobForTesting,
        );
      case MonetizationAdContentKind.placeholder:
        return AdPlaceholderSlot(placement: placement);
    }
  }
}

/// 楽天検索結果リストにネイティブ広告枠を挿入するための index ヘルパー。
abstract final class RakutenSearchNativeAdListIndex {
  static const int insertAfterProductCount = 5;
  static const int adVirtualIndex = insertAfterProductCount;

  static bool shouldInsertNativeAd({
    required int productCount,
    required bool adsEnabled,
  }) {
    return adsEnabled && productCount >= insertAfterProductCount;
  }

  static int virtualItemCount({
    required int productCount,
    required bool adsEnabled,
  }) {
    return productCount +
        (shouldInsertNativeAd(
          productCount: productCount,
          adsEnabled: adsEnabled,
        )
            ? 1
            : 0);
  }

  static bool isAdVirtualIndex({
    required int virtualIndex,
    required int productCount,
    required bool adsEnabled,
  }) {
    return shouldInsertNativeAd(
          productCount: productCount,
          adsEnabled: adsEnabled,
        ) &&
        virtualIndex == adVirtualIndex;
  }

  static int productIndexForVirtualIndex({
    required int virtualIndex,
    required int productCount,
    required bool adsEnabled,
  }) {
    if (isAdVirtualIndex(
      virtualIndex: virtualIndex,
      productCount: productCount,
      adsEnabled: adsEnabled,
    )) {
      throw ArgumentError.value(
        virtualIndex,
        'virtualIndex',
        'Ad slot index has no product mapping',
      );
    }
    if (!shouldInsertNativeAd(
      productCount: productCount,
      adsEnabled: adsEnabled,
    )) {
      return virtualIndex;
    }
    return virtualIndex > adVirtualIndex ? virtualIndex - 1 : virtualIndex;
  }
}
