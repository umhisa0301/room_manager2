import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/analytics_params.dart';
import '../models/today_recommendation.dart';
import '../services/analytics_service.dart';
import '../services/app_action_service.dart';
import '../services/post_comment_generation_limit.dart';
import '../services/recommendation_generation_limit.dart';
import '../navigation/app_shell_controller.dart';
import '../services/batch_candidate_add_availability.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/room_recommendation_profile_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/today_recommendations_screen_tokens.dart';
import '../ui/feedback/app_feedback.dart';
import '../utils/recommend_cooldown_policy.dart';
import '../utils/today_recommendation_ui_tags.dart';
import '../utils/today_recommendation_work_progress.dart';
import '../utils/app_debug_log.dart';
import '../utils/room_sync_log.dart';
import '../widgets/app_button.dart';
import '../widgets/mypage/mypage_widgets.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_status.dart';
import '../utils/product_price_display.dart';
import '../utils/product_card_rakuten_open.dart';
import '../widgets/monetization/monetization_ad_slot.dart';
import '../widgets/room_post_prepare_sheet.dart';

class TodayRecommendationsScreen extends StatefulWidget {
  const TodayRecommendationsScreen({super.key, this.skipInitialEnsure = false});

  final bool skipInitialEnsure;

  @override
  State<TodayRecommendationsScreen> createState() =>
      _TodayRecommendationsScreenState();
}

class _TodayRecommendationsScreenState extends State<TodayRecommendationsScreen>
    with WidgetsBindingObserver {
  Timer? _regenerateUiRefreshTimer;
  bool _recommendationsOpenedLogged = false;

  /// 初回生成完了・手動再生成完了時のみ一覧入場モーションを有効化する。
  bool _listEntranceMotionArmed = false;
  String? _lastRevealedBundleKey;

  void _maybeLogRecommendationsOpened(TodayRecommendationBundle bundle) {
    if (_recommendationsOpenedLogged || bundle.entries.isEmpty) return;
    _recommendationsOpenedLogged = true;
    final analytics = context.read<AnalyticsService>();
    final generatedToday =
        bundle.localDateKey == TodayRecommendationWorkProgress.localDateKey();
    unawaited(
      analytics.logRecommendationsOpened(
        itemCount: bundle.entries.length,
        generatedToday: generatedToday,
      ),
    );
  }

  void _logRecommendationItemTapped({
    required int position,
    required AnalyticsRecommendationAction action,
  }) {
    unawaited(
      context.read<AnalyticsService>().logRecommendationItemTapped(
        position: position,
        action: action,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.skipInitialEnsure) {
        importantDebugLog('[RECOMMEND_GUARD] skipReason=recentEnsure');
        return;
      }
      recommendAuditLog('[RECOMMEND_TRIGGER] source=screenOpen');
      _ensureToday();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _regenerateUiRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncRegenerateUiRefresh(immediateSetState: true);
    }
  }

  void _syncRegenerateUiRefresh({bool immediateSetState = false}) {
    if (!mounted) return;
    final rec = context.read<TodayRecommendationProvider>();
    rec.logRegenerateButtonState(trigger: 'screenSync');
    final ui = rec.regenerateButtonUiState();
    _regenerateUiRefreshTimer?.cancel();
    _regenerateUiRefreshTimer = null;
    if (!ui.needsPeriodicRefresh) {
      if (immediateSetState) setState(() {});
      return;
    }
    _regenerateUiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final latest = context.read<TodayRecommendationProvider>();
      latest.logRegenerateButtonState(trigger: 'screenTicker');
      setState(() {});
      if (!latest.regenerateButtonUiState().needsPeriodicRefresh) {
        _regenerateUiRefreshTimer?.cancel();
        _regenerateUiRefreshTimer = null;
      }
    });
    if (immediateSetState) setState(() {});
  }

  Future<void> _ensureToday() async {
    if (!mounted) return;
    final recommender = context.read<TodayRecommendationProvider>();
    final profile = context.read<UserProfileProvider>().profile;
    final managed = context.read<RakutenManagedProductProvider>().items;
    final saved = context.read<SavedShopProvider>().shops;
    await recommender.ensureToday(
      profile: profile,
      managedItems: managed,
      savedShops: saved,
      recommendationProfile: context
          .read<RoomRecommendationProfileProvider>()
          .profile,
      trigger: 'screenOpen',
    );
  }

  Future<void> _regenerate() async {
    if (!mounted) return;
    final recommender = context.read<TodayRecommendationProvider>();
    final profile = context.read<UserProfileProvider>().profile;
    final managed = context.read<RakutenManagedProductProvider>().items;
    final saved = context.read<SavedShopProvider>().shops;
    final beforeGeneratedAt = recommender.bundle?.generatedAt;
    final beforeHadEntries =
        recommender.bundle != null && recommender.bundle!.entries.isNotEmpty;
    await recommender.regenerateToday(
      profile: profile,
      managedItems: managed,
      savedShops: saved,
      recommendationProfile: context
          .read<RoomRecommendationProfileProvider>()
          .profile,
      trigger: 'manual',
      manual: true,
    );
    if (!mounted) return;
    final guard = recommender.lastGuardReason ?? '';
    if (guard.contains('monetizationDailyLimit')) {
      final state = await resolveRecommendationGenerationAvailabilityForToday();
      if (!mounted) return;
      _showGenerationLimitMessage(context, state);
      return;
    }
    if (guard.contains('manualCooldown') ||
        guard.contains('rateLimitCooldown') ||
        guard.contains('recentlyGenerated')) {
      final status = recommender.manualRegenerateCooldownStatus();
      final msg = status.userFacingWaitLabel.isEmpty
          ? 'あと約5分後に再生成できます'
          : status.userFacingWaitLabel;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (guard.isNotEmpty) return;

    final afterGeneratedAt = recommender.bundle?.generatedAt;
    final updatedSuccessfully =
        beforeHadEntries &&
        afterGeneratedAt != null &&
        afterGeneratedAt != beforeGeneratedAt &&
        (recommender.bundle?.entries.isNotEmpty ?? false);
    if (updatedSuccessfully) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('today_recommendation_updated_snackbar'),
          content: Text('おすすめを更新しました'),
        ),
      );
    }
  }

  static String _bundleIdentity(TodayRecommendationBundle bundle) {
    final productIds = bundle.entries.map((e) => e.item.productId).join(',');
    return '${bundle.generatedAt.toIso8601String()}|$productIds';
  }

  void _showGenerationLimitMessage(
    BuildContext context,
    RecommendationGenerationLimitState state,
  ) {
    final body = buildRecommendationGenerationLimitBlockedBody(state);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('today_recommendation_generation_limit_snackbar'),
        content: Text(body),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: TodayRecommendationsScreenUi.overlayTheme(theme),
      child: Scaffold(
        backgroundColor: TodayRecommendationsScreenUi.canvas,
        appBar: AppBar(
          title: const Text('今日のおすすめコレ候補'),
          backgroundColor: TodayRecommendationsScreenUi.canvas,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Consumer<TodayRecommendationProvider>(
            builder: (context, rec, _) {
              final hasEntries =
                  rec.bundle != null && rec.bundle!.entries.isNotEmpty;
              final isInitialLoading = rec.isLoading && !hasEntries;
              final isRefreshing = rec.isLoading && hasEntries;

              if (isInitialLoading) {
                _listEntranceMotionArmed = true;
                return const KeyedSubtree(
                  key: Key('today_recommendation_status_area'),
                  child: AppScreenLoadingCenter(
                    title: 'おすすめコレを準備しています',
                    subtitle: 'あなたに合う商品を集めています。',
                  ),
                );
              }
              if (rec.errorMessage != null &&
                  (rec.bundle == null || rec.bundle!.entries.isEmpty)) {
                return KeyedSubtree(
                  key: const Key('today_recommendation_error_message'),
                  child: AppScreenErrorCenter(
                    title: 'おすすめを表示できませんでした',
                    message: rec.errorMessage!,
                    onRetry: _regenerate,
                    retryLabel: '候補を作り直す',
                  ),
                );
              }

              final bundle = rec.bundle;
              if (bundle == null || bundle.entries.isEmpty) {
                final favoriteGenres = context
                    .read<UserProfileProvider>()
                    .profile
                    .favoriteGenreIdList;
                return KeyedSubtree(
                  key: const Key('today_recommendation_empty_message'),
                  child: AppScreenEmptyCenter(
                    icon: Icons.auto_awesome_outlined,
                    title: 'まだ今日のおすすめがありません',
                    body: favoriteGenres.isEmpty
                        ? 'まずはジャンルを設定すると精度が上がります。登録後に生成すると、好きなジャンルや候補履歴に近い商品を優先します。'
                        : '下のボタンで最大10件のコレ候補を提案します。候補・コレ済は除外し、レビューが多い商品を優先します。',
                    actions: [
                      const _GenerationLimitUsageLine(),
                      MyPagePrimaryButton(
                        key: const Key('today_recommendation_generate_button'),
                        label: '今日のおすすめを作る',
                        onPressed: _regenerate,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        height: 48,
                      ),
                    ],
                  ),
                );
              }

              if (isRefreshing) {
                _listEntranceMotionArmed = true;
              }

              final bundleKey = _bundleIdentity(bundle);
              final shouldAnimateEntrance =
                  !isRefreshing &&
                  _listEntranceMotionArmed &&
                  _lastRevealedBundleKey != bundleKey;
              if (!isRefreshing) {
                _lastRevealedBundleKey = bundleKey;
                if (shouldAnimateEntrance) {
                  _listEntranceMotionArmed = false;
                }
              }

              final savedShopCount = context
                  .read<SavedShopProvider>()
                  .shops
                  .length;
              final rows = _RecommendationListRow.fromEntries(
                bundle.entries,
                savedShopCount: savedShopCount,
              );
              final visibleEntries =
                  TodayRecommendationSectionVisibility.visibleEntries(
                    entries: bundle.entries,
                    savedShopCount: savedShopCount,
                  );
              final pendingCount = visibleEntries
                  .where(
                    (e) => e.decision == TodayRecommendationDecision.pending,
                  )
                  .length;
              final alreadyAdded = bundle.entries
                  .where(
                    (e) =>
                        e.decision ==
                        TodayRecommendationDecision.addedCandidate,
                  )
                  .length;
              final skipped = bundle.entries
                  .where(
                    (e) => e.decision == TodayRecommendationDecision.skipped,
                  )
                  .length;
              if (kDebugMode) {
                debugPrint(
                  '[TODAY_RECOMMEND_SELECTION_RENDER] total=${bundle.entries.length} '
                  'pending=$pendingCount alreadyAdded=$alreadyAdded skipped=$skipped',
                );
              }
              final regenerateUi = rec.regenerateButtonUiState();
              final batchAddState = resolveBatchCandidateAddAvailability();
              rec.logRegenerateButtonState(trigger: 'resultRender');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _syncRegenerateUiRefresh();
                _maybeLogRecommendationsOpened(bundle);
              });
              return KeyedSubtree(
                key: const Key('today_recommendation_result_area'),
                child: Column(
                  children: [
                    _SummaryCard(
                      total: visibleEntries.length,
                      uiState: regenerateUi,
                      isRegenerating: isRefreshing,
                      onRegenerate: _regenerate,
                    ),
                    if (isRefreshing) const _RegeneratingInlineStatus(),
                    const MonetizationAdSlot(
                      placement: MonetizationAdPlacement
                          .todayRecommendationSummaryBanner,
                    ),
                    if (pendingCount > 0 &&
                        batchAddState.limitsEnforcementEnabled &&
                        !batchAddState.allowed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                        child: Text(
                          batchCandidateAddLockedMessage(),
                          key: const Key(
                            'today_recommendation_bulk_add_locked_hint',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ),
                    Expanded(
                      child: _RecommendationListView(
                        key: ValueKey(bundleKey),
                        rows: rows,
                        animateEntrance: shouldAnimateEntrance,
                        onItemTapped: _logRecommendationItemTapped,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecommendationListRow {
  const _RecommendationListRow.entry(this.entry) : section = null;
  const _RecommendationListRow.section(this.section) : entry = null;

  final TodayRecommendationEntry? entry;
  final TodayRecommendationSection? section;

  static List<_RecommendationListRow> fromEntries(
    List<TodayRecommendationEntry> entries, {
    required int savedShopCount,
  }) {
    final rows = <_RecommendationListRow>[];
    for (final section in TodayRecommendationSectionVisibility.visibleSections(
      entries: entries,
      savedShopCount: savedShopCount,
    )) {
      final sectionEntries = entries
          .where((e) => e.section == section)
          .toList(growable: false);
      rows.add(_RecommendationListRow.section(section));
      rows.addAll(sectionEntries.map(_RecommendationListRow.entry));
    }
    return rows;
  }
}

class _RecommendationSectionHeader extends StatelessWidget {
  const _RecommendationSectionHeader({
    required this.section,
    required this.topPadding,
  });

  final TodayRecommendationSection section;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, topPadding, 2, 6),
      child: Text(
        _sectionTitle(section),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  String _sectionTitle(TodayRecommendationSection section) {
    switch (section) {
      case TodayRecommendationSection.sellable:
        return '保存ショップから';
      case TodayRecommendationSection.popular:
        return 'あなた向け';
      case TodayRecommendationSection.fresh:
        return '発見候補';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.uiState,
    required this.onRegenerate,
    this.isRegenerating = false,
  });

  final int total;
  final RegenerateButtonUiState uiState;
  final VoidCallback onRegenerate;
  final bool isRegenerating;

  @override
  Widget build(BuildContext context) {
    final cooldownHint =
        uiState.showCooldownMessage && uiState.waitLabel.isNotEmpty
        ? uiState.waitLabel
        : (uiState.canPress || isRegenerating ? '' : 'あと約5分で再生成できます');
    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total件の候補',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (cooldownHint.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    cooldownHint,
                    key: const Key('today_recommendation_skip_message'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppSecondaryButton(
            key: const Key('today_recommendation_regenerate_button'),
            label: '再生成',
            onPressed: uiState.canPress && !isRegenerating
                ? onRegenerate
                : null,
            isLoading: isRegenerating,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RegeneratingInlineStatus extends StatelessWidget {
  const _RegeneratingInlineStatus();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        key: const Key('today_recommendation_regenerating_status'),
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TodayRecommendationsScreenUi.primary.withValues(
                alpha: 0.85,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'おすすめを選び直しています',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationListView extends StatelessWidget {
  const _RecommendationListView({
    super.key,
    required this.rows,
    required this.animateEntrance,
    required this.onItemTapped,
  });

  final List<_RecommendationListRow> rows;
  final bool animateEntrance;
  final void Function({
    required int position,
    required AnalyticsRecommendationAction action,
  })
  onItemTapped;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.section != null) {
          return _RecommendationSectionHeader(
            section: row.section!,
            topPadding: index == 0 ? 2 : 8,
          );
        }
        final position =
            rows.take(index + 1).where((r) => r.entry != null).length - 1;
        final staggerIndex = position.clamp(0, 2);
        final productId = row.entry!.item.productId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RecommendationEntrance(
            animate: animateEntrance,
            staggerIndex: staggerIndex,
            child: _RecommendationCard(
              key: ValueKey(productId),
              entry: row.entry!,
              position: position,
              onItemTapped: onItemTapped,
            ),
          ),
        );
      },
    );
  }
}

/// 初回生成完了 / 再生成完了時のみ Fade + 軽い縦 Slide（最大 8px）。
class _RecommendationEntrance extends StatelessWidget {
  const _RecommendationEntrance({
    required this.animate,
    required this.staggerIndex,
    required this.child,
  });

  final bool animate;
  final int staggerIndex;
  final Widget child;

  static const double _slidePx = 8;

  @override
  Widget build(BuildContext context) {
    if (!animate || AppMotion.reduceMotionOf(context)) {
      return child;
    }
    final base = AppMotion.durationOf(context, AppMotion.normal);
    if (base == Duration.zero) return child;

    final delayMs = staggerIndex * 50;
    final totalMs = base.inMilliseconds + delayMs;
    final begin = delayMs / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(begin, 1, curve: AppMotion.standard),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _slidePx * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    super.key,
    required this.entry,
    required this.position,
    required this.onItemTapped,
  });

  final TodayRecommendationEntry entry;
  final int position;
  final void Function({
    required int position,
    required AnalyticsRecommendationAction action,
  })
  onItemTapped;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      radius: 16,
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImageWithStatus(
            entry: entry,
            position: position,
            onItemTapped: onItemTapped,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    onItemTapped(
                      position: position,
                      action: AnalyticsRecommendationAction.openDetail,
                    );
                    ProductCardRakutenOpen.open(
                      context: context,
                      affiliateUrl: item.affiliateUrl,
                      itemUrl: item.itemUrl,
                      screen: 'todayRecommendations',
                      productId: item.productId,
                      source: 'title',
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.24,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textPrimary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  ProductPriceDisplay.formatYen(item.itemPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '評価 ${item.reviewAverage.toStringAsFixed(2)} / 評価数 ${item.reviewCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 6),
                _RecommendationTagWrap(entry: entry),
                const SizedBox(height: 10),
                _CardActionArea(
                  entry: entry,
                  position: position,
                  onItemTapped: onItemTapped,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CompactActionStyle { primary, secondary, weak }

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    super.key,
    required this.label,
    required this.style,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final _CompactActionStyle style;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final String? semanticLabel;

  static const double _minHeight = 40;

  bool get _isPrimary => style == _CompactActionStyle.primary;
  bool get _isSecondary => style == _CompactActionStyle.secondary;

  @override
  Widget build(BuildContext context) {
    final foreground = _isPrimary
        ? AppColors.textOnAccent
        : _isSecondary
        ? TodayRecommendationsScreenUi.primary
        : AppColors.textSecondary;
    final background = _isPrimary
        ? TodayRecommendationsScreenUi.primary
        : _isSecondary
        ? Colors.white
        : Colors.transparent;
    final border = _isPrimary
        ? TodayRecommendationsScreenUi.primary
        : _isSecondary
        ? TodayRecommendationsScreenUi.primaryBorder
        : AppColors.divider.withValues(alpha: 0.82);
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: _isPrimary
            ? AppColors.textOnAccent.withValues(alpha: 0.55)
            : AppColors.textSecondary,
        backgroundColor: background,
        disabledBackgroundColor: AppColors.surfaceVariant,
        padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 8, vertical: 8),
        minimumSize: Size(expand ? double.infinity : 0, _minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: _isSecondary ? 1.5 : 1),
        ),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 4)],
          Text(label, maxLines: 1, softWrap: false),
        ],
      ),
    );
    final sized = SizedBox(
      width: expand ? double.infinity : null,
      height: _minHeight,
      child: button,
    );
    if (semanticLabel == null) return sized;
    return Semantics(button: true, label: semanticLabel, child: sized);
  }
}

class _RecommendationTagWrap extends StatelessWidget {
  const _RecommendationTagWrap({required this.entry});

  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    final tags = todayRecommendationUiTags(entry);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: tags.map((e) => _ProductTag(label: e)).toList(growable: false),
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = label == '売れ筋価格帯';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: accent
            ? TodayRecommendationsScreenUi.primaryLight
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? TodayRecommendationsScreenUi.primaryBorder.withValues(
                  alpha: 0.55,
                )
              : AppColors.divider.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent
              ? TodayRecommendationsScreenUi.primary
              : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _RecommendationCardCtaState { pending, addedNotCollected, collected }

RakutenManagedProduct? _managedProductForEntry(
  RakutenManagedProductProvider provider,
  TodayRecommendationEntry entry,
) {
  final id = entry.item.productId.trim();
  for (final p in provider.items) {
    if (p.productId == id) return p;
  }
  return null;
}

bool _isManagedProductCollected(RakutenManagedProduct? product) {
  if (product == null) return false;
  return RakutenManagedProduct.isMemberForStatusTab(
    product,
    RakutenManagedProductStatus.done,
  );
}

_RecommendationCardCtaState _recommendationCardCtaState({
  required TodayRecommendationDecision decision,
  required RakutenManagedProduct? managedProduct,
}) {
  if (_isManagedProductCollected(managedProduct)) {
    return _RecommendationCardCtaState.collected;
  }
  switch (decision) {
    case TodayRecommendationDecision.pending:
      return _RecommendationCardCtaState.pending;
    case TodayRecommendationDecision.addedCandidate:
      return _RecommendationCardCtaState.addedNotCollected;
    case TodayRecommendationDecision.skipped:
      return _RecommendationCardCtaState.pending;
  }
}

class _CardActionArea extends StatefulWidget {
  const _CardActionArea({
    required this.entry,
    required this.position,
    required this.onItemTapped,
  });

  final TodayRecommendationEntry entry;
  final int position;
  final void Function({
    required int position,
    required AnalyticsRecommendationAction action,
  })
  onItemTapped;

  @override
  State<_CardActionArea> createState() => _CardActionAreaState();
}

class _CardActionAreaState extends State<_CardActionArea> {
  bool _isAddingCandidate = false;

  TodayRecommendationEntry get entry => widget.entry;

  bool get _canSkip => entry.decision == TodayRecommendationDecision.pending;

  /// 投稿管理タブへ遷移する従来導線（別画面からの再利用用に保持）。
  // ignore: unused_element
  void _openPostManagement(BuildContext context) {
    final shell = context.read<AppShellController>();
    final nav = Navigator.of(context);
    nav.pop();
    shell.openRoomCollect(
      initialTabIndex: 0,
      focusCandidateProductId: entry.item.productId,
    );
  }

  void _openPostPrepareSheet(BuildContext context) {
    widget.onItemTapped(
      position: widget.position,
      action: AnalyticsRecommendationAction.postPrepare,
    );
    showRoomPostPrepareBottomSheet(
      context: context,
      item: entry.item,
      recommendationReason: entry.reason,
      generationBucket: PostCommentGenerationBucket.recommendation,
      analyticsSource: AnalyticsPostPrepareSource.recommendation,
    );
  }

  Future<void> _openRoom(BuildContext context) async {
    final provider = context.read<RakutenManagedProductProvider>();
    final product = _managedProductForEntry(provider, entry);
    if (product == null) return;
    final postUrl = product.extractedUrl.trim();
    final canOpen =
        product.extractionStatus == RakutenUrlExtractionStatus.success &&
        postUrl.isNotEmpty;
    if (!canOpen) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ROOM用URLがまだ取得できていません')));
      return;
    }
    unawaited(
      context.read<AnalyticsService>().logRoomLaunchTapped(
        source: AnalyticsRoomLaunchSource.recommendation,
        launchType: AnalyticsRoomLaunchType.room,
      ),
    );
    await AppActionService.openUrl(context, url: postUrl);
  }

  Future<void> _addCandidate(BuildContext context) async {
    if (_isAddingCandidate ||
        _recommendationCardCtaState(
              decision: entry.decision,
              managedProduct: _managedProductForEntry(
                context.read<RakutenManagedProductProvider>(),
                entry,
              ),
            ) !=
            _RecommendationCardCtaState.pending) {
      return;
    }
    final bulk = context.read<BulkOperationStateController>();
    if (bulk.isRoomTourSearchBlocking) {
      roomSyncUiGuardLog(
        'blockedAction=recommendCandidateAdd '
        'currentJob=${bulk.roomTourBlockingJobLabel} '
        'message=${BulkOperationStateController.roomTourSearchBlockedUserMessage}',
      );
      bulk.guardBlockingOperations(context);
      return;
    }
    setState(() => _isAddingCandidate = true);
    widget.onItemTapped(
      position: widget.position,
      action: AnalyticsRecommendationAction.addCandidate,
    );
    final rec = context.read<TodayRecommendationProvider>();
    final managed = context.read<RakutenManagedProductProvider>();
    final err = await rec.markAddedCandidate(
      managedProvider: managed,
      item: entry.item,
    );
    if (!mounted) return;
    setState(() => _isAddingCandidate = false);
    if (err != null) {
      await showDialog<void>(
        context: this.context,
        builder: (ctx) => AlertDialog(
          title: const Text('候補に追加できませんでした'),
          content: Text(err),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }
    AppFeedback.success(this.context, message: 'コレ候補に追加しました');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<
      BulkOperationStateController,
      RakutenManagedProductProvider
    >(
      builder: (context, bulk, managedProvider, _) {
        final syncLocked = bulk.isRoomTourSearchBlocking;
        final ctaState = _recommendationCardCtaState(
          decision: entry.decision,
          managedProduct: _managedProductForEntry(managedProvider, entry),
        );
        final showAddCandidate =
            entry.decision == TodayRecommendationDecision.pending &&
            (ctaState == _RecommendationCardCtaState.pending ||
                _isAddingCandidate);
        final showPost =
            ctaState == _RecommendationCardCtaState.addedNotCollected;
        final showOpenRoom = ctaState == _RecommendationCardCtaState.collected;
        final showPrimaryCta = showAddCandidate || showPost || showOpenRoom;
        return Column(
          key: const Key('today_recommendation_card_cta'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showAddCandidate)
              _CompactActionButton(
                key: const Key('today_recommendation_add_candidate_button'),
                label: _isAddingCandidate ? '追加中…' : '候補に追加',
                icon: _isAddingCandidate ? null : Icons.add_rounded,
                style: _CompactActionStyle.primary,
                expand: true,
                onPressed: _isAddingCandidate || syncLocked
                    ? syncLocked && !_isAddingCandidate
                          ? () {
                              roomSyncUiGuardLog(
                                'blockedAction=recommendCandidateAdd '
                                'currentJob=${bulk.roomTourBlockingJobLabel} '
                                'message=${BulkOperationStateController.roomTourSearchBlockedUserMessage}',
                              );
                              bulk.guardBlockingOperations(context);
                            }
                          : null
                    : () => _addCandidate(context),
              )
            else if (showPost)
              _CompactActionButton(
                key: const Key('today_recommendation_post_button'),
                label: '投稿する',
                style: _CompactActionStyle.primary,
                expand: true,
                semanticLabel: 'today_recommendation_post_button',
                onPressed: () => _openPostPrepareSheet(context),
              )
            else if (showOpenRoom)
              _CompactActionButton(
                key: const Key('today_recommendation_open_room_button'),
                label: 'ROOMを開く',
                icon: Icons.open_in_new_rounded,
                style: _CompactActionStyle.primary,
                expand: true,
                semanticLabel: 'today_recommendation_open_room_button',
                onPressed: () => _openRoom(context),
              ),
            if (showPrimaryCta) const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _CompactActionButton(
                    key: const Key('today_recommendation_open_rakuten_button'),
                    label: '楽天で見る',
                    style: _CompactActionStyle.secondary,
                    onPressed: () {
                      AppActionService.openUrl(
                        context,
                        url: entry.item.browserLaunchUrl,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactActionButton(
                    key: const Key('today_recommendation_skip_button'),
                    label: '見送る',
                    style: _CompactActionStyle.weak,
                    onPressed: _canSkip
                        ? () async {
                            final rec = context
                                .read<TodayRecommendationProvider>();
                            await rec.markSkipped(entry.item.productId);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ProductImageWithStatus extends StatelessWidget {
  const _ProductImageWithStatus({
    required this.entry,
    required this.position,
    required this.onItemTapped,
  });

  final TodayRecommendationEntry entry;
  final int position;
  final void Function({
    required int position,
    required AnalyticsRecommendationAction action,
  })
  onItemTapped;

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, managedProvider, _) {
        final managedProduct = _managedProductForEntry(managedProvider, entry);
        final collected = _isManagedProductCollected(managedProduct);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _Thumb(
              imageUrl: entry.item.imageUrl,
              entry: entry,
              position: position,
              onItemTapped: onItemTapped,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: _DecisionBadge(
                decision: entry.decision,
                collected: collected,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.decision, required this.collected});

  final TodayRecommendationDecision decision;
  final bool collected;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;
    if (collected) {
      text = 'コレ済み';
      bg = TodayRecommendationsScreenUi.primaryLight;
      fg = TodayRecommendationsScreenUi.primary;
    } else {
      switch (decision) {
        case TodayRecommendationDecision.pending:
          text = '未確認';
          bg = AppColors.surfaceVariant;
          fg = AppColors.textSecondary;
        case TodayRecommendationDecision.skipped:
          text = '見送り';
          bg = const Color(0xFFFFF3E0);
          fg = const Color(0xFFEF6C00);
        case TodayRecommendationDecision.addedCandidate:
          text = '候補追加済';
          bg = const Color(0xFFE8F5E9);
          fg = const Color(0xFF2E7D32);
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.imageUrl,
    required this.entry,
    required this.position,
    required this.onItemTapped,
  });

  final String imageUrl;
  final TodayRecommendationEntry entry;
  final int position;
  final void Function({
    required int position,
    required AnalyticsRecommendationAction action,
  })
  onItemTapped;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: AppColors.surfaceVariant,
        child: InkWell(
          onTap: () {
            onItemTapped(
              position: position,
              action: AnalyticsRecommendationAction.openDetail,
            );
            ProductCardRakutenOpen.open(
              context: context,
              affiliateUrl: entry.item.affiliateUrl,
              itemUrl: entry.item.itemUrl,
              screen: 'todayRecommendations',
              productId: entry.item.productId,
              source: 'image',
            );
          },
          child: SizedBox(
            width: 92,
            height: 108,
            child: imageUrl.trim().isEmpty
                ? const Icon(
                    Icons.image_outlined,
                    color: AppColors.textTertiary,
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textTertiary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GenerationLimitUsageLine extends StatelessWidget {
  const _GenerationLimitUsageLine();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecommendationGenerationLimitState>(
      future: resolveRecommendationGenerationAvailabilityForToday(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || !state.limitsEnforcementEnabled) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            recommendationGenerationUsageLabel(state),
            key: const Key('today_recommendation_generation_usage'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
