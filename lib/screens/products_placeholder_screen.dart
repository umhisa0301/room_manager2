import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../state/product_list_provider.dart';
import 'product_add_screen.dart';
import 'product_detail_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/empty_state_view.dart';

/// 商品管理画面。検索・タブ・フィルタチップ・商品一覧カード。
/// タブは status でフィルタし、FAB から追加画面へ遷移する。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({super.key});

  @override
  State<ProductsPlaceholderScreen> createState() => _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        readOnly: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('検索は未実装')),
          );
        },
        decoration: InputDecoration(
          hintText: '商品を検索',
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.textTertiary,
            size: 22,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPaddingH),
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
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
    if (items.isEmpty) {
      return const EmptyStateView(
        message: 'まだ商品がありません',
        detail: '右下ボタンから追加',
        icon: Icons.shopping_bag_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        AppDimensions.spacingSm,
        AppDimensions.screenPaddingH,
        80,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = items[index];
        return ProductCard(
          product: product,
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
