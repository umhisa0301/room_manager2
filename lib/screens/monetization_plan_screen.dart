import 'package:flutter/material.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../theme/app_theme.dart';
import '../utils/monetization_plan_display.dart';
import '../widgets/app_card.dart';

/// プラン内容の案内画面（課金処理は行わない）。
class MonetizationPlanScreen extends StatelessWidget {
  const MonetizationPlanScreen({
    super.key,
    this.flags,
    this.purchasedPlanOverride,
  });

  /// テスト用。未指定時はコンパイル時フラグ。
  final MonetizationFlagSnapshot? flags;
  final MonetizationPlan? purchasedPlanOverride;

  static const double _screenPadH = AppDimensions.screenPaddingH;
  static const double _gap = AppDimensions.spacingMd;

  @override
  Widget build(BuildContext context) {
    final snapshot = flags ?? MonetizationFlagSnapshot.fromCompileTime();
    final currentPlan = resolveCurrentMonetizationPlan(
      flags: snapshot,
      purchasedPlanOverride: purchasedPlanOverride,
    );
    final comparisonLines = buildFreeBasicComparisonLines();
    final freeSummary = buildFreePlanSummaryLines();
    final basicSummary = buildBasicPlanSummaryLines();

    return Scaffold(
      key: const Key('monetization_plan_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('プランを見る')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            _screenPadH,
            AppDimensions.spacingMd,
            _screenPadH,
            AppDimensions.spacingLg,
          ),
          children: [
            _CurrentPlanBanner(plan: currentPlan),
            const SizedBox(height: _gap),
            _PreparingNoticeBanner(),
            const SizedBox(height: _gap),
            _PlanSectionCard(
              title: '無料版でできること',
              subtitle: 'いまお使いいただいているプランです',
              icon: Icons.check_circle_outline_rounded,
              lines: freeSummary,
            ),
            const SizedBox(height: _gap),
            _BasicPlanCard(
              summaryLines: basicSummary,
              comparisonLines: comparisonLines,
            ),
            const SizedBox(height: _gap),
            const _ProPlanTeaserCard(),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({required this.plan});

  final MonetizationPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '現在のプラン',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            monetizationPlanDisplayName(plan),
            key: const Key('monetization_plan_current_label'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _PreparingNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: const Color(0xFFFFF8E8),
      borderColor: const Color(0xFFFFE0A3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              MonetizationPlanDisplayCopy.subscriptionPreparingNotice,
              key: const Key('monetization_plan_preparing_notice'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSectionCard extends StatelessWidget {
  const _PlanSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.lines,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '・$line',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicPlanCard extends StatelessWidget {
  const _BasicPlanCard({
    required this.summaryLines,
    required this.comparisonLines,
  });

  final List<String> summaryLines;
  final List<MonetizationPlanFeatureLine> comparisonLines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: 'Basicプランで増えること',
            subtitle: '広告なし・便利機能の拡張（予定）',
            icon: Icons.workspace_premium_outlined,
          ),
          const SizedBox(height: 10),
          Text(
            MonetizationPlanDisplayCopy.basicPlannedMonthlyPriceLabel,
            key: const Key('monetization_plan_basic_price'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          ...summaryLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '・$line',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '無料版との主な違い',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          _ComparisonTable(lines: comparisonLines),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              key: const Key('monetization_plan_basic_coming_soon'),
              label: Text(MonetizationPlanDisplayCopy.basicComingSoonLabel),
              backgroundColor: AppColors.surfaceVariant,
              side: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.lines});

  final List<MonetizationPlanFeatureLine> lines;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        );
    final cellStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          height: 1.35,
          color: AppColors.textPrimary,
        );

    return Table(
      key: const Key('monetization_plan_comparison_table'),
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('無料版', style: headerStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Basic', style: headerStyle),
            ),
          ],
        ),
        ...lines.map(
          (line) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(line.label, style: cellStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(line.freeValue, style: cellStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(line.basicValue, style: cellStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProPlanTeaserCard extends StatelessWidget {
  const _ProPlanTeaserCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('monetization_plan_pro_teaser'),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proプラン（今後追加予定）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            MonetizationPlanDisplayCopy.proPlannedMonthlyPriceLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'AIコメント生成、AI改善提案、条件指定一括処理などを検討しています。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
