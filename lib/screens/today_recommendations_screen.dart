import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/today_recommendation.dart';
import '../services/app_action_service.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/recommend_cooldown_policy.dart';
import '../utils/today_recommendation_ui_tags.dart';
import '../utils/app_debug_log.dart';
import '../utils/room_sync_log.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/search_bulk_selection_header.dart';
import '../utils/product_card_rakuten_open.dart';

class TodayRecommendationsScreen extends StatefulWidget {
  const TodayRecommendationsScreen({super.key, this.skipInitialEnsure = false});

  final bool skipInitialEnsure;

  @override
  State<TodayRecommendationsScreen> createState() =>
      _TodayRecommendationsScreenState();
}

class _TodayRecommendationsScreenState
    extends State<TodayRecommendationsScreen> {
  final Set<String> _selectedProductIds = <String>{};
  bool _isBulkAdding = false;
  int _bulkProcessed = 0;
  int _bulkTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.skipInitialEnsure) {
        importantDebugLog('[RECOMMEND_GUARD] skipReason=recentEnsure');
        return;
      }
      recommendAuditLog('[RECOMMEND_TRIGGER] source=screenOpen');
      _ensureToday();
    });
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
      trigger: 'screenOpen',
    );
  }

  Future<void> _bulkAddCandidates(
    BuildContext context,
    List<TodayRecommendationEntry> selectable,
  ) async {
    if (_isBulkAdding || _selectedProductIds.isEmpty) return;
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
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      trigger: 'manual',
      manual: true,
    );
    if (!mounted) return;
    final guard = recommender.lastGuardReason ?? '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('今日のおすすめコレ候補')),
      body: SafeArea(
        child: Consumer<TodayRecommendationProvider>(
          builder: (context, rec, _) {
            if (rec.isLoading) {
              return const AppScreenLoadingCenter(
                title: '今日のおすすめを準備しています',
                subtitle:
                    '保存ジャンルを中心に、画像・価格が確認できる商品を集めています。',
              );
            }
            if (rec.errorMessage != null &&
                (rec.bundle == null || rec.bundle!.entries.isEmpty)) {
              return AppScreenErrorCenter(
                title: 'おすすめを表示できませんでした',
                message: rec.errorMessage!,
                onRetry: _regenerate,
                retryLabel: 'もう一度生成する',
              );
            }

            final bundle = rec.bundle;
            if (bundle == null || bundle.entries.isEmpty) {
              final favoriteGenres = context
                  .read<UserProfileProvider>()
                  .profile
                  .favoriteGenreIdList;
              return AppScreenEmptyCenter(
                icon: Icons.auto_awesome_outlined,
                title: 'まだ今日のおすすめがありません',
                body: favoriteGenres.isEmpty
                    ? 'まずはジャンルを設定すると精度が上がります。登録後に生成すると、好きなジャンルや候補履歴に近い商品を優先します。'
                    : '下のボタンで最大10件のコレ候補を提案します。候補・コレ済は除外し、レビューが多い商品を優先します。',
                actions: [
                  AppPrimaryButton(
                    label: '今日のおすすめを作る',
                    onPressed: _regenerate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                ],
              );
            }

            final rows = _RecommendationListRow.fromEntries(bundle.entries);
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
            return Column(
              children: [
                _SummaryCard(
                  total: bundle.entries.length,
                  pending: rec.pendingCount,
                  completed: rec.isCompleted,
                  cooldown: rec.manualRegenerateCooldownStatus(),
                  onRegenerate: _regenerate,
                ),
                if (selectable.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: SearchBulkSelectionHeader(
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
                          topPadding: index == 0 ? 2 : 10,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RecommendationCard(
                          entry: row.entry!,
                          bulkSelectEnabled: row.entry!.decision ==
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
                if (_selectedProductIds.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: AppPrimaryButton(
                        label: _isBulkAdding
                            ? '追加中…（$_bulkProcessed/$_bulkTotal）'
                            : 'まとめて候補に追加（${_selectedProductIds.length}件）',
                        icon: const Icon(Icons.playlist_add_check_rounded),
                        isLoading: _isBulkAdding,
                        onPressed: _isBulkAdding
                            ? null
                            : () => _bulkAddCandidates(context, selectable),
                      ),
                    ),
                  ),
              ],
            );
          },
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
    List<TodayRecommendationEntry> entries,
  ) {
    final rows = <_RecommendationListRow>[];
    for (final section in TodayRecommendationSection.values) {
      final sectionEntries = entries
          .where((e) => e.section == section)
          .toList(growable: false);
      if (sectionEntries.isEmpty) continue;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionTitle(section),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _sectionSubtitle(section),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
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
        return '発掘・トレンド';
    }
  }

  String _sectionSubtitle(TodayRecommendationSection section) {
    switch (section) {
      case TodayRecommendationSection.sellable:
        return '保存したショップの中から、投稿しやすい候補です。';
      case TodayRecommendationSection.popular:
        return '好きなジャンル・コレ履歴・保存ショップに近い候補です。';
      case TodayRecommendationSection.fresh:
        return 'いつもの傾向を少し広げた候補です。最大3件に抑えています。';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.pending,
    required this.completed,
    required this.cooldown,
    required this.onRegenerate,
  });

  final int total;
  final int pending;
  final bool completed;
  final RecommendRegenerateCooldownStatus cooldown;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final canRegenerate = cooldown.canRegenerate && !completed;
    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed ? '本日のおすすめはチェック完了です' : '本日のおすすめ $total件（未処理 $pending件）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            completed
                ? '10件見終わりました。次回は翌日に新しい候補が生成されます。'
                : '今日チェックしたい商品です。候補・コレ済は除外しています',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (!cooldown.canRegenerate && cooldown.userFacingWaitLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              cooldown.userFacingWaitLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: AppSecondaryButton(
              label: '今日の候補を再生成',
              onPressed: canRegenerate ? onRegenerate : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
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
      padding: const EdgeInsets.all(10),
      radius: 16,
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bulkSelectEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 2, top: 4),
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelected?.call(),
                activeColor: AppColors.accentPrimary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        color: accent ? const Color(0xFFFFEEF5) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppColors.accentPrimary.withValues(alpha: 0.18)
              : AppColors.divider.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent ? AppColors.accentPrimary : AppColors.textSecondary,
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
        ? AppColors.accentPrimary
        : AppColors.textSecondary;
    final background = _isPrimary
        ? AppColors.accentPrimary
        : _isMedium
        ? const Color(0xFFFFEEF5)
        : Colors.transparent;
    final border = _isPrimary
        ? AppColors.accentPrimary
        : _isMedium
        ? AppColors.accentPrimary.withValues(alpha: 0.22)
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
