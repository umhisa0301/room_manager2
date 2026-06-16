import '../config/monetization_plan_config.dart';

/// プラン表示画面向けの文言・フォーマット（課金商品IDは含まない）。
abstract final class MonetizationPlanDisplayCopy {
  static const String basicPlannedMonthlyPriceLabel = '月額500円（予定）';
  static const String proPlannedMonthlyPriceLabel = '月額900円（予定）';
  static const String subscriptionPreparingNotice =
      'アプリ内課金は現在準備中です。Basicプランは近日対応予定です。';
  static const String basicComingSoonLabel = '近日対応予定';
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

/// 機能の利用可否表示。
String formatFeatureAvailability(bool enabled) => enabled ? '利用可' : '利用不可';

/// 広告表示の文言（Basic は未実装のため「予定」付き）。
String formatAdsDisplayForPlan(MonetizationPlan plan, MonetizationPlanLimits limits) {
  if (limits.adsRemoved) {
    return plan == MonetizationPlan.basic ? '広告なし（予定）' : '広告なし';
  }
  return '広告あり';
}

/// free / basic の差分比較行を [MonetizationPlanLimits] から生成する。
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
      freeValue:
          formatFeatureAvailability(freeLimits.advancedRakutenSearchSortEnabled),
      basicValue:
          formatFeatureAvailability(basicLimits.advancedRakutenSearchSortEnabled),
    ),
    const MonetizationPlanFeatureLine(
      label: '通常キーワード検索',
      freeValue: '利用可',
      basicValue: '利用可',
    ),
    const MonetizationPlanFeatureLine(
      label: '1件ずつ候補追加',
      freeValue: '利用可',
      basicValue: '利用可',
    ),
  ];
}

/// 無料版プランの機能一覧（単独表示用）。
List<String> buildFreePlanSummaryLines({
  MonetizationPlanLimits limits = kFreeMonetizationPlanLimits,
}) {
  return buildFreeBasicComparisonLines(freeLimits: limits, basicLimits: limits)
      .map((line) => '${line.label}：${line.freeValue}')
      .toList(growable: false);
}

/// Basicプランの機能一覧（単独表示用）。
List<String> buildBasicPlanSummaryLines({
  MonetizationPlanLimits limits = kBasicMonetizationPlanLimits,
}) {
  return buildFreeBasicComparisonLines(freeLimits: limits, basicLimits: limits)
      .map((line) => '${line.label}：${line.basicValue}')
      .toList(growable: false);
}
