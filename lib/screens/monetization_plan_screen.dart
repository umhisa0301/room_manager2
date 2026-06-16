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
  static const double _wideLayoutBreakpoint = 520;

  @override
  Widget build(BuildContext context) {
    final snapshot = flags ?? MonetizationFlagSnapshot.fromCompileTime();
    final currentPlan = resolveCurrentMonetizationPlan(
      flags: snapshot,
      purchasedPlanOverride: purchasedPlanOverride,
    );
    final comparisonLines = buildFreeBasicComparisonLines();
    final freeFeatures = buildFreePlanCardFeatures();
    final basicFeatures = buildBasicPlanCardFeatures();

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
            LayoutBuilder(
              builder: (context, constraints) {
                final useSideBySide =
                    constraints.maxWidth >= _wideLayoutBreakpoint;
                if (useSideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FreePlanCard(features: freeFeatures),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BasicPlanCard(features: basicFeatures),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _FreePlanCard(features: freeFeatures),
                    const SizedBox(height: 12),
                    _BasicPlanCard(features: basicFeatures),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                MonetizationPlanDisplayCopy.freePlanFootnote,
                key: const Key('monetization_plan_free_footnote'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
              ),
            ),
            const SizedBox(height: _gap),
            _CoreComparisonSection(lines: comparisonLines),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

class _FreePlanCard extends StatelessWidget {
  const _FreePlanCard({required this.features});

  final List<MonetizationPlanCardFeature> features;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('monetization_plan_free_card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '無料版',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '0円',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          _PlanTaglineChip(
            label: MonetizationPlanDisplayCopy.freePlanTagline,
            emphasized: false,
          ),
          const SizedBox(height: 14),
          ...features.map(
            (feature) => _PlanFeatureRow(feature: feature),
          ),
        ],
      ),
    );
  }
}

class _BasicPlanCard extends StatelessWidget {
  const _BasicPlanCard({required this.features});

  final List<MonetizationPlanCardFeature> features;

  void _onComingSoonTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(MonetizationPlanDisplayCopy.preparingSnackBarMessage),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('monetization_plan_basic_card'),
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFFF8FAFF),
      borderColor: const Color(0xFFB8C8E8),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MonetizationPlanDisplayCopy.basicPlannedMonthlyPriceLabel,
                      key: const Key('monetization_plan_basic_price'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2F4A7A),
                          ),
                    ),
                  ],
                ),
              ),
              _PlanTaglineChip(
                label: MonetizationPlanDisplayCopy.basicPlanTagline,
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...features.map(
            (feature) => _PlanFeatureRow(feature: feature),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            key: const Key('monetization_plan_basic_coming_soon'),
            onPressed: () => _onComingSoonTap(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              MonetizationPlanDisplayCopy.basicComingSoonLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTaglineChip extends StatelessWidget {
  const _PlanTaglineChip({
    required this.label,
    required this.emphasized,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? const Color(0xFFE8EEF8)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasized
              ? const Color(0xFFB8C8E8)
              : AppColors.divider,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasized
                  ? const Color(0xFF2F4A7A)
                  : AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _PlanFeatureRow extends StatelessWidget {
  const _PlanFeatureRow({required this.feature});

  final MonetizationPlanCardFeature feature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              feature.muted ? Icons.remove_rounded : Icons.check_rounded,
              size: 16,
              color: feature.muted
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: feature.muted
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    height: 1.4,
                    fontWeight:
                        feature.muted ? FontWeight.w500 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreComparisonSection extends StatelessWidget {
  const _CoreComparisonSection({required this.lines});

  final List<MonetizationPlanFeatureLine> lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '主な違い',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '無料版とBasicの主要な差分です',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          _ComparisonTable(lines: lines),
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
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          height: 1.35,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          height: 1.35,
          color: AppColors.textPrimary,
        );

    return Table(
      key: const Key('monetization_plan_comparison_table'),
      columnWidths: const {
        0: FlexColumnWidth(2.4),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('無料版', style: headerStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Basic', style: headerStyle),
            ),
          ],
        ),
        ...lines.map(
          (line) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(line.label, style: labelStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(line.freeValue, style: valueStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(line.basicValue, style: valueStyle),
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
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proプラン（今後追加予定）',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            MonetizationPlanDisplayCopy.proPlannedMonthlyPriceLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'AIコメント生成、AI改善提案、条件指定一括処理などを検討中',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
