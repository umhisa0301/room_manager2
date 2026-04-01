import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
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

/// ROOMコレ管理画面。楽天検索で登録したコレ候補・コレ済をタブで表示する。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  /// 0: コレ候補、1: コレ済
  final int initialTabIndex;

  @override
  State<ProductsPlaceholderScreen> createState() =>
      _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _continuousCollectMode = false;
  bool _awaitingContinuousResume = false;
  String _lastCollectedName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
            showLoadingIndicator: false,
          );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {});
    });
  }

  RakutenManagedProduct? _nextCandidate(RakutenManagedProductProvider provider) {
    final base =
        provider.sortedItemsForStatus(RakutenManagedProductStatus.candidate);
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
    final moved = provider.statusForProduct(product.productId) ==
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ROOMコレ管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
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
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.surface,
            child: Consumer<RakutenManagedProductProvider>(
              builder: (context, managed, _) {
                final nCand = managed
                    .sortedItemsForStatus(RakutenManagedProductStatus.candidate)
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
              8,
              AppDimensions.screenPaddingH,
              6,
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
                    '商品追加：右上の「楽天で検索」　／　下の欄は保存済み一覧の絞り込みです',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
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
              8,
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
                  emptyHint:
                      'まずは右上の「楽天で検索」から商品を探してみてください。',
                  accentColor: RoomListAccent.candidate,
                ),
                _RoomManagedProductListTab(
                  status: RakutenManagedProductStatus.done,
                  variant: RakutenManagedProductCardVariant.done,
                  filterQuery: _searchQuery,
                  continuousCollectMode: false,
                  emptyTitle: 'コレ済の商品はまだありません',
                  emptySubtitle:
                      'コレ候補一覧で ROOM の URL を開き「コレする」を押すと、'
                      'このアプリの一覧ではコレ済に移動します。',
                  emptyHint: '※ ROOM への実際の投稿完了までは、このアプリでは確認できません。',
                  accentColor: RoomListAccent.done,
                ),
              ],
            ),
          ),
        ],
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
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyHint,
    required this.accentColor,
  });

  final RakutenManagedProductStatus status;
  final RakutenManagedProductCardVariant variant;
  final String filterQuery;
  final bool continuousCollectMode;
  final ValueChanged<bool>? onContinuousModeChanged;
  final Future<void> Function(
    BuildContext context,
    RakutenManagedProduct product,
  )? onCollectPressed;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyHint;
  final Color accentColor;

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
            message: provider.listUiErrorMessage ??
                '一覧データの読み込みに失敗しました。',
            onRetry: () => provider.refreshManagedProductList(
              showLoadingIndicator: true,
            ),
          );
        }

        final baseList = provider.sortedItemsForStatus(status);
        final list = _filterManagedProductsByQuery(baseList, filterQuery);

        if (baseList.isEmpty) {
          return _RoomCollectionEmptyState(
            title: emptyTitle,
            subtitle: emptySubtitle,
            hint: emptyHint,
            accentColor: accentColor,
          );
        }

        if (list.isEmpty) {
          return _RoomCollectionSearchEmptyState(accentColor: accentColor);
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshManagedProductList(
            showLoadingIndicator: true,
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              4,
              AppDimensions.screenPaddingH,
              24,
            ),
            children: [
              if (status == RakutenManagedProductStatus.candidate)
                _ContinuousCollectModePanel(
                  enabled: continuousCollectMode,
                  onChanged: onContinuousModeChanged ?? (_) {},
                  hasNextCandidate: list.isNotEmpty,
                  nextCandidateName:
                      list.isNotEmpty ? list.first.itemName : null,
                ),
              if (status == RakutenManagedProductStatus.candidate)
                const SizedBox(height: 10),
              for (var i = 0; i < list.length; i++) ...[
                RakutenManagedProductCard(
                  product: list[i],
                  variant: variant,
                  onCollectPressed: onCollectPressed,
                  emphasizeAsNext:
                      status == RakutenManagedProductStatus.candidate &&
                          continuousCollectMode &&
                          i == 0,
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
                color: enabled ? AppColors.accentPrimary : AppColors.textSecondary,
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
  });

  final String title;
  final String subtitle;
  final String hint;
  final Color accentColor;

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
