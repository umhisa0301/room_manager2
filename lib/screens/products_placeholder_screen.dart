import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../navigation/app_shell_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/rakuten_managed_product_card.dart';
import 'rakuten_search_screen.dart';

List<RakutenManagedProduct> _filterManagedProductsByQuery(
  List<RakutenManagedProduct> items,
  String query,
) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) return items;
  return items.where((e) {
    return e.itemName.toLowerCase().contains(t) ||
        e.shopName.toLowerCase().contains(t) ||
        e.productId.toLowerCase().contains(t) ||
        e.itemUrl.toLowerCase().contains(t) ||
        e.shopCode.toLowerCase().contains(t) ||
        e.genreId.toLowerCase().contains(t);
  }).toList();
}

/// [anchor] のローカル暦日と同一日の [doneAt] をもつコレ済のみ。
List<RakutenManagedProduct> _filterDoneOnLocalCalendarDay(
  List<RakutenManagedProduct> items,
  DateTime anchor,
) {
  final target = DateTime(anchor.year, anchor.month, anchor.day);
  return items.where((e) {
    final d = e.doneAt;
    if (d == null) return false;
    final localDay = DateTime(d.year, d.month, d.day);
    return localDay == target;
  }).toList();
}

/// ROOMコレ管理画面。楽天検索で登録したコレ候補・コレ済をタブで表示する。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialDoneFilterLocalDay,
    this.initialFocusCandidateProductId,
  });

  /// 0: コレ候補、1: コレ済
  final int initialTabIndex;

  /// 指定したローカル暦日に [doneAt] があるコレ済のみ表示（コレ済タブ向け）。
  final DateTime? initialDoneFilterLocalDay;

  /// コレ候補タブで、この商品IDの行へスクロールし、約1秒ハイライトする。
  final String? initialFocusCandidateProductId;

  @override
  State<ProductsPlaceholderScreen> createState() =>
      _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _candidateScrollController = ScrollController();
  final Map<String, GlobalKey> _candidateRowKeys = <String, GlobalKey>{};
  String _searchQuery = '';
  bool _continuousCollectMode = false;
  bool _awaitingContinuousResume = false;
  String _lastCollectedName = '';
  DateTime? _doneLocalDayFilter;
  Timer? _flashTimer;
  String? _flashProductId;
  bool _candidateFocusHandled = false;
  String? _shellFocusCandidateProductId;
  late final AppShellController _shellCtrl;

  String? get _focusCandidateTargetId {
    final w = widget.initialFocusCandidateProductId;
    if (w != null && w.isNotEmpty) return w;
    final s = _shellFocusCandidateProductId;
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  GlobalKey _keyForCandidateRow(String productId) =>
      _candidateRowKeys.putIfAbsent(productId, GlobalKey.new);

  void _onCandidateFocusListReady() {
    if (_candidateFocusHandled) return;
    final id = _focusCandidateTargetId;
    if (id == null || id.isEmpty) return;
    _candidateFocusHandled = true;
    setState(() => _shellFocusCandidateProductId = null);
    _runScrollToCandidate(id, 0);
  }

  void _onCandidateFocusProductMissing() {
    if (_candidateFocusHandled) return;
    _candidateFocusHandled = true;
    setState(() => _shellFocusCandidateProductId = null);
  }

  void _runScrollToCandidate(String productId, int attempt) {
    if (!mounted || attempt > 16) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _candidateRowKeys[productId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.12,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
        setState(() => _flashProductId = productId);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _flashProductId = null);
        });
        return;
      }
      _runScrollToCandidate(productId, attempt + 1);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final d = widget.initialDoneFilterLocalDay;
    if (d != null) {
      _doneLocalDayFilter = DateTime(d.year, d.month, d.day);
    }
    final focusId = widget.initialFocusCandidateProductId;
    final idx0 = widget.initialTabIndex.clamp(0, 1);
    if (focusId != null &&
        focusId.isNotEmpty &&
        idx0 == 0) {
      _searchController.clear();
      _searchQuery = '';
    }
    final initialIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) setState(() {});
    });
    _shellCtrl = context.read<AppShellController>();
    _shellCtrl.addListener(_onShellCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
        showLoadingIndicator: false,
      );
      _tryConsumeRoomCollectIntent();
    });
  }

  void _onShellCtrlChanged() {
    _tryConsumeRoomCollectIntent();
  }

  void _tryConsumeRoomCollectIntent() {
    if (!mounted) return;
    final intent = _shellCtrl.takePendingRoomCollectIntent();
    if (intent != null) {
      _applyRoomCollectIntent(intent);
    }
  }

  void _applyRoomCollectIntent(RoomCollectNavigationIntent intent) {
    final idx = intent.initialTabIndex.clamp(0, 1);
    final focusRaw = intent.focusCandidateProductId;
    final focusId = (focusRaw != null && focusRaw.isNotEmpty && idx == 0)
        ? focusRaw
        : null;

    setState(() {
      if (idx == 0) {
        _doneLocalDayFilter = null;
        if (focusId != null) {
          _searchController.clear();
          _searchQuery = '';
        }
      } else {
        final d = intent.doneFilterLocalDay;
        _doneLocalDayFilter =
            d == null ? null : DateTime(d.year, d.month, d.day);
      }
      _shellFocusCandidateProductId = focusId;
      _candidateFocusHandled = false;
    });

    if (_tabController.index != idx) {
      _tabController.animateTo(idx);
    }
  }

  @override
  void dispose() {
    _shellCtrl.removeListener(_onShellCtrlChanged);
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _candidateScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_continuousCollectMode || !_awaitingContinuousResume) return;
    _awaitingContinuousResume = false;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<RakutenManagedProductProvider>();
      final next = _nextCandidate(provider);
      final moved = _truncateName(_lastCollectedName);
      final message = next == null
          ? '「$moved」をコレ済へ移動しました。次の候補はありません。'
          : '「$moved」をコレ済へ移動しました。次の候補はこちら: 「${_truncateName(next.itemName)}」';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {});
    });
  }

  RakutenManagedProduct? _nextCandidate(
    RakutenManagedProductProvider provider,
  ) {
    final base = provider.sortedItemsForStatus(
      RakutenManagedProductStatus.candidate,
    );
    final filtered = _filterManagedProductsByQuery(base, _searchQuery);
    if (filtered.isEmpty) return null;
    return filtered.first;
  }

  String _truncateName(String text, {int max = 24}) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}...';
  }

  Future<void> _handleContinuousCollect(
    BuildContext context,
    RakutenManagedProduct product,
  ) async {
    final provider = context.read<RakutenManagedProductProvider>();
    await provider.collectRoomAndLaunch(context, product.productId);
    if (!mounted) return;
    final moved =
        provider.statusForProduct(product.productId) ==
        RakutenManagedProductStatus.done;
    if (moved && _continuousCollectMode) {
      setState(() {
        _lastCollectedName = product.itemName;
        _awaitingContinuousResume = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppDimensions.spacingSm,
                AppDimensions.screenPaddingH,
                0,
              ),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      tooltip: '戻る',
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: '楽天の商品を検索し、コレ候補として登録できます',
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RakutenSearchScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.travel_explore_rounded,
                            size: 20,
                            color: AppColors.accentPrimary,
                          ),
                          label: Text(
                            '楽天で検索',
                            style: TextStyle(
                              color: AppColors.accentPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: AppColors.surface,
              child: Consumer<RakutenManagedProductProvider>(
                builder: (context, managed, _) {
                  final nCand = managed
                      .sortedItemsForStatus(
                        RakutenManagedProductStatus.candidate,
                      )
                      .length;
                  final nDone = managed
                      .sortedItemsForStatus(RakutenManagedProductStatus.done)
                      .length;
                  final idx = _tabController.index;
                  return TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.accentPrimary,
                    indicatorWeight: 3,
                    dividerColor: AppColors.divider,
                    tabs: [
                      _RoomTabChip(
                        selected: idx == 0,
                        accent: RoomListAccent.candidate,
                        icon: Icons.bookmark_outline_rounded,
                        label: 'コレ候補（$nCand件）',
                      ),
                      _RoomTabChip(
                        selected: idx == 1,
                        accent: RoomListAccent.done,
                        icon: Icons.task_alt_rounded,
                        label: 'コレ済（$nDone件）',
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                6,
                AppDimensions.screenPaddingH,
                4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.accentPrimary.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '追加：上の「楽天で検索」／下欄は一覧の絞り込み',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                0,
                AppDimensions.screenPaddingH,
                6,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '商品名・ショップ・商品IDで絞り込み',
                  isDense: true,
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RoomManagedProductListTab(
                    status: RakutenManagedProductStatus.candidate,
                    variant: RakutenManagedProductCardVariant.candidate,
                    filterQuery: _searchQuery,
                    continuousCollectMode: _continuousCollectMode,
                    onContinuousModeChanged: (next) {
                      setState(() {
                        _continuousCollectMode = next;
                        _awaitingContinuousResume = false;
                      });
                    },
                    onCollectPressed: _handleContinuousCollect,
                    emptyTitle: 'コレ候補はまだありません',
                    emptySubtitle:
                        '① 画面上部の「楽天で検索」で商品を探す\n'
                        '② 検索結果から「コレ候補へ登録」\n'
                        '③ URL取得後に「コレする」でコレ済へ移動',
                    emptyHint: 'まずは上の「楽天で検索」から商品を探してみてください。',
                    accentColor: RoomListAccent.candidate,
                    listScrollController: _candidateScrollController,
                    flashHighlightProductId: _flashProductId,
                    rowKeyFor: _keyForCandidateRow,
                    focusCandidateProductId: _focusCandidateTargetId,
                    onCandidateFocusListReady:
                        _focusCandidateTargetId != null &&
                                _focusCandidateTargetId!.isNotEmpty
                            ? _onCandidateFocusListReady
                            : null,
                    onCandidateFocusProductMissing:
                        _focusCandidateTargetId != null &&
                                _focusCandidateTargetId!.isNotEmpty
                            ? _onCandidateFocusProductMissing
                            : null,
                  ),
                  _RoomManagedProductListTab(
                    status: RakutenManagedProductStatus.done,
                    variant: RakutenManagedProductCardVariant.done,
                    filterQuery: _searchQuery,
                    continuousCollectMode: false,
                    doneAtLocalDayFilter: _doneLocalDayFilter,
                    onClearDoneDayFilter: _doneLocalDayFilter == null
                        ? null
                        : () => setState(() => _doneLocalDayFilter = null),
                    emptyTitle: 'コレ済の商品はまだありません',
                    emptySubtitle:
                        'コレ候補一覧で ROOM の URL を開き「コレする」を押すと、'
                        'このアプリの一覧ではコレ済に移動します。',
                    emptyHint: '※ ROOM への実際の投稿完了までは、このアプリでは確認できません。',
                    dayFilterEmptyTitle: 'この日にコレした商品はありません',
                    dayFilterEmptySubtitle: '表示は端末の日付（このアプリでコレ済にした日時）に基づきます。',
                    accentColor: RoomListAccent.done,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTabChip extends StatelessWidget {
  const _RoomTabChip({
    required this.selected,
    required this.accent,
    required this.icon,
    required this.label,
  });

  final bool selected;
  final Color accent;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? accent : AppColors.textTertiary;
    final textColor = selected ? accent : AppColors.textSecondary;
    return Tab(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomManagedProductListTab extends StatelessWidget {
  const _RoomManagedProductListTab({
    required this.status,
    required this.variant,
    required this.filterQuery,
    this.continuousCollectMode = false,
    this.onContinuousModeChanged,
    this.onCollectPressed,
    this.doneAtLocalDayFilter,
    this.onClearDoneDayFilter,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyHint,
    this.dayFilterEmptyTitle,
    this.dayFilterEmptySubtitle,
    required this.accentColor,
    this.listScrollController,
    this.flashHighlightProductId,
    this.rowKeyFor,
    this.focusCandidateProductId,
    this.onCandidateFocusListReady,
    this.onCandidateFocusProductMissing,
  });

  final RakutenManagedProductStatus status;
  final RakutenManagedProductCardVariant variant;
  final String filterQuery;
  final bool continuousCollectMode;
  final ValueChanged<bool>? onContinuousModeChanged;
  final Future<void> Function(
    BuildContext context,
    RakutenManagedProduct product,
  )?
  onCollectPressed;
  final DateTime? doneAtLocalDayFilter;
  final VoidCallback? onClearDoneDayFilter;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyHint;
  final String? dayFilterEmptyTitle;
  final String? dayFilterEmptySubtitle;
  final Color accentColor;
  final ScrollController? listScrollController;
  final String? flashHighlightProductId;
  final GlobalKey Function(String productId)? rowKeyFor;
  final String? focusCandidateProductId;
  final VoidCallback? onCandidateFocusListReady;
  final VoidCallback? onCandidateFocusProductMissing;

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, provider, _) {
        final ui = provider.listUiStatus;

        if (ui == RakutenManagedProductListUiStatus.loading) {
          return const AppScreenLoadingCenter(
            title: 'コレ一覧を読み込んでいます',
            subtitle: 'この端末に保存した候補・コレ済のデータを表示しています。',
          );
        }

        if (ui == RakutenManagedProductListUiStatus.error) {
          return _RoomCollectionErrorState(
            message: provider.listUiErrorMessage ?? '一覧データの読み込みに失敗しました。',
            onRetry: () =>
                provider.refreshManagedProductList(showLoadingIndicator: true),
          );
        }

        final baseList = provider.sortedItemsForStatus(status);
        final scoped =
            status == RakutenManagedProductStatus.done &&
                doneAtLocalDayFilter != null
            ? _filterDoneOnLocalCalendarDay(baseList, doneAtLocalDayFilter!)
            : baseList;
        final list = _filterManagedProductsByQuery(scoped, filterQuery);

        if (baseList.isEmpty) {
          return _RoomCollectionEmptyState(
            title: emptyTitle,
            subtitle: emptySubtitle,
            hint: emptyHint,
            accentColor: accentColor,
          );
        }

        if (scoped.isEmpty &&
            doneAtLocalDayFilter != null &&
            dayFilterEmptyTitle != null &&
            dayFilterEmptySubtitle != null) {
          return _RoomCollectionEmptyState(
            title: dayFilterEmptyTitle!,
            subtitle: dayFilterEmptySubtitle!,
            hint: '日付の絞り込みを解除すると、コレ済の一覧がすべて表示されます。',
            accentColor: accentColor,
            actionLabel: onClearDoneDayFilter != null ? 'すべて表示' : null,
            onAction: onClearDoneDayFilter,
          );
        }

        if (list.isEmpty) {
          return _RoomCollectionSearchEmptyState(accentColor: accentColor);
        }

        final showDayBanner =
            status == RakutenManagedProductStatus.done &&
            doneAtLocalDayFilter != null &&
            onClearDoneDayFilter != null;

        final fid = focusCandidateProductId;
        if (status == RakutenManagedProductStatus.candidate &&
            fid != null &&
            fid.isNotEmpty &&
            onCandidateFocusListReady != null &&
            onCandidateFocusProductMissing != null) {
          final inList = list.any((e) => e.productId == fid);
          if (inList) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onCandidateFocusListReady!();
            });
          } else if (baseList.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onCandidateFocusProductMissing!();
            });
          }
        }

        return RefreshIndicator(
          onRefresh: () =>
              provider.refreshManagedProductList(showLoadingIndicator: true),
          child: ListView(
            controller: listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              4,
              AppDimensions.screenPaddingH,
              24,
            ),
            children: [
              if (showDayBanner) ...[
                _DoneDayFilterBanner(
                  filterDay: doneAtLocalDayFilter!,
                  onClear: onClearDoneDayFilter!,
                ),
                const SizedBox(height: 10),
              ],
              if (status == RakutenManagedProductStatus.candidate)
                _ContinuousCollectModePanel(
                  enabled: continuousCollectMode,
                  onChanged: onContinuousModeChanged ?? (_) {},
                  hasNextCandidate: list.isNotEmpty,
                  nextCandidateName: list.isNotEmpty
                      ? list.first.itemName
                      : null,
                ),
              if (status == RakutenManagedProductStatus.candidate)
                const SizedBox(height: 10),
              for (var i = 0; i < list.length; i++) ...[
                _KeyedCandidateProductRow(
                  product: list[i],
                  variant: variant,
                  onCollectPressed: onCollectPressed,
                  emphasizeAsNext:
                      status == RakutenManagedProductStatus.candidate &&
                      continuousCollectMode &&
                      i == 0,
                  rowKey: rowKeyFor?.call(list[i].productId),
                  flash: flashHighlightProductId == list[i].productId,
                ),
                if (i != list.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KeyedCandidateProductRow extends StatelessWidget {
  const _KeyedCandidateProductRow({
    required this.product,
    required this.variant,
    required this.onCollectPressed,
    required this.emphasizeAsNext,
    this.rowKey,
    this.flash = false,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final Future<void> Function(BuildContext context, RakutenManagedProduct p)?
  onCollectPressed;
  final bool emphasizeAsNext;
  final GlobalKey? rowKey;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    Widget card = RakutenManagedProductCard(
      product: product,
      variant: variant,
      onCollectPressed: onCollectPressed,
      emphasizeAsNext: emphasizeAsNext,
    );
    if (flash) {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.accentLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.accentPrimary, width: 2),
        ),
        child: card,
      );
    }
    if (rowKey != null) {
      return KeyedSubtree(key: rowKey, child: card);
    }
    return card;
  }
}

class _DoneDayFilterBanner extends StatelessWidget {
  const _DoneDayFilterBanner({required this.filterDay, required this.onClear});

  final DateTime filterDay;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '本日（${filterDay.month}/${filterDay.day}）コレした分のみ表示中',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('すべて表示'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinuousCollectModePanel extends StatelessWidget {
  const _ContinuousCollectModePanel({
    required this.enabled,
    required this.onChanged,
    required this.hasNextCandidate,
    required this.nextCandidateName,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool hasNextCandidate;
  final String? nextCandidateName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: enabled ? AppColors.accentPrimary : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.autorenew_rounded,
                size: 18,
                color: enabled
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '連続コレモード',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onChanged,
                activeThumbColor: AppColors.accentPrimary,
              ),
            ],
          ),
          Text(
            enabled
                ? '「コレする」後に戻ると、次に処理する候補を案内します。'
                : 'ONにすると、次にコレする候補を強調表示します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            Text(
              hasNextCandidate
                  ? '次の候補: ${nextCandidateName ?? ''}'
                  : '次の候補はありません',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomCollectionSearchEmptyState extends StatelessWidget {
  const _RoomCollectionSearchEmptyState({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.35,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_outlined,
                    size: 52,
                    color: accentColor.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '検索に一致する商品はありません',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '別のキーワードで試すか、検索欄をクリアしてください。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomCollectionEmptyState extends StatelessWidget {
  const _RoomCollectionEmptyState({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.accentColor,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String hint;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.4,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 56,
                    color: accentColor.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: 16),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomCollectionErrorState extends StatelessWidget {
  const _RoomCollectionErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    '一覧を表示できませんでした',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => onRetry(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('もう一度読み込む'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
