import 'monetization_ad_placement.dart';

/// [MonetizationAdSlot] が描画するコンテンツ種別。
enum MonetizationAdContentKind {
  none,
  admobBanner,
  placeholder,
}

/// 広告枠の表示分岐（単体テスト用の純粋関数）。
MonetizationAdContentKind resolveMonetizationAdContent({
  required MonetizationAdPlacement placement,
  required bool adsEnabled,
}) {
  if (!adsEnabled) {
    return MonetizationAdContentKind.none;
  }
  if (placement == MonetizationAdPlacement.homeBottomBanner ||
      placement == MonetizationAdPlacement.todayRecommendationSummaryBanner) {
    return MonetizationAdContentKind.admobBanner;
  }
  return MonetizationAdContentKind.placeholder;
}
