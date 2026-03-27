import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/product_search_hit.dart';
import '../models/product_status.dart';
import '../services/product_search_service.dart';
import '../state/product_list_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/product_card.dart';
import 'product_add_screen.dart';
import 'product_detail_screen.dart';

/// 商品管理画面。検索・タブ・フィルタチップ・商品一覧カード。
/// 「これコレしたっけ？」を素早く確認できる検索体験を優先する。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({super.key});

  @override
  State<ProductsPlaceholderScreen> createState() =>
      _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _tabLabels = ['候補', 'コレ済', 'アーカイブ'];
  static const List<ProductStatus> _tabStatuses = [
    ProductStatus.candidate,
    ProductStatus.collected,
    ProductStatus.archived,
  ];

  static const List<String> _filterChipLabels = [
    'すべて',
    '育児',
    'インテリア',
    'キッチン',
    'ガジェット',
  ];

  int _selectedChipIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
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
        title: const Text('商品管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accentPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(),
          _buildSearchHint(),
          _buildFilterChips(),
          Expanded(
            child: Consumer<ProductListProvider>(
              builder: (context, provider, _) {
                return TabBarView(
                  controller: _tabController,
                  children: _tabStatuses
                      .map((status) => _buildProductList(provider.byStatus(status)))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const ProductAddScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        AppDimensions.spacingMd,
        AppDimensions.screenPaddingH,
        AppDimensions.spacingSm,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: '商品名・URL・タグ・メモ・コメントで検索',
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
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSearchHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        0,
        AppDimensions.screenPaddingH,
        AppDimensions.spacingSm,
      ),
      child: Text(
        'ヒント: URL貼り付けで重複確認 / 商品名やタグでも検索できます',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.screenPaddingH),
        child: Row(
          children: List.generate(_filterChipLabels.length, (index) {
            final isSelected = _selectedChipIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
              child: FilterChip(
                label: Text(_filterChipLabels[index]),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedChipIndex = index);
                },
                selectedColor: AppColors.accentLight,
                checkmarkColor: AppColors.accentPrimary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
                ),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: isSelected ? AppColors.accentPrimary : AppColors.divider,
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildProductList(List<Product> items) {
    final isSearching = _searchQuery.trim().isNotEmpty;
    final hits = isSearching
        ? ProductSearchService.search(items, _searchQuery)
        : items
            .map((p) => ProductSearchHit(product: p, matchKinds: const []))
            .toList();

    if (!isSearching && items.isEmpty) {
      return const EmptyStateView(
        message: 'まだ商品がありません',
        detail: '右下ボタンから追加',
        icon: Icons.shopping_bag_outlined,
      );
    }

    if (isSearching && hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: AppDimensions.iconPlaceholder,
                color: AppColors.accentPrimary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                '一致する商品は見つかりませんでした',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'URLで登録されていないか確認してください。\n商品名やタグ、メモでも検索できます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        AppDimensions.spacingSm,
        AppDimensions.screenPaddingH,
        80,
      ),
      itemCount: hits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hit = hits[index];
        final product = hit.product;
        return ProductCard(
          product: product,
          matchKinds: hit.matchKinds,
          highlightSearchState: isSearching,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ProductDetailScreen(productId: product.id),
              ),
            );
          },
        );
      },
    );
  }
}
