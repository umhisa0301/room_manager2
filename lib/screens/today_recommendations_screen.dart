import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/today_recommendation.dart';
import '../services/app_action_service.dart';
import '../services/recommendation_generation_limit.dart';
import '../services/batch_candidate_add_availability.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/room_recommendation_profile_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/today_recommendations_screen_tokens.dart';
import '../utils/recommend_cooldown_policy.dart';
import '../utils/today_recommendation_ui_tags.dart';
import '../utils/app_debug_log.dart';
import '../utils/room_sync_log.dart';
import '../widgets/app_button.dart';
import '../widgets/mypage/mypage_widgets.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/search_bulk_selection_header.dart';
import '../utils/product_card_rakuten_open.dart';
import '../widgets/monetization/monetization_ad_slot.dart';

class TodayRecommendationsScreen extends StatefulWidget {
  const TodayRecommendationsScreen({super.key, this.skipInitialEnsure = false});

  final bool skipInitialEnsure;

  @override
  State<TodayRecommendationsScreen> createState() =>
      _TodayRecommendationsScreenState();
}

class _TodayRecommendationsScreenState
    extends State<TodayRecommendationsScreen> with WidgetsBindingObserver {
  final Set<String> _selectedProductIds = <String>{};
  bool _isBulkAdding = false;
  int _bulkProcessed = 0;
  int _bulkTotal = 0;
  Timer? _regenerateUiRefreshTimer;

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
      recommendationProfile:
          context.read<RoomRecommendationProfileProvider>().profile,
      trigger: 'screenOpen',
    );
  }

  Future<void> _bulkAddCandidates(
    BuildContext context,
    List<TodayRecommendationEntry> selectable,
  ) async {
    if (_isBulkAdding || _selectedProductIds.isEmpty) return;
    final batchAddState = resolveBatchCandidateAddAvailability();
    if (!batchAddState.allowed) {
      _showBatchAddLockedMessage(context, batchAddState);
      return;
    }
    final bulkCtl = context.read<BulkOperationStateController>();
    if (bulkCtl.isRoomTourSearchBlocking) {
      bulkCtl.guardBlockingOperations(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補にまとめて追加'),
        content: const Text(
          '選択した商品を候補に追加します。登録中は他の商品登録を一時停止します。よろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TodayRecommendationsScreenUi.dismissTextButtonStyle(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TodayRecommendationsScreenUi.primaryButtonStyle(height: 40),
            child: const Text('開始する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final targets = selectable
        .where((e) => _selectedProductIds.contains(e.item.productId))
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[TODAY_RECOMMEND_BULK_ADD_START] selected=${targets.length}',
      );
    }
    bulkCtl.setBulkCandidateRegistering(true);
    setState(() {
      _isBulkAdding = true;
      _bulkProcessed = 0;
      _bulkTotal = targets.length;
    });
    var success = 0;
    var alreadyAdded = 0;
    var failed = 0;
    final rec = context.read<TodayRecommendationProvider>();
    final managed = context.read<RakutenManagedProductProvider>();
    try {
      for (var i = 0; i < targets.length; i++) {
        if (!mounted) break;
        setState(() => _bulkProcessed = i);
        final entry = targets[i];
        final err = await rec.markAddedCandidate(
          managedProvider: managed,
          item: entry.item,
        );
        if (err == null) {
          success++;
        } else if (err.contains('登録済') || err.contains('候補')) {
          alreadyAdded++;
        } else {
          failed++;
        }
      }
    } finally {
      bulkCtl.setBulkCandidateRegistering(false);
      if (mounted) {
        setState(() {
          _isBulkAdding = false;
          _bulkProcessed = _bulkTotal;
          _selectedProductIds.clear();
        });
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[TODAY_RECOMMEND_BULK_ADD_RESULT] success=$success '
        'alreadyAdded=$alreadyAdded failed=$failed',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '候補に追加しました（$success件）'
          '${alreadyAdded > 0 ? '・登録済み $alreadyAdded件' : ''}'
          '${failed > 0 ? '・失敗 $failed件' : ''}',
        ),
      ),
    );
  }

  Future<void> _regenerate() async {
    if (!mounted) return;
    final recommender = context.read<TodayRecommendationProvider>();
    final profile = context.read<UserProfileProvider>().profile;
    final managed = context.read<RakutenManagedProductProvider>().items;
    final saved = context.read<SavedShopProvider>().shops;
    await recommender.regenerateToday(
      profile: profile,
      managedItems: managed,
      savedShops: saved,
      recommendationProfile:
          context.read<RoomRecommendationProfileProvider>().profile,
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
    }
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

  void _showBatchAddLockedMessage(
    BuildContext context,
    BatchCandidateAddAvailabilityState state,
  ) {
    final body = buildBatchCandidateAddLockedBody(state);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('today_recommendation_bulk_add_locked_snackbar'),
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
            if (rec.isLoading) {
              return const KeyedSubtree(
                key: Key('today_recommendation_status_area'),
                child: AppScreenLoadingCenter(
                  title: '今日のおすすめを準備しています',
                  subtitle:
                      '保存ジャンルを中心に、画像・価格が確認できる商品を集めています。',
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
                  retryLabel: 'もう一度生成する',
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

            final rows = _RecommendationListRow.fromEntries(
              bundle.entries,
              savedShopCount: context.read<SavedShopProvider>().shops.length,
            );
            final selectable = bundle.entries
                .where(
                  (e) => e.decision == TodayRecommendationDecision.pending,
                )
                .toList(growable: false);
            final alreadyAdded = bundle.entries
                .where(
                  (e) =>
                      e.decision == TodayRecommendationDecision.addedCandidate,
                )
                .length;
            final skipped = bundle.entries
                .where((e) => e.decision == TodayRecommendationDecision.skipped)
                .length;
            if (kDebugMode) {
              debugPrint(
                '[TODAY_RECOMMEND_SELECTION_RENDER] total=${bundle.entries.length} '
                'selectable=${selectable.length} selected=${_selectedProductIds.length} '
                'alreadyAdded=$alreadyAdded skipped=$skipped',
              );
            }
            if (kDebugMode) {
              debugPrint(
                '[TODAY_RECOMMEND_BULK_SELECT_AUDIT] selectAllVisible=${selectable.isNotEmpty} '
                'checkboxShape=square selectedCount=${_selectedProductIds.length} '
                'bulkButtonVisible=${_selectedProductIds.isNotEmpty}',
              );
            }
            final regenerateUi = rec.regenerateButtonUiState();
            final batchAddState = resolveBatchCandidateAddAvailability();
            final bulkSelectAllowed =
                batchAddState.allowed && selectable.isNotEmpty;
            rec.logRegenerateButtonState(trigger: 'resultRender');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncRegenerateUiRefresh();
            });
            return KeyedSubtree(
              key: const Key('today_recommendation_result_area'),
              child: Column(
              children: [
                _SummaryCard(
                  total: bundle.entries.length,
                  uiState: regenerateUi,
                  onRegenerate: _regenerate,
                ),
                const MonetizationAdSlot(
                  placement: MonetizationAdPlacement
                      .todayRecommendationSummaryBanner,
                ),
                if (bulkSelectAllowed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
                    child: SearchBulkSelectionHeader(
                      key: const Key('today_recommendation_bulk_selection_header'),
                      screen: 'todayRecommendations',
                      selectedCount: _selectedProductIds.length,
                      totalSelectable: selectable.length,
                      enabled: !_isBulkAdding,
                      onToggleAll: (selectAll) {
                        setState(() {
                          if (selectAll) {
                            _selectedProductIds
                              ..clear()
                              ..addAll(
                                selectable.map((e) => e.item.productId),
                              );
                          } else {
                            _selectedProductIds.clear();
                          }
                        });
                        if (kDebugMode) {
                          debugPrint(
                            '[TODAY_RECOMMEND_SELECT_ALL] checked=$selectAll '
                            'selected=${_selectedProductIds.length}',
                          );
                        }
                      },
                    ),
                  )
                else if (selectable.isNotEmpty &&
                    batchAddState.limitsEnforcementEnabled &&
                    !batchAddState.allowed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      batchCandidateAddLockedMessage(),
                      key: const Key('today_recommendation_bulk_add_locked_hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      _selectedProductIds.isNotEmpty ? 88 : 24,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row.section != null) {
                        return _RecommendationSectionHeader(
                          section: row.section!,
                          topPadding: index == 0 ? 0 : 6,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _RecommendationCard(
                          entry: row.entry!,
                          bulkSelectEnabled: bulkSelectAllowed &&
                              row.entry!.decision ==
                                  TodayRecommendationDecision.pending,
                          isSelected: _selectedProductIds
                              .contains(row.entry!.item.productId),
                          onToggleSelected: () {
                            final id = row.entry!.item.productId;
                            setState(() {
                              if (_selectedProductIds.contains(id)) {
                                _selectedProductIds.remove(id);
                              } else {
                                _selectedProductIds.add(id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedProductIds.isNotEmpty && batchAddState.allowed)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: MyPagePrimaryButton(
                        key: const Key('today_recommendation_bulk_add_button'),
                        label: _isBulkAdding
                            ? '追加中…（$_bulkProcessed/$_bulkTotal）'
                            : 'まとめて候補に追加（${_selectedProductIds.length}件）',
                        icon: const Icon(Icons.playlist_add_check_rounded),
                        isLoading: _isBulkAdding,
                        height: 48,
                        onPressed: _isBulkAdding
                            ? null
                            : () => _bulkAddCandidates(context, selectable),
                      ),
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
      padding: EdgeInsets.fromLTRB(2, topPadding, 2, 4),
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
  });

  final int total;
  final RegenerateButtonUiState uiState;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final cooldownHint = uiState.showCooldownMessage && uiState.waitLabel.isNotEmpty
        ? uiState.waitLabel
        : (uiState.canPress ? '' : 'あと約5分で再生成できます');
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
            label: '再生成',
            onPressed: uiState.canPress ? onRegenerate : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.entry,
    this.bulkSelectEnabled = false,
    this.isSelected = false,
    this.onToggleSelected,
  });

  final TodayRecommendationEntry entry;
  final bool bulkSelectEnabled;
  final bool isSelected;
  final VoidCallback? onToggleSelected;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return AppCard(
      padding: const EdgeInsets.all(8),
      radius: 16,
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bulkSelectEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 0, top: 0),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelected?.call(),
                  activeColor: TodayRecommendationsScreenUi.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          _ProductImageWithStatus(entry: entry),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => ProductCardRakutenOpen.open(
                    context: context,
                    affiliateUrl: item.affiliateUrl,
                    itemUrl: item.itemUrl,
                    screen: 'todayRecommendations',
                    productId: item.productId,
                    source: 'title',
                  ),
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
                const SizedBox(height: 4),
                Text(
                  _formatPrice(item.itemPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '評価 ${item.reviewAverage.toStringAsFixed(2)} / 評価数 ${item.reviewCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 5),
                _RecommendationTagWrap(entry: entry),
                const SizedBox(height: 8),
                _ActionRow(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPrice(int price) {
  final raw = price.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '¥$buffer';
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
              ? TodayRecommendationsScreenUi.primaryBorder.withValues(alpha: 0.55)
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.entry});

  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    final enabled = entry.decision == TodayRecommendationDecision.pending;
    return Consumer<BulkOperationStateController>(
      builder: (context, bulk, _) {
        final syncLocked = bulk.isRoomTourSearchBlocking;
        return Row(
          children: [
            Expanded(
              flex: 6,
              child: _CompactActionButton(
                label: '楽天で見る',
                style: _CompactActionStyle.primary,
                onPressed: () {
                  AppActionService.openUrl(
                    context,
                    url: entry.item.browserLaunchUrl,
                  );
                },
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 4,
              child: _CompactActionButton(
                label: '候補',
                icon: Icons.bookmark_add_rounded,
                style: _CompactActionStyle.medium,
                onPressed: !enabled
                    ? null
                    : syncLocked
                    ? () {
                        roomSyncUiGuardLog(
                          'blockedAction=recommendCandidateAdd '
                          'currentJob=${bulk.roomTourBlockingJobLabel} '
                          'message=${BulkOperationStateController.roomTourSearchBlockedUserMessage}',
                        );
                        bulk.guardBlockingOperations(context);
                      }
                    : () async {
                        final rec = context.read<TodayRecommendationProvider>();
                        final managed = context
                            .read<RakutenManagedProductProvider>();
                        final err = await rec.markAddedCandidate(
                          managedProvider: managed,
                          item: entry.item,
                        );
                        if (!context.mounted) return;
                        if (err != null) {
                          await showDialog<void>(
                            context: context,
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
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('候補に追加しました')));
                      },
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 4,
              child: _CompactActionButton(
                label: '見送る',
                style: _CompactActionStyle.weak,
                onPressed: enabled
                    ? () async {
                        final rec = context.read<TodayRecommendationProvider>();
                        await rec.markSkipped(entry.item.productId);
                      }
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _CompactActionStyle { primary, medium, weak }

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.style,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final _CompactActionStyle style;
  final VoidCallback? onPressed;
  final IconData? icon;

  bool get _isPrimary => style == _CompactActionStyle.primary;
  bool get _isMedium => style == _CompactActionStyle.medium;

  @override
  Widget build(BuildContext context) {
    final foreground = _isPrimary
        ? AppColors.textOnAccent
        : _isMedium
        ? TodayRecommendationsScreenUi.primary
        : AppColors.textSecondary;
    final background = _isPrimary
        ? TodayRecommendationsScreenUi.primary
        : _isMedium
        ? Colors.white
        : Colors.transparent;
    final border = _isPrimary
        ? TodayRecommendationsScreenUi.primary
        : _isMedium
        ? TodayRecommendationsScreenUi.primaryBorder
        : AppColors.divider.withValues(alpha: 0.82);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: _isPrimary
              ? AppColors.textOnAccent.withValues(alpha: 0.55)
              : AppColors.textSecondary,
          backgroundColor: background,
          disabledBackgroundColor: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: border),
          ),
          textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImageWithStatus extends StatelessWidget {
  const _ProductImageWithStatus({required this.entry});

  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Thumb(imageUrl: entry.item.imageUrl, entry: entry),
        Positioned(
          top: 4,
          right: 4,
          child: _DecisionBadge(decision: entry.decision),
        ),
      ],
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.decision});
  final TodayRecommendationDecision decision;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;
    switch (decision) {
      case TodayRecommendationDecision.pending:
        text = '未処理';
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
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl, required this.entry});

  final String imageUrl;
  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: AppColors.surfaceVariant,
        child: InkWell(
          onTap: () => ProductCardRakutenOpen.open(
            context: context,
            affiliateUrl: entry.item.affiliateUrl,
            itemUrl: entry.item.itemUrl,
            screen: 'todayRecommendations',
            productId: entry.item.productId,
            source: 'image',
          ),
          child: SizedBox(
            width: 92,
            height: 108,
            child: imageUrl.trim().isEmpty
                ? const Icon(Icons.image_outlined, color: AppColors.textTertiary)
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
