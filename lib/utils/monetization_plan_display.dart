import '../config/monetization_plan_config.dart';

/// プラン表示画面向けの文言・フォーマット（課金商品IDは含まない）。
abstract final class MonetizationPlanDisplayCopy {
  static const String basicPlannedMonthlyPriceLabel = '月額500円（予定）';
  static const String proPlannedMonthlyPriceLabel = '月額900円（予定）';
  static const String subscriptionPreparingNotice =
      'アプリ内課金は現在準備中です。Basicプランは近日対応予定です。';
  static const String basicComingSoonLabel = '近日対応予定';
  static const String preparingSnackBarMessage = '現在準備中です';
  static const String freePlanTagline = 'お試しプラン';
  static const String basicPlanTagline = 'よく使う人向け';
  static const String freePlanFootnote =
      '無料版でも通常キーワード検索・1件ずつ候補追加は使えます';
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

/// 広告表示の文言（Basic は未実装のため「予定」付き）。
String formatAdsDisplayForPlan(MonetizationPlan plan, MonetizationPlanLimits limits) {
  if (limits.adsRemoved) {
    return plan == MonetizationPlan.basic ? 'なし（予定）' : 'なし';
  }
  return 'あり';
}

/// 楽天検索の詳細条件の比較表表示。
String formatAdvancedRakutenSearchComparisonValue(
  MonetizationPlanLimits limits,
) {
  if (limits.advancedRakutenSearchSortEnabled) {
    return '価格・並び順・詳細条件';
  }
  return '通常検索のみ';
}

/// free / basic の主要差分比較行を [MonetizationPlanLimits] から生成する。
List<MonetizationPlanFeatureLine> buildFreeBasicComparisonLines({
  MonetizationPlanLimits freeLimits = kFreeMonetizationPlanLimits,
  MonetizationPlanLimits basicLimits = kBasicMonetizationPlanLimits,
}) {
  return [
    MonetizationPlanFeatureLine(
      label: '広告',
      freeValue: formatAdsDisplayForPlan(MonetizationPlan.free, freeLimits),
      basicValue: formatAdsDisplayForPlan(MonetizationPlan.basic, basicLimits),
    ),
    MonetizationPlanFeatureLine(
      label: 'ROOMデータ更新 / 管理商品数',
      freeValue: formatRoomImportLimitDisplay(freeLimits.roomImportLimitPerRun),
      basicValue: formatRoomImportLimitDisplay(basicLimits.roomImportLimitPerRun),
    ),
    MonetizationPlanFeatureLine(
      label: 'おすすめコレ生成',
      freeValue: formatDailyCountDisplay(freeLimits.dailyRecommendationLimit),
      basicValue: formatDailyCountDisplay(basicLimits.dailyRecommendationLimit),
    ),
    MonetizationPlanFeatureLine(
      label: 'おすすめコレ再生成',
      freeValue: formatDailyCountDisplay(freeLimits.dailyRecommendationRefreshLimit),
      basicValue:
          formatDailyCountDisplay(basicLimits.dailyRecommendationRefreshLimit),
    ),
    MonetizationPlanFeatureLine(
      label: 'おすすめコレ一括追加',
      freeValue: formatFeatureAvailability(freeLimits.batchCandidateAddEnabled),
      basicValue: formatFeatureAvailability(basicLimits.batchCandidateAddEnabled),
    ),
    MonetizationPlanFeatureLine(
      label: '楽天検索の一括追加',
      freeValue: formatFeatureAvailability(freeLimits.batchCandidateAddEnabled),
      basicValue: formatFeatureAvailability(basicLimits.batchCandidateAddEnabled),
    ),
    MonetizationPlanFeatureLine(
      label: '楽天検索の詳細条件',
      freeValue: formatAdvancedRakutenSearchComparisonValue(freeLimits),
      basicValue: formatAdvancedRakutenSearchComparisonValue(basicLimits),
    ),
  ];
}

/// 無料版プランカードの機能箇条書き。
List<MonetizationPlanCardFeature> buildFreePlanCardFeatures({
  MonetizationPlanLimits limits = kFreeMonetizationPlanLimits,
}) {
  return [
    MonetizationPlanCardFeature(
      text: formatAdsDisplayForPlan(MonetizationPlan.free, limits) == 'あり'
          ? '広告あり'
          : '広告なし',
    ),
    MonetizationPlanCardFeature(
      text:
          'ROOMデータ更新 / 管理商品数: ${formatRoomImportLimitDisplay(limits.roomImportLimitPerRun)}',
    ),
    MonetizationPlanCardFeature(
      text:
          'おすすめコレ生成 / 再生成: 各${formatDailyCountDisplay(limits.dailyRecommendationLimit)}',
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
          'ROOMデータ更新 / 管理商品数: ${formatRoomImportLimitDisplay(limits.roomImportLimitPerRun)}',
    ),
    MonetizationPlanCardFeature(
      text:
          'おすすめコレ生成 / 再生成: 各${formatDailyCountDisplay(limits.dailyRecommendationLimit)}',
    ),
    MonetizationPlanCardFeature(
      text: limits.batchCandidateAddEnabled ? '一括追加が使える' : '一括追加は利用不可',
    ),
    MonetizationPlanCardFeature(
      text: limits.advancedRakutenSearchSortEnabled
          ? '価格・並び順などの詳細検索が使える'
          : '詳細検索は利用不可',
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
