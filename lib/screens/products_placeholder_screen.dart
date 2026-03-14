import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product_item.dart';
import '../data/dummy_products.dart';
import '../widgets/product_card.dart';

/// 商品管理画面。検索・タブ・フィルタチップ・商品一覧カード。
/// タブ・チップの選択状態は後で実データのフィルタと連携しやすいように分離している。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({super.key});

  @override
  State<ProductsPlaceholderScreen> createState() => _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// タブ: 0=候補, 1=コレ済, 2=アーカイブ。後で実データの status と連携可能。
  static const List<String> _tabLabels = ['候補', 'コレ済', 'アーカイブ'];

  /// フィルタチップ（見た目のみ）。後でカテゴリフィルタと連携可能。
  static const List<String> _filterChipLabels = [
    'すべて',
    '育児',
    'インテリア',
    'キッチン',
    'ガジェット',
  ];

  int _selectedChipIndex = 0;
  final List<ProductItem> _dummyProducts = getDummyProducts();

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
              tabs: _tabLabels
                  .map((label) => Tab(text: label))
                  .toList(),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(),
                _buildProductList(),
                _buildProductList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未実装')),
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

  Widget _buildProductList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        AppDimensions.spacingMd,
        AppDimensions.screenPaddingH,
        80,
      ),
      itemCount: _dummyProducts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spacingMd),
      itemBuilder: (context, index) {
        return ProductCard(
          item: _dummyProducts[index],
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_dummyProducts[index].name} 詳細は未実装')),
            );
          },
        );
      },
    );
  }
}
