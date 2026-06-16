import '../config/billing_product_config.dart';
import '../config/monetization_plan_config.dart';
import '../services/billing_product_service.dart';

/// プラン表示画面向けの文言・フォーマット（課金商品IDは含まない）。
abstract final class MonetizationPlanDisplayCopy {
  static const String basicPlannedMonthlyPriceLabel = '月額500円（予定）';
  static const String basicPriceAmount = '500';
  static const String freePriceAmount = '0';
  static const String proPlannedMonthlyPriceLabel = '月額900円（予定）';
  static const String proPriceAmount = '900';
  static const String subscriptionPreparingNotice =
      'アプリ内課金は現在準備中です。Basicプランは近日対応予定です。';
  static const String basicComingSoonLabel = '近日対応予定';
  static const String preparingSnackBarMessage = '現在準備中です';
  static const String billingStatusChecking = '商品情報を確認中';
  static const String billingStatusFetchFailed = '商品情報を取得できませんでした';
  static const String basicPriceLoadingLabel = '価格確認中';
  static const String freePlanTagline = 'お試しプラン';
  static const String basicPlanTagline = 'よく使う人向け';
  static const String basicRecommendedLabel = 'おすすめ';
  static const String currentPlanChipLabel = '現在利用中';
  static const String freePlanFootnote =
      '通常検索と1件ずつ候補追加は使えます';
}

/// プラン比較表の1行。
class MonetizationPlanFeatureLine {
  const MonetizationPlanFeatureLine({
    required this.label,
    required this.freeValue,
    required this.basicValue,
  });

  final String label;
  final String freeValue;
  final String basicValue;
}

/// プランカード内の機能箇条書き1行。
class MonetizationPlanCardFeature {
  const MonetizationPlanCardFeature({
    required this.text,
    this.muted = false,
  });

  final String text;
  final bool muted;
}

/// 画面表示用のプラン名。
String monetizationPlanDisplayName(MonetizationPlan plan) {
  switch (plan) {
    case MonetizationPlan.free:
      return '無料版';
    case MonetizationPlan.basic:
      return 'Basicプラン';
    case MonetizationPlan.pro:
      return 'Proプラン';
  }
}

/// [roomImportLimitPerRun] の表示文言。
String formatRoomImportLimitDisplay(int? limit) {
  if (limit == null) return '上限なし';
  return '$limit件まで';
}

/// 1日回数制限の表示文言。
String formatDailyCountDisplay(int count) => '1日$count回';

/// 機能の利用可否表示（比較表向け・短縮）。
String formatFeatureAvailability(bool enabled) => enabled ? '○' : '×';

/// 広告表示の文言（比較表向け）。
String formatAdsComparisonValue(MonetizationPlan plan, MonetizationPlanLimits limits) {
  if (limits.adsRemoved) {
    return plan == MonetizationPlan.basic ? 'なし予定' : 'なし';
  }
  return 'あり';
}

/// 楽天検索の詳細条件の比較表表示（カード補足向け）。
String formatAdvancedRakutenSearchComparisonValue(
  MonetizationPlanLimits limits,
) {
  if (limits.advancedRakutenSearchSortEnabled) {
    return '価格・並び順・詳細条件';
  }
  return '通常検索のみ';
}

/// free / basic の主要差分比較行を [MonetizationPlanLimits] から生成する（6項目）。
List<MonetizationPlanFeatureLine> buildFreeBasicComparisonLines({
  MonetizationPlanLimits freeLimits = kFreeMonetizationPlanLimits,
  MonetizationPlanLimits basicLimits = kBasicMonetizationPlanLimits,
}) {
  return [
    MonetizationPlanFeatureLine(
      label: '広告',
      freeValue: formatAdsComparisonValue(MonetizationPlan.free, freeLimits),
      basicValue: formatAdsComparisonValue(MonetizationPlan.basic, basicLimits),
    ),
    MonetizationPlanFeatureLine(
      label: 'ROOM更新',
      freeValue: formatRoomImportLimitDisplay(freeLimits.roomImportLimitPerRun),
      basicValue: formatRoomImportLimitDisplay(basicLimits.roomImportLimitPerRun),
    ),
    MonetizationPlanFeatureLine(
      label: 'おすすめ生成',
      freeValue: formatDailyCountDisplay(freeLimits.dailyRecommendationLimit),
      basicValue: formatDailyCountDisplay(basicLimits.dailyRecommendationLimit),
    ),
    MonetizationPlanFeatureLine(
      label: 'おすすめ再生成',
      freeValue: formatDailyCountDisplay(freeLimits.dailyRecommendationRefreshLimit),
      basicValue:
          formatDailyCountDisplay(basicLimits.dailyRecommendationRefreshLimit),
    ),
    MonetizationPlanFeatureLine(
      label: '一括追加',
      freeValue: formatFeatureAvailability(freeLimits.batchCandidateAddEnabled),
      basicValue: formatFeatureAvailability(basicLimits.batchCandidateAddEnabled),
    ),
    MonetizationPlanFeatureLine(
      label: '詳細検索',
      freeValue:
          formatFeatureAvailability(freeLimits.advancedRakutenSearchSortEnabled),
      basicValue:
          formatFeatureAvailability(basicLimits.advancedRakutenSearchSortEnabled),
    ),
  ];
}

/// 無料版プランカードの機能箇条書き。
List<MonetizationPlanCardFeature> buildFreePlanCardFeatures({
  MonetizationPlanLimits limits = kFreeMonetizationPlanLimits,
}) {
  return [
    MonetizationPlanCardFeature(
      text: formatAdsComparisonValue(MonetizationPlan.free, limits) == 'あり'
          ? '広告あり'
          : '広告なし',
    ),
    MonetizationPlanCardFeature(
      text:
          'ROOM更新 ${formatRoomImportLimitDisplay(limits.roomImportLimitPerRun)}',
    ),
    MonetizationPlanCardFeature(
      text:
          'おすすめ各${formatDailyCountDisplay(limits.dailyRecommendationLimit)}',
    ),
    const MonetizationPlanCardFeature(
      text: '一括追加・詳細検索はBasic向け',
      muted: true,
    ),
  ];
}

/// Basicプランカードの機能箇条書き。
List<MonetizationPlanCardFeature> buildBasicPlanCardFeatures({
  MonetizationPlanLimits limits = kBasicMonetizationPlanLimits,
}) {
  return [
    MonetizationPlanCardFeature(
      text: limits.adsRemoved ? '広告なし（予定）' : '広告あり',
    ),
    MonetizationPlanCardFeature(
      text:
          'ROOM更新 ${formatRoomImportLimitDisplay(limits.roomImportLimitPerRun)}',
    ),
    MonetizationPlanCardFeature(
      text:
          'おすすめ各${formatDailyCountDisplay(limits.dailyRecommendationLimit)}',
    ),
    MonetizationPlanCardFeature(
      text: limits.batchCandidateAddEnabled ? '一括追加OK' : '一括追加×',
    ),
    MonetizationPlanCardFeature(
      text: limits.advancedRakutenSearchSortEnabled ? '詳細検索OK' : '詳細検索×',
    ),
  ];
}

/// 無料版プランの機能一覧（単独表示用・後方互換）。
List<String> buildFreePlanSummaryLines({
  MonetizationPlanLimits limits = kFreeMonetizationPlanLimits,
}) {
  return buildFreePlanCardFeatures(limits: limits)
      .map((feature) => feature.text)
      .toList(growable: false);
}

/// Basicプランの機能一覧（単独表示用・後方互換）。
List<String> buildBasicPlanSummaryLines({
  MonetizationPlanLimits limits = kBasicMonetizationPlanLimits,
}) {
  return buildBasicPlanCardFeatures(limits: limits)
      .map((feature) => feature.text)
      .toList(growable: false);
}

/// 比較表のBasic列値を強調表示するか。
bool shouldEmphasizeBasicComparisonValue(String value) {
  if (value == '○' || value == '上限なし') return true;
  if (value.contains('5回') || value.contains('なし予定')) return true;
  return false;
}

/// 比較表の無料版列値を控えめにするか。
bool shouldMuteFreeComparisonValue(String value) => value == '×';

/// プラン価格の表示ソース。
enum MonetizationPlanPriceSource {
  loading,
  store,
  planned,
}

/// プラン価格表示用の解決結果。
class MonetizationPlanPriceDisplay {
  const MonetizationPlanPriceDisplay({
    required this.label,
    required this.source,
    this.showMonthlyPrefix = false,
    this.showPlannedSuffix = false,
    this.useStorePriceFormat = false,
  });

  final String label;
  final MonetizationPlanPriceSource source;
  final bool showMonthlyPrefix;
  final bool showPlannedSuffix;

  /// true のとき [label] をそのまま表示（ストアのローカライズ価格）。
  final bool useStorePriceFormat;
}

/// Basic プランの価格表示を解決する。
MonetizationPlanPriceDisplay resolveBasicPlanPriceDisplay({
  required bool isLoading,
  BillingProductQueryResult? queryResult,
}) {
  if (isLoading) {
    return const MonetizationPlanPriceDisplay(
      label: MonetizationPlanDisplayCopy.basicPriceLoadingLabel,
      source: MonetizationPlanPriceSource.loading,
      showMonthlyPrefix: true,
    );
  }

  final basic = queryResult?.basic;
  if (basic != null && basic.available) {
    return MonetizationPlanPriceDisplay(
      label: basic.price,
      source: MonetizationPlanPriceSource.store,
      useStorePriceFormat: true,
    );
  }

  return const MonetizationPlanPriceDisplay(
    label: MonetizationPlanDisplayCopy.basicPriceAmount,
    source: MonetizationPlanPriceSource.planned,
    showMonthlyPrefix: true,
    showPlannedSuffix: true,
  );
}

/// Pro プラン（ティザー）の価格ラベルを解決する。
String resolveProPlanPriceLabel({
  required bool isLoading,
  BillingProductQueryResult? queryResult,
}) {
  if (isLoading) {
    return MonetizationPlanDisplayCopy.billingStatusChecking;
  }

  final pro = queryResult?.pro;
  if (pro != null && pro.available) {
    return pro.price;
  }

  return MonetizationPlanDisplayCopy.proPlannedMonthlyPriceLabel;
}

/// 商品照会の UI ステータス文言。表示不要なら null。
String? resolveBillingStatusMessage({
  required bool isLoading,
  BillingProductQueryResult? queryResult,
}) {
  if (isLoading) {
    return MonetizationPlanDisplayCopy.billingStatusChecking;
  }
  if (queryResult == null) {
    return null;
  }
  if (!queryResult.available) {
    return MonetizationPlanDisplayCopy.billingStatusFetchFailed;
  }
  if (queryResult.basic == null && queryResult.pro == null) {
    return MonetizationPlanDisplayCopy.billingStatusFetchFailed;
  }
  return null;
}

/// 商品照会を行うべきか（プラン画面向け）。
bool shouldQueryBillingProducts({
  required bool monetizationEnabled,
  required bool subscriptionEnabled,
}) {
  return monetizationEnabled && subscriptionEnabled;
}

/// テスト用: 照会スキップ時のフォールバック結果。
BillingProductQueryResult createPlannedFallbackBillingQueryResult() {
  return BillingProductQueryResult.fromProducts(
    products: const [],
    notFoundIds: BillingProductConfig.allProductIds,
  );
}
