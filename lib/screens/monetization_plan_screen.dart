import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../services/billing_product_service.dart';
import '../services/billing_purchase_service.dart';
import '../theme/app_theme.dart';
import '../theme/mypage_screen_tokens.dart';
import '../utils/monetization_plan_display.dart';
import '../widgets/app_card.dart';

/// プラン内容の案内画面（課金処理は行わない）。
class MonetizationPlanScreen extends StatefulWidget {
  const MonetizationPlanScreen({
    super.key,
    this.flags,
    this.purchasedPlanOverride,
    this.billingProductService,
    this.billingPurchaseService,
    this.billingQueryResultOverride,
    this.skipBillingQuery = false,
  });

  /// テスト用。未指定時はコンパイル時フラグ。
  final MonetizationFlagSnapshot? flags;
  final MonetizationPlan? purchasedPlanOverride;

  /// テスト・差し替え用の商品照会サービス。
  final BillingProductService? billingProductService;

  /// テスト・差し替え用の購入サービス。
  final BillingPurchaseService? billingPurchaseService;

  /// テスト用。指定時は照会を行わずこの結果を使う。
  final BillingProductQueryResult? billingQueryResultOverride;

  /// テスト用。true のとき商品照会をスキップする。
  final bool skipBillingQuery;

  @override
  State<MonetizationPlanScreen> createState() => _MonetizationPlanScreenState();
}

class _MonetizationPlanScreenState extends State<MonetizationPlanScreen> {
  static const double _screenPadH = AppDimensions.screenPaddingH;
  static const double _gap = AppDimensions.spacingMd;
  static const double _wideLayoutBreakpoint = 520;

  static const Color _basicAccentBg = MyPageScreenUi.primaryLight;
  static const Color _basicAccentBorder = MyPageScreenUi.primaryBorder;
  static const Color _basicAccentText = MyPageScreenUi.primary;
  static const Color _basicColumnBg = MyPageScreenUi.chipSetFill;
  static const Color _stripeEven = Color(0xFFF8F8FA);

  bool _billingQueryLoading = false;
  BillingProductQueryResult? _billingQueryResult;
  BillingPurchaseService? _purchaseService;
  String? _lastShownPurchaseMessage;

  @override
  void initState() {
    super.initState();
    _initializeBillingQuery();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindPurchaseServiceIfNeeded();
  }

  void _bindPurchaseServiceIfNeeded() {
    final service =
        widget.billingPurchaseService ?? _readPurchaseServiceFromContext();
    if (service == null || identical(service, _purchaseService)) {
      return;
    }
    _purchaseService?.removeListener(_onPurchaseServiceChanged);
    _purchaseService = service;
    _purchaseService!.addListener(_onPurchaseServiceChanged);
  }

  BillingPurchaseService? _readPurchaseServiceFromContext() {
    try {
      return context.read<BillingPurchaseService>();
    } catch (_) {
      return null;
    }
  }

  void _onPurchaseServiceChanged() {
    if (!mounted) return;
    final message = _purchaseService?.lastUserMessage;
    if (message != null && message != _lastShownPurchaseMessage) {
      _lastShownPurchaseMessage = message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _purchaseService?.removeListener(_onPurchaseServiceChanged);
    super.dispose();
  }

  void _initializeBillingQuery() {
    if (widget.billingQueryResultOverride != null) {
      _billingQueryResult = widget.billingQueryResultOverride;
      return;
    }
    if (widget.skipBillingQuery) {
      _billingQueryResult = createPlannedFallbackBillingQueryResult();
      return;
    }

    final snapshot = widget.flags ?? MonetizationFlagSnapshot.fromCompileTime();
    if (!shouldQueryBillingProducts(
      monetizationEnabled: snapshot.isMonetizationEnabled,
      subscriptionEnabled: snapshot.isSubscriptionEnabled,
    )) {
      _billingQueryResult = createPlannedFallbackBillingQueryResult();
      return;
    }

    _billingQueryLoading = true;
    final service = widget.billingProductService ?? BillingProductService();
    service.queryProducts().then((result) {
      if (!mounted) return;
      setState(() {
        _billingQueryLoading = false;
        _billingQueryResult = result;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.flags ?? MonetizationFlagSnapshot.fromCompileTime();
    final purchaseService = widget.billingPurchaseService ?? _purchaseService;
    final purchasedPlan = widget.purchasedPlanOverride ??
        (purchaseService?.entitlement.isActive == true
            ? purchaseService!.entitlement.resolvedPlan
            : null);
    final currentPlan = resolveCurrentMonetizationPlan(
      flags: snapshot,
      purchasedPlanOverride: purchasedPlan,
    );
    final comparisonLines = buildFreeBasicComparisonLines();
    final freeFeatures = buildFreePlanCardFeatures();
    final basicFeatures = buildBasicPlanCardFeatures();
    final showCurrentOnFree = currentPlan == MonetizationPlan.free;
    final showCurrentOnBasic = currentPlan == MonetizationPlan.basic;
    final basicPriceDisplay = resolveBasicPlanPriceDisplay(
      isLoading: _billingQueryLoading,
      queryResult: _billingQueryResult,
    );
    final proPriceLabel = resolveProPlanPriceLabel(
      isLoading: _billingQueryLoading,
      queryResult: _billingQueryResult,
    );
    final billingStatusMessage = resolveBillingStatusMessage(
      isLoading: _billingQueryLoading,
      queryResult: _billingQueryResult,
    );
    final basicProductAvailable = _billingQueryResult?.basic != null;
    final purchaseEnabled =
        snapshot.isSubscriptionEnabled && basicProductAvailable;
    final isPurchasing = purchaseService?.isPurchasing ?? false;
    final isRestoring = purchaseService?.isRestoring ?? false;
    final basicButtonState = resolveBasicPlanButtonState(
      isBasicActive: showCurrentOnBasic,
      purchaseEnabled: purchaseEnabled,
      isPurchasing: isPurchasing,
      isRestoring: isRestoring,
    );
    final showRestoreButton = snapshot.isSubscriptionEnabled;

    return Theme(
      data: MyPageScreenUi.overlayTheme(Theme.of(context)),
      child: Scaffold(
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
            const _PreparingNoticeBanner(),
            if (billingStatusMessage != null) ...[
              const SizedBox(height: 8),
              _BillingStatusLine(message: billingStatusMessage),
            ],
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
                        child: _BasicPlanCard(
                          features: basicFeatures,
                          priceDisplay: basicPriceDisplay,
                          buttonState: basicButtonState,
                          showCurrentChip: showCurrentOnBasic,
                          onPurchaseTap: purchaseEnabled && !showCurrentOnBasic
                              ? () => _onBasicPurchaseTap(purchaseService)
                              : null,
                          onComingSoonTap: !purchaseEnabled && !showCurrentOnBasic
                              ? () => _onComingSoonTap(context)
                              : null,
                        ),
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
                    _BasicPlanCard(
                      features: basicFeatures,
                      priceDisplay: basicPriceDisplay,
                      buttonState: basicButtonState,
                      showCurrentChip: showCurrentOnBasic,
                      onPurchaseTap: purchaseEnabled && !showCurrentOnBasic
                          ? () => _onBasicPurchaseTap(purchaseService)
                          : null,
                      onComingSoonTap: !purchaseEnabled && !showCurrentOnBasic
                          ? () => _onComingSoonTap(context)
                          : null,
                    ),
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
            if (showRestoreButton) ...[
              const SizedBox(height: 12),
              _RestorePurchasesButton(
                isRestoring: isRestoring,
                isPurchasing: isPurchasing,
                onTap: purchaseService == null
                    ? null
                    : () => purchaseService.restorePurchases(),
              ),
            ],
            const SizedBox(height: _gap),
            _ProPlanTeaserCard(priceLabel: proPriceLabel),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _onBasicPurchaseTap(BillingPurchaseService? purchaseService) async {
    if (purchaseService == null) {
      _onComingSoonTap(context);
      return;
    }
    final basic = _billingQueryResult?.basic;
    if (basic == null) {
      _onComingSoonTap(context);
      return;
    }
    await purchaseService.purchaseBasic(basicProduct: basic);
  }

  void _onComingSoonTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(MonetizationPlanDisplayCopy.preparingSnackBarMessage),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _PreparingNoticeBanner extends StatelessWidget {
  const _PreparingNoticeBanner();

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

class _BillingStatusLine extends StatelessWidget {
  const _BillingStatusLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: const Key('monetization_plan_billing_status'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            height: 1.35,
          ),
    );
  }
}

class _PlanPriceDisplay extends StatelessWidget {
  const _PlanPriceDisplay({
    required this.priceDisplay,
    this.accentColor,
    this.priceKey,
  });

  final MonetizationPlanPriceDisplay priceDisplay;
  final Color? accentColor;
  final Key? priceKey;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.textPrimary;

    if (priceDisplay.useStorePriceFormat) {
      return Text(
        priceDisplay.label,
        key: priceKey,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
              letterSpacing: -0.5,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (priceDisplay.showMonthlyPrefix)
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
              priceDisplay.label,
              key: priceKey,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: priceDisplay.source == MonetizationPlanPriceSource.loading
                        ? 22
                        : 36,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
            ),
            if (priceDisplay.source != MonetizationPlanPriceSource.loading) ...[
              Text(
                '円',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
              if (priceDisplay.showPlannedSuffix) ...[
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
            priceDisplay: MonetizationPlanPriceDisplay(
              label: MonetizationPlanDisplayCopy.freePriceAmount,
              source: MonetizationPlanPriceSource.planned,
            ),
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
  const _BasicPlanCard({
    required this.features,
    required this.priceDisplay,
    required this.buttonState,
    required this.showCurrentChip,
    this.onPurchaseTap,
    this.onComingSoonTap,
  });

  final List<MonetizationPlanCardFeature> features;
  final MonetizationPlanPriceDisplay priceDisplay;
  final BasicPlanButtonState buttonState;
  final bool showCurrentChip;
  final VoidCallback? onPurchaseTap;
  final VoidCallback? onComingSoonTap;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = buttonState.label;
    final buttonEnabled = buttonState.isEnabled;
    final VoidCallback? onPressed = buttonState.canPurchase
        ? onPurchaseTap
        : (buttonState.showComingSoon ? onComingSoonTap : null);

    return AppCard(
      key: const Key('monetization_plan_basic_card'),
      padding: EdgeInsets.zero,
      backgroundColor: _MonetizationPlanScreenState._basicAccentBg,
      borderColor: _MonetizationPlanScreenState._basicAccentBorder,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: MyPageScreenUi.chipSetFill,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                if (showCurrentChip)
                  _PlanTaglineChip(
                    key: const Key('monetization_plan_basic_current_label'),
                    label: MonetizationPlanDisplayCopy.currentPlanChipLabel,
                    variant: _PlanChipVariant.current,
                  ),
                if (showCurrentChip) const SizedBox(width: 6),
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
                  priceDisplay: priceDisplay,
                  accentColor: _MonetizationPlanScreenState._basicAccentText,
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
                  onPressed: buttonEnabled ? onPressed : null,
                  style: buttonEnabled
                      ? MyPageScreenUi.outlineButtonStyle(height: 44)
                      : MyPageScreenUi.disabledOutlineButtonStyle(height: 44),
                  child: Text(
                    buttonLabel,
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

class _RestorePurchasesButton extends StatelessWidget {
  const _RestorePurchasesButton({
    required this.isRestoring,
    required this.isPurchasing,
    required this.onTap,
  });

  final bool isRestoring;
  final bool isPurchasing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isRestoring && !isPurchasing;
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        key: const Key('monetization_plan_restore_button'),
        onPressed: enabled ? onTap : null,
        child: Text(
          isRestoring
              ? MonetizationPlanDisplayCopy.purchaseProcessingLabel
              : MonetizationPlanDisplayCopy.restorePurchasesLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: enabled
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
        ),
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
          MyPageScreenUi.primaryLight,
          MyPageScreenUi.primaryBorder,
          MyPageScreenUi.primary,
        ),
      _PlanChipVariant.recommendedMuted => (
          MyPageScreenUi.chipSetFill,
          _MonetizationPlanScreenState._basicAccentBorder,
          _MonetizationPlanScreenState._basicAccentText,
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
                      ? _MonetizationPlanScreenState._basicAccentText
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
            : _MonetizationPlanScreenState._stripeEven);

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
            color: _MonetizationPlanScreenState._basicAccentText,
          )
        : Theme.of(context).textTheme.bodySmall!.copyWith(
              color: emphasized
                  ? _MonetizationPlanScreenState._basicAccentText
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
                      color: _MonetizationPlanScreenState._basicColumnBg,
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
  const _ProPlanTeaserCard({required this.priceLabel});

  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('monetization_plan_pro_teaser'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
      child: Text(
        'Proプラン（今後追加予定）・$priceLabel・AIコメント生成などを検討中',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
      ),
    );
  }
}
