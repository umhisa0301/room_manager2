import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
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
  const ProductsPlaceholderScreen({super.key});

  @override
  State<ProductsPlaceholderScreen> createState() =>
      _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyHint,
    required this.accentColor,
  });

  final RakutenManagedProductStatus status;
  final RakutenManagedProductCardVariant variant;
  final String filterQuery;
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
          return const Center(child: CircularProgressIndicator());
        }

        if (ui == RakutenManagedProductListUiStatus.error) {
          return _RoomCollectionErrorState(
            message: provider.listUiErrorMessage ?? '読み込みに失敗しました',
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
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return RakutenManagedProductCard(
                product: list[index],
                variant: variant,
              );
            },
          ),
        );
      },
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
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => onRetry(),
                    child: const Text('再試行'),
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
