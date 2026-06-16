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

  static const Color _basicAccentBg = Color(0xFFFFF5F9);
  static const Color _basicAccentBorder = Color(0xFFF0B8D4);
  static const Color _basicAccentText = Color(0xFFC21872);
  static const Color _basicColumnBg = Color(0xFFFFF8FB);
  static const Color _stripeEven = Color(0xFFF8F8FA);

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
    final showCurrentOnFree = currentPlan == MonetizationPlan.free;

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
                        child: _BasicPlanCard(features: basicFeatures),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FreePlanCard(
                          features: freeFeatures,
                          showCurrentChip: showCurrentOnFree,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _BasicPlanCard(features: basicFeatures),
                    const SizedBox(height: 12),
                    _FreePlanCard(
                      features: freeFeatures,
                      showCurrentChip: showCurrentOnFree,
                    ),
                  ],
                );
              },
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

class _PreparingNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: const Color(0xFFFFF8E8),
      borderColor: const Color(0xFFFFE0A3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              MonetizationPlanDisplayCopy.subscriptionPreparingNotice,
              key: const Key('monetization_plan_preparing_notice'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPriceDisplay extends StatelessWidget {
  const _PlanPriceDisplay({
    required this.amount,
    this.showMonthlyPrefix = false,
    this.showPlannedSuffix = false,
    this.accentColor,
    this.priceKey,
  });

  final String amount;
  final bool showMonthlyPrefix;
  final bool showPlannedSuffix;
  final Color? accentColor;
  final Key? priceKey;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMonthlyPrefix)
          Text(
            '月額',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount,
              key: priceKey,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
            ),
            Text(
              '円',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            if (showPlannedSuffix) ...[
              const SizedBox(width: 4),
              Text(
                '（予定）',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  const _FreePlanCard({
    required this.features,
    required this.showCurrentChip,
  });

  final List<MonetizationPlanCardFeature> features;
  final bool showCurrentChip;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('monetization_plan_free_card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showCurrentChip)
                _PlanTaglineChip(
                  key: const Key('monetization_plan_current_label'),
                  label: MonetizationPlanDisplayCopy.currentPlanChipLabel,
                  variant: _PlanChipVariant.current,
                ),
              _PlanTaglineChip(
                label: MonetizationPlanDisplayCopy.freePlanTagline,
                variant: _PlanChipVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '無料版',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          const _PlanPriceDisplay(
            amount: MonetizationPlanDisplayCopy.freePriceAmount,
            priceKey: Key('monetization_plan_free_price'),
          ),
          const SizedBox(height: 12),
          ...features.map(
            (feature) => _PlanFeatureRow(feature: feature),
          ),
          const SizedBox(height: 4),
          Text(
            MonetizationPlanDisplayCopy.freePlanFootnote,
            key: const Key('monetization_plan_free_footnote'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.35,
                ),
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
      padding: EdgeInsets.zero,
      backgroundColor: MonetizationPlanScreen._basicAccentBg,
      borderColor: MonetizationPlanScreen._basicAccentBorder,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFE8F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                _PlanTaglineChip(
                  key: const Key('monetization_plan_basic_recommended'),
                  label: MonetizationPlanDisplayCopy.basicRecommendedLabel,
                  variant: _PlanChipVariant.recommended,
                ),
                const Spacer(),
                _PlanTaglineChip(
                  label: MonetizationPlanDisplayCopy.basicPlanTagline,
                  variant: _PlanChipVariant.recommendedMuted,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Basic',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                _PlanPriceDisplay(
                  amount: MonetizationPlanDisplayCopy.basicPriceAmount,
                  showMonthlyPrefix: true,
                  showPlannedSuffix: true,
                  accentColor: MonetizationPlanScreen._basicAccentText,
                  priceKey: const Key('monetization_plan_basic_price'),
                ),
                const SizedBox(height: 12),
                ...features.map(
                  (feature) => _PlanFeatureRow(
                    feature: feature,
                    accent: true,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('monetization_plan_basic_coming_soon'),
                  onPressed: () => _onComingSoonTap(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MonetizationPlanScreen._basicAccentText,
                    side: BorderSide(
                      color: MonetizationPlanScreen._basicAccentBorder,
                    ),
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
          ),
        ],
      ),
    );
  }
}

enum _PlanChipVariant { neutral, current, recommended, recommendedMuted }

class _PlanTaglineChip extends StatelessWidget {
  const _PlanTaglineChip({
    super.key,
    required this.label,
    required this.variant,
  });

  final String label;
  final _PlanChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color text) = switch (variant) {
      _PlanChipVariant.neutral => (
          AppColors.surfaceVariant,
          AppColors.divider,
          AppColors.textSecondary,
        ),
      _PlanChipVariant.current => (
          const Color(0xFFEEF0F3),
          const Color(0xFFD0D4DA),
          AppColors.textSecondary,
        ),
      _PlanChipVariant.recommended => (
          AppColors.accentPrimary,
          AppColors.accentPrimary,
          AppColors.textOnAccent,
        ),
      _PlanChipVariant.recommendedMuted => (
          const Color(0xFFFFE8F2),
          MonetizationPlanScreen._basicAccentBorder,
          MonetizationPlanScreen._basicAccentText,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: text,
            ),
      ),
    );
  }
}

class _PlanFeatureRow extends StatelessWidget {
  const _PlanFeatureRow({
    required this.feature,
    this.accent = false,
  });

  final MonetizationPlanCardFeature feature;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              feature.muted ? Icons.remove_rounded : Icons.check_rounded,
              size: 15,
              color: feature.muted
                  ? AppColors.textTertiary
                  : (accent
                      ? MonetizationPlanScreen._basicAccentText
                      : AppColors.textSecondary),
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
                    height: 1.35,
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
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '主な違い',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 10),
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

    return Column(
      key: const Key('monetization_plan_comparison_table'),
      children: [
        _ComparisonRow(
          isHeader: true,
          label: '',
          freeValue: '無料版',
          basicValue: 'Basic',
          rowIndex: -1,
          headerStyle: headerStyle,
        ),
        ...lines.asMap().entries.map(
              (entry) => _ComparisonRow(
                label: entry.value.label,
                freeValue: entry.value.freeValue,
                basicValue: entry.value.basicValue,
                rowIndex: entry.key,
              ),
            ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.freeValue,
    required this.basicValue,
    required this.rowIndex,
    this.isHeader = false,
    this.headerStyle,
  });

  final String label;
  final String freeValue;
  final String basicValue;
  final int rowIndex;
  final bool isHeader;
  final TextStyle? headerStyle;

  @override
  Widget build(BuildContext context) {
    final rowBg = isHeader
        ? Colors.transparent
        : (rowIndex.isEven
            ? Colors.white
            : MonetizationPlanScreen._stripeEven);

    final labelStyle = isHeader
        ? headerStyle
        : Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            );

    TextStyle freeStyle(bool muted) => isHeader
        ? headerStyle!
        : Theme.of(context).textTheme.bodySmall!.copyWith(
              color: muted ? AppColors.textTertiary : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            );

    TextStyle basicStyle(bool emphasized) => isHeader
        ? headerStyle!.copyWith(
            color: MonetizationPlanScreen._basicAccentText,
          )
        : Theme.of(context).textTheme.bodySmall!.copyWith(
              color: emphasized
                  ? MonetizationPlanScreen._basicAccentText
                  : AppColors.textPrimary,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              height: 1.3,
            );

    final freeMuted = !isHeader && shouldMuteFreeComparisonValue(freeValue);
    final basicEmphasized =
        !isHeader && shouldEmphasizeBasicComparisonValue(basicValue);

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 46,
            child: Text(label, style: labelStyle),
          ),
          Expanded(
            flex: 27,
            child: Text(
              freeValue,
              textAlign: TextAlign.center,
              style: freeStyle(freeMuted),
            ),
          ),
          Expanded(
            flex: 27,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              decoration: isHeader
                  ? null
                  : BoxDecoration(
                      color: MonetizationPlanScreen._basicColumnBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
              child: Text(
                basicValue,
                textAlign: TextAlign.center,
                style: basicStyle(basicEmphasized || isHeader),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProPlanTeaserCard extends StatelessWidget {
  const _ProPlanTeaserCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('monetization_plan_pro_teaser'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
      child: Text(
        'Proプラン（今後追加予定）・${MonetizationPlanDisplayCopy.proPlannedMonthlyPriceLabel}・AIコメント生成などを検討中',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
      ),
    );
  }
}
