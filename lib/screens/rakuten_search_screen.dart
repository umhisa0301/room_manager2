import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/rakuten_api_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/shop_discovery_summary.dart';
import '../navigation/app_route_observer.dart';
import '../services/shop_discovery_aggregator.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/rakuten_search_result_card.dart';
import '../widgets/shop_discovery_card.dart';
import 'saved_shops_screen.dart';
import 'shop_discovery_detail_screen.dart';

/// 楽天API商品検索画面（最小構成）。
class RakutenSearchScreen extends StatefulWidget {
  const RakutenSearchScreen({super.key});

  @override
  State<RakutenSearchScreen> createState() => _RakutenSearchScreenState();
}

class _RakutenSearchScreenState extends State<RakutenSearchScreen>
    with RouteAware, SingleTickerProviderStateMixin {
  _RakutenSearchMode _mode = _RakutenSearchMode.product;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _excludeKeywordController = TextEditingController();
  final TextEditingController _minReviewCountController = TextEditingController();
  final TextEditingController _minReviewAverageController = TextEditingController();
  final TextEditingController _minCommentCountController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _shopDiscoveryKeywordController =
      TextEditingController();
  final TextEditingController _shopDiscoveryExcludeController =
      TextEditingController();
  final TextEditingController _shopDiscoveryMinReviewCountController =
      TextEditingController();
  final TextEditingController _shopDiscoveryMinReviewAverageController =
      TextEditingController();
  final TextEditingController _shopDiscoveryShopLimitController =
      TextEditingController(text: '10');
  final TextEditingController _shopDiscoveryItemsPerShopController =
      TextEditingController(text: '5');
  String? _selectedShopCode;
  String? _selectedGenreId;
  String? _selectedDiscoveryGenreId;
  bool _excludeCandidate = false;
  bool _excludeDone = false;
  bool _selectionMode = false;
  bool _isBulkRegistering = false;
  final Set<String> _selectedProductIds = <String>{};
  bool _routeSubscribed = false;
  late final TabController _modeTabController;
  _GenreSort _genreSort = _GenreSort.reviewCount;
  bool _excludeSavedShops = true;

  void _resetSearchUi() {
    _keywordController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _excludeKeywordController.clear();
    _minReviewCountController.clear();
    _minReviewAverageController.clear();
    _minCommentCountController.clear();
    _genreController.clear();
    _shopDiscoveryKeywordController.clear();
    _shopDiscoveryExcludeController.clear();
    _shopDiscoveryMinReviewCountController.clear();
    _shopDiscoveryMinReviewAverageController.clear();
    _shopDiscoveryShopLimitController.text = '10';
    _shopDiscoveryItemsPerShopController.text = '5';
    _selectedShopCode = null;
    _selectedGenreId = null;
    _selectedDiscoveryGenreId = null;
    _excludeCandidate = false;
    _excludeDone = false;
    _selectionMode = false;
    _isBulkRegistering = false;
    _selectedProductIds.clear();
    _mode = _RakutenSearchMode.product;
    _genreSort = _GenreSort.reviewCount;
    context.read<RakutenSearchProvider>().resetTransientState();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _modeTabController = TabController(
      length: _RakutenSearchMode.values.length,
      vsync: this,
      initialIndex: _mode.index,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetSearchUi();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _keywordController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _excludeKeywordController.dispose();
    _minReviewCountController.dispose();
    _minReviewAverageController.dispose();
    _minCommentCountController.dispose();
    _genreController.dispose();
    _shopDiscoveryKeywordController.dispose();
    _shopDiscoveryExcludeController.dispose();
    _shopDiscoveryMinReviewCountController.dispose();
    _shopDiscoveryMinReviewAverageController.dispose();
    _shopDiscoveryShopLimitController.dispose();
    _shopDiscoveryItemsPerShopController.dispose();
    _modeTabController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _resetSearchUi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('楽天検索'),
      ),
      body: SafeArea(
        child: Consumer3<RakutenSearchProvider, RakutenManagedProductProvider,
            SavedShopProvider>(
          builder: (context, search, managed, saved, _) {
            return Column(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _buildModeAndInputArea(context, search),
                  ),
                ),
                Expanded(
                  child: _buildResultArea(context, search, managed, saved),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _runSearch(BuildContext context) {
    setState(() {
      _selectionMode = false;
      _selectedProductIds.clear();
    });
    final condition = _buildProductCondition();
    context.read<RakutenSearchProvider>().searchWithCondition(condition);
  }

  RakutenProductSearchCondition _buildProductCondition() {
    return RakutenProductSearchCondition(
      keyword: _keywordController.text,
      minPrice: _parseInt(_minPriceController.text),
      maxPrice: _parseInt(_maxPriceController.text),
      excludeKeyword: _excludeKeywordController.text,
      minReviewCount: _parseInt(_minReviewCountController.text),
      minReviewAverage: _parseDouble(_minReviewAverageController.text),
      minCommentCount: _parseInt(_minCommentCountController.text),
      shopCode: _selectedShopCode,
      genreId: _selectedGenreId,
    ).normalized();
  }

  int? _parseInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double? _parseDouble(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Widget _buildModeAndInputArea(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DiscoveryFlowGuide(),
          const SizedBox(height: 8),
          Text(
            '検索モード',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _ModeTabBar(
            controller: _modeTabController,
            onChanged: _onModeChanged,
          ),
          const SizedBox(height: 8),
          Text(
            _mode.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 8),
          switch (_mode) {
            _RakutenSearchMode.product => _buildProductInput(context, search),
            _RakutenSearchMode.genre => _buildGenreInput(context),
            _RakutenSearchMode.shopDiscovery => _buildShopDiscoveryInput(context),
          },
        ],
      ),
    );
  }

  Widget _buildProductInput(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(context),
                decoration: const InputDecoration(
                  hintText: '商品キーワードを入力',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: search.status == RakutenSearchStatus.loading
                  ? null
                  : () => _runSearch(context),
              child: const Text('検索'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'キーワードで商品を探し、必要なら詳細条件で絞り込みます。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openProductConditionsSheet(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('詳細条件'),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'キーワードが思いつかないときに、ジャンルから次の候補商品を探すためのモードです。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'ジャンルを選択',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedGenreId,
              items: _mockGenres
                  .map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.id,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedGenreId = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _genreController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: '補助キーワード（任意）',
            hintText: '例: 収納 ボックス',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (_) => _runGenreSearch(context),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openProductConditionsSheet(context),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('詳細条件'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _runGenreSearch(context),
                child: const Text('ジャンルで検索'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShopDiscoveryInput(BuildContext context) {
    final savedCount = context.watch<SavedShopProvider>().shops.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'キーワードやジャンルから、売れ筋商品を扱うショップを探します。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _shopDiscoveryKeywordController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'キーワード',
            hintText: '例: おしゃれ 家具',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'ジャンル',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedDiscoveryGenreId,
              items: _mockGenres
                  .map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.id,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedDiscoveryGenreId = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openShopDiscoveryConditionsSheet(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('発掘条件'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _runShopDiscovery(context),
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text(
              'ショップを発掘する',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SavedShopsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.bookmarks_outlined, size: 18),
          label: Text('保存ショップを見る（$savedCount件）'),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureは次ステップで有効化します')),
    );
  }

  void _onModeChanged(_RakutenSearchMode next) {
    if (_mode == next) return;
    setState(() => _mode = next);
    _modeTabController.animateTo(next.index);
    context.read<RakutenSearchProvider>().resetTransientState();
  }

  Future<void> _openProductConditionsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'キーワード検索の詳細条件',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最低価格',
                            hintText: '1000',
                            prefixIcon: Icon(Icons.currency_yen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最高価格',
                            hintText: '5000',
                            prefixIcon: Icon(Icons.currency_yen),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _excludeKeywordController,
                    decoration: const InputDecoration(
                      labelText: '除外ワード',
                      hintText: '中古 訳あり',
                      prefixIcon: Icon(Icons.block_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minReviewCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最低評価数',
                            hintText: '50',
                            prefixIcon: Icon(Icons.reviews_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _minReviewAverageController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: '最低評価点数',
                            hintText: '4.0',
                            prefixIcon: Icon(Icons.star_outline_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _minCommentCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最低コメント数',
                      hintText: '30',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'ショップ選択',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedShopCode,
                        items: _mockShops
                            .map(
                              (e) => DropdownMenuItem<String?>(
                                value: e.code,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedShopCode = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'ジャンル選択',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedGenreId,
                        items: _mockGenres
                            .map(
                              (e) => DropdownMenuItem<String?>(
                                value: e.id,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedGenreId = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openShopDiscoveryConditionsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ショップ発掘の詳細条件',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shopDiscoveryExcludeController,
                    decoration: const InputDecoration(
                      labelText: '除外ワード',
                      hintText: '例: 中古 訳あり',
                      prefixIcon: Icon(Icons.block_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shopDiscoveryMinReviewCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最低評価数',
                            hintText: '100',
                            prefixIcon: Icon(Icons.reviews_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _shopDiscoveryMinReviewAverageController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: '最低評価点',
                            hintText: '4.2',
                            prefixIcon: Icon(Icons.star_outline_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shopDiscoveryShopLimitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '表示ショップ数',
                            hintText: '10',
                            prefixIcon: Icon(Icons.store_mall_directory_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _shopDiscoveryItemsPerShopController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '1ショップあたり表示商品数',
                            hintText: '5',
                            prefixIcon: Icon(Icons.view_stream_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _runShopDiscovery(BuildContext context) {
    final keyword = _shopDiscoveryKeywordController.text.trim();
    final genreId = _selectedDiscoveryGenreId;
    if (keyword.isEmpty && (genreId == null || genreId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('キーワードまたはジャンルを指定してください')),
      );
      return;
    }
    final fallbackKeyword = _labelForGenre(genreId) ?? '楽天';
    final condition = RakutenProductSearchCondition(
      keyword: keyword.isNotEmpty ? keyword : fallbackKeyword,
      excludeKeyword: _shopDiscoveryExcludeController.text,
      minReviewCount: _parseInt(_shopDiscoveryMinReviewCountController.text),
      minReviewAverage: _parseDouble(_shopDiscoveryMinReviewAverageController.text),
      genreId: genreId,
    ).normalized();
    context.read<RakutenSearchProvider>().searchWithCondition(condition);
  }

  String? _labelForGenre(String? id) {
    if (id == null) return null;
    for (final g in _mockGenres) {
      if (g.id == id) return g.label;
    }
    return null;
  }

  Future<void> _runGenreSearch(BuildContext context) async {
    if (_selectedGenreId == null || _selectedGenreId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ジャンルを選択してください')),
      );
      return;
    }
    final condition = RakutenProductSearchCondition(
      keyword: _genreController.text,
      minPrice: _parseInt(_minPriceController.text),
      maxPrice: _parseInt(_maxPriceController.text),
      excludeKeyword: _excludeKeywordController.text,
      minReviewCount: _parseInt(_minReviewCountController.text),
      minReviewAverage: _parseDouble(_minReviewAverageController.text),
      genreId: _selectedGenreId,
    ).normalized();
    await context.read<RakutenSearchProvider>().searchWithCondition(condition);
  }

  List<RakutenSearchItem> _applyLocalStatusFilters(
    List<RakutenSearchItem> source,
    RakutenManagedProductProvider managed,
  ) {
    if (!_excludeCandidate && !_excludeDone) return source;
    return source.where((item) {
      final status = managed.statusForProduct(item.productId);
      if (_excludeCandidate && status == RakutenManagedProductStatus.candidate) {
        return false;
      }
      if (_excludeDone && status == RakutenManagedProductStatus.done) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 候補済・コレ済の商品や保存済みショップの商品を優先的に除外したリストを返す。
  /// ただし、除外しすぎて極端に件数が減る場合は元のリストをそのまま使う前提で呼び出し元でフォールバックする。
  List<RakutenSearchItem> _applyPreferredExcludes(
    List<RakutenSearchItem> source,
    RakutenManagedProductProvider managed,
    SavedShopProvider saved,
  ) {
    if (source.isEmpty) return source;
    final out = <RakutenSearchItem>[];
    for (final item in source) {
      final status = managed.statusForProduct(item.productId);
      final fromSavedShop =
          item.shopCode.trim().isNotEmpty && saved.isSaved(item.shopCode.trim());
      if (status == RakutenManagedProductStatus.candidate ||
          status == RakutenManagedProductStatus.done ||
          fromSavedShop) {
        // 優先除外候補
        continue;
      }
      out.add(item);
    }
    // 除外後が極端に少ないときは、呼び出し側で元リストにフォールバックさせる。
    return out;
  }

  bool _isSelectableForBulk(
    RakutenSearchItem item,
    RakutenManagedProductProvider managed,
  ) {
    final status = managed.statusForProduct(item.productId);
    return status == RakutenManagedProductStatus.none;
  }

  String? _selectionDisabledReason(
    RakutenSearchItem item,
    RakutenManagedProductProvider managed,
  ) {
    final status = managed.statusForProduct(item.productId);
    if (status == RakutenManagedProductStatus.candidate) {
      return 'コレ候補登録済のため選択不可';
    }
    if (status == RakutenManagedProductStatus.done) {
      return 'コレ済のため選択不可';
    }
    return null;
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedProductIds.clear();
      }
    });
  }

  Future<void> _bulkRegisterCandidates(
    RakutenManagedProductProvider managed,
    List<RakutenSearchItem> source,
  ) async {
    if (_isBulkRegistering || _selectedProductIds.isEmpty) return;
    setState(() => _isBulkRegistering = true);
    var success = 0;
    var failed = 0;
    final selectedItems = source
        .where((e) => _selectedProductIds.contains(e.productId))
        .toList();
    for (final item in selectedItems) {
      final err = await managed.registerCandidate(item);
      if (err == null) {
        success++;
      } else {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _isBulkRegistering = false;
      _selectionMode = false;
      _selectedProductIds.clear();
    });
    final failureText = failed > 0 ? ' / 失敗 $failed件' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('一括で候補登録しました: 成功 $success件$failureText')),
    );
  }

  void _selectAllForBulk(
    List<RakutenSearchItem> source,
    RakutenManagedProductProvider managed,
  ) {
    setState(() {
      _selectedProductIds.clear();
      for (final item in source) {
        if (_isSelectableForBulk(item, managed)) {
          _selectedProductIds.add(item.productId);
        }
      }
    });
  }

  void _clearBulkSelection() {
    setState(() {
      _selectedProductIds.clear();
    });
  }

  Widget _buildResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
    SavedShopProvider saved,
  ) {
    if (_mode == _RakutenSearchMode.shopDiscovery) {
      return _buildShopDiscoveryResultArea(context, search);
    }
    if (_mode == _RakutenSearchMode.genre) {
      return _buildGenreResultArea(context, search, managed);
    }
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return _centerText('商品名やキーワードを入力して検索してください');
      case RakutenSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RakutenSearchStatus.error:
        return _searchErrorPanel(
          context,
          message: search.errorMessage,
          onRetry: () => _runSearch(context),
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return _centerText('検索結果は0件でした');
        }
        final managedPreferred = _applyPreferredExcludes(
          search.results,
          managed,
          saved,
        );
        final base = managedPreferred.isNotEmpty ? managedPreferred : search.results;
        final filteredResults = _applyLocalStatusFilters(base, managed);
        final selectableCount =
            filteredResults.where((e) => _isSelectableForBulk(e, managed)).length;
        final totalCount = search.results.length;
        final showingCount = filteredResults.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kDebugMode) _buildAffiliateDebugBanner(search),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isBulkRegistering ? null : _toggleSelectionMode,
                    icon: Icon(
                      _selectionMode
                          ? Icons.checklist_rtl_rounded
                          : Icons.playlist_add_check_rounded,
                    ),
                    label: Text(_selectionMode ? '選択終了' : '選択モード'),
                  ),
                  const SizedBox(width: 8),
                  if (_selectionMode)
                    Expanded(
                      child: Text(
                        '選択中 ${_selectedProductIds.length}件 / 選択可能 $selectableCount件',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (_selectionMode) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: filteredResults.isEmpty || _isBulkRegistering
                          ? null
                          : () => _selectAllForBulk(filteredResults, managed),
                      child: const Text('全部選択'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _selectedProductIds.isEmpty || _isBulkRegistering
                          ? null
                          : _clearBulkSelection,
                      child: const Text('全部解除'),
                    ),
                  ],
                ],
              ),
            ),
            _SearchLocalFilterBar(
              excludeCandidate: _excludeCandidate,
              excludeDone: _excludeDone,
              onExcludeCandidateChanged: (next) {
                setState(() => _excludeCandidate = next);
              },
              onExcludeDoneChanged: (next) {
                setState(() => _excludeDone = next);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                totalCount >= 100
                    ? '表示 $showingCount件 / 取得 $totalCount件（最大100件まで取得しています）'
                    : '表示 $showingCount件 / 取得 $totalCount件',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            Expanded(
              child: filteredResults.isEmpty
                  ? _centerText(
                      '登録済みの候補・コレ済・保存ショップ由来の商品を優先的に除外した結果、'
                      '表示できる商品がありません。\n'
                      '除外フィルタをOFFにするか、条件を少し緩めて再検索してください。',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                      itemCount: filteredResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filteredResults[index];
                        final isSelectable = _isSelectableForBulk(item, managed);
                        return RakutenSearchResultCard(
                          item: item,
                          localStatus: managed.statusForProduct(item.productId),
                          isRegistering: managed.isRegistering(item.productId),
                          selectionMode: _selectionMode,
                          isSelected:
                              _selectedProductIds.contains(item.productId),
                          isSelectionEnabled: isSelectable && !_isBulkRegistering,
                          selectionDisabledLabel:
                              _selectionDisabledReason(item, managed),
                          onToggleSelected: () {
                            if (!isSelectable || _isBulkRegistering) return;
                            setState(() {
                              if (_selectedProductIds.contains(item.productId)) {
                                _selectedProductIds.remove(item.productId);
                              } else {
                                _selectedProductIds.add(item.productId);
                              }
                            });
                          },
                          onRegisterCandidate: () async {
                            final err = await managed.registerCandidate(item);
                            if (!context.mounted) return;
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
            if (_selectionMode)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selectedProductIds.isEmpty || _isBulkRegistering
                          ? null
                          : () => _bulkRegisterCandidates(
                                managed,
                                filteredResults,
                              ),
                      icon: _isBulkRegistering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_add_check_rounded),
                      label: Text(
                        _isBulkRegistering
                            ? '一括登録中...'
                            : 'まとめて候補登録（${_selectedProductIds.length}件）',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _buildGenreResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
  ) {
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return _centerText('ジャンルと必要なら補助キーワードを指定して検索してください');
      case RakutenSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RakutenSearchStatus.error:
        return _searchErrorPanel(
          context,
          message:
              'ジャンル検索を完了できませんでした。\n${search.errorMessage}',
          onRetry: () {
            _runGenreSearch(context);
          },
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return _centerText('指定したジャンルでは商品が見つかりませんでした');
        }
        final managedPreferred = _applyPreferredExcludes(
          search.results,
          managed,
          context.read<SavedShopProvider>(),
        );
        final base = managedPreferred.isNotEmpty ? managedPreferred : search.results;
        final filteredResults = _applyLocalStatusFilters(base, managed);
        if (filteredResults.isEmpty) {
          return _centerText(
            '除外条件やフィルタにより、表示できる商品がありませんでした。\n条件を緩めて再検索してください。',
          );
        }
        final sorted = [...filteredResults];
        switch (_genreSort) {
          case _GenreSort.reviewCount:
            sorted.sort(
              (a, b) => b.reviewCount.compareTo(a.reviewCount),
            );
          case _GenreSort.reviewAverage:
            sorted.sort(
              (a, b) => b.reviewAverage.compareTo(a.reviewAverage),
            );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    'ジャンル検索結果（${sorted.length}件）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  DropdownButton<_GenreSort>(
                    value: _genreSort,
                    underline: const SizedBox.shrink(),
                    onChanged: (next) {
                      if (next == null) return;
                      setState(() => _genreSort = next);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: _GenreSort.reviewCount,
                        child: Text('評価数順'),
                      ),
                      DropdownMenuItem(
                        value: _GenreSort.reviewAverage,
                        child: Text('評価点順'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  return RakutenSearchResultCard(
                    item: item,
                    localStatus: managed.statusForProduct(item.productId),
                    isRegistering: managed.isRegistering(item.productId),
                    onRegisterCandidate: () async {
                      final err = await managed.registerCandidate(item);
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildShopDiscoveryResultArea(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return _centerText(
          'ショップ発掘モードです。\n'
          'キーワードまたはジャンルを指定して「ショップを発掘する」を押してください。',
        );
      case RakutenSearchStatus.loading:
        return _loadingGuide(
          title: 'ショップを分析中...',
          subtitle: '売れ筋商品をショップ単位に集約しています',
        );
      case RakutenSearchStatus.error:
        return _errorGuide(
          message:
              'ショップ発掘を完了できませんでした。\n${search.errorMessage}',
          onRetry: () => _runShopDiscovery(context),
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return _centerText('ショップ発掘の対象商品がありませんでした');
        }
        final shopLimit = _parseInt(_shopDiscoveryShopLimitController.text) ?? 10;
        final itemsPerShop =
            _parseInt(_shopDiscoveryItemsPerShopController.text) ?? 5;
        final summaries = ShopDiscoveryAggregator.aggregate(
          search.results,
          shopLimit: shopLimit,
          itemsPerShop: itemsPerShop,
        );
        if (summaries.isEmpty) {
          return _centerText('ショップとして集約できる結果がありませんでした');
        }
        return Consumer<SavedShopProvider>(
          builder: (context, saved, _) {
            final raw = summaries;
            final filtered = raw
                .where(
                  (s) => _excludeSavedShops ? !saved.isSaved(s.shopKey) : true,
                )
                .toList(growable: false);
            final visible = filtered.isEmpty ? raw : filtered;
            final removedCount = raw.length - visible.length;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '発掘結果 ${visible.length}ショップ（スコア順）',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '売れ筋度は「ヒット商品数」「評価数」「評価点」から計算した、このアプリ独自のスコアです。',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                        if (_excludeSavedShops)
                          Text(
                            removedCount > 0
                                ? '※ 保存済みショップを除外しています（除外 $removedCount件）。'
                                : '※ 保存済みショップも含めて表示されています。',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.textTertiary,
                                  height: 1.3,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      selected: _excludeSavedShops,
                      onSelected: (next) {
                        setState(() => _excludeSavedShops = next);
                      },
                      label: const Text('保存済ショップを除外'),
                      avatar: const Icon(Icons.bookmarks_outlined, size: 18),
                      selectedColor:
                          AppColors.accentPrimary.withValues(alpha: 0.15),
                      showCheckmark: false,
                      side: BorderSide(
                        color: _excludeSavedShops
                            ? AppColors.accentPrimary
                            : AppColors.divider,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final summary = visible[index];
                      final shopItems = search.results
                          .where((e) => _shopDiscoveryGroupKey(e) == summary.shopKey)
                          .toList(growable: false);
                      final isSaved = saved.isSaved(summary.shopKey);
                      return ShopDiscoveryCard(
                        summary: summary,
                        rank: index + 1,
                        isSaved: isSaved,
                        onOpenShop: () => _openShopDetail(context, summary, shopItems),
                        onSave: () => _saveDiscoveredShop(context, summary, isSaved),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
    }
  }

  Widget _loadingGuide({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchErrorPanel(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.error,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('もう一度試す'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorGuide({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.error,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('同じ条件で再実行'),
            ),
          ],
        ),
      ),
    );
  }

  String _shopDiscoveryGroupKey(RakutenSearchItem item) {
    final code = item.shopCode.trim();
    if (code.isNotEmpty) return code;
    final name = item.shopName.trim();
    if (name.isNotEmpty) return name;
    return 'unknown';
  }

  Future<void> _openShopDetail(
    BuildContext context,
    ShopDiscoverySummary summary,
    List<RakutenSearchItem> items,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopDiscoveryDetailScreen(
          summary: summary,
          items: items,
        ),
      ),
    );
  }

  Future<void> _saveDiscoveredShop(
    BuildContext context,
    ShopDiscoverySummary summary,
    bool isSaved,
  ) async {
    final savedProvider = context.read<SavedShopProvider>();
    if (isSaved) {
      await savedProvider.removeShop(summary.shopKey);
    } else {
      await savedProvider.upsertShop(
        shopId: summary.shopKey,
        shopName: summary.shopName,
        shopUrl: summary.shopUrl,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isSaved ? '保存解除しました' : '保存しました')),
    );
  }

  Widget _buildAffiliateDebugBanner(RakutenSearchProvider provider) {
    final req = RakutenApiConfig.requestIncludesAffiliateId;
    final n = provider.resultsWithAffiliateUrlCount;
    final total = provider.results.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        'DEBUG: リクエストにaffiliateId付与=$req / レスポンスaffiliateUrlあり $n/$total 件 '
        '（APIはaffiliateId文字列を返しません。affiliateUrlの有無で判断）',
        style: TextStyle(
          fontSize: 11,
          height: 1.25,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _centerText(String text, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _modePlaceholder() {
    final title = switch (_mode) {
      _RakutenSearchMode.genre => 'ジャンル検索の結果はここに表示されます',
      _RakutenSearchMode.shopDiscovery => 'ショップ発掘の結果はここに表示されます',
      _RakutenSearchMode.product => '',
    };
    final guide = switch (_mode) {
      _RakutenSearchMode.genre =>
        '上部でジャンル名を入力し検索すると、ジャンルに沿った商品一覧を表示する予定です。',
      _RakutenSearchMode.shopDiscovery =>
        '上部の条件を指定して実行すると、有望なショップ候補を表示する予定です。',
      _RakutenSearchMode.product => '',
    };
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _mode.icon,
                    size: 52,
                    color: AppColors.textTertiary.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guide,
                    textAlign: TextAlign.center,
                    style: TextStyle(
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

enum _RakutenSearchMode {
  product('キーワード検索', Icons.shopping_bag_outlined, 'キーワード中心で商品を探し、必要に応じて詳細条件で絞り込みます'),
  genre('ジャンル検索', Icons.category_outlined, '楽天ジャンルを軸に商品を探します（順次機能拡張）'),
  shopDiscovery('ショップ発掘', Icons.storefront_outlined, 'キーワードやジャンルから強いショップ候補を見つけます');

  const _RakutenSearchMode(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class _DiscoveryFlowGuide extends StatelessWidget {
  const _DiscoveryFlowGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        'おすすめ導線: ショップ発掘 → ショップ詳細で商品比較 → 保存ショップで再訪',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ModeTabBar extends StatelessWidget {
  const _ModeTabBar({
    required this.controller,
    required this.onChanged,
  });

  final TabController controller;
  final ValueChanged<_RakutenSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: TabBar(
        controller: controller,
        onTap: (index) => onChanged(_RakutenSearchMode.values[index]),
        tabs: [
          for (final mode in _RakutenSearchMode.values)
            Tab(
              icon: Icon(mode.icon, size: 18),
              text: mode.label,
            ),
        ],
        indicator: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        labelColor: AppColors.accentPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dividerColor: Colors.transparent,
      ),
    );
  }
}

class _SearchShopOption {
  const _SearchShopOption(this.code, this.label);
  final String? code;
  final String label;
}

class _SearchGenreOption {
  const _SearchGenreOption(this.id, this.label);
  final String? id;
  final String label;
}

enum _GenreSort {
  reviewCount,
  reviewAverage,
}

class _SearchLocalFilterBar extends StatelessWidget {
  const _SearchLocalFilterBar({
    required this.excludeCandidate,
    required this.excludeDone,
    required this.onExcludeCandidateChanged,
    required this.onExcludeDoneChanged,
  });

  final bool excludeCandidate;
  final bool excludeDone;
  final ValueChanged<bool> onExcludeCandidateChanged;
  final ValueChanged<bool> onExcludeDoneChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            selected: excludeCandidate,
            onSelected: onExcludeCandidateChanged,
            label: const Text('コレ候補登録済を除外'),
            avatar: const Icon(Icons.bookmark_added_outlined, size: 18),
            selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
            showCheckmark: false,
            side: BorderSide(
              color: excludeCandidate ? AppColors.accentPrimary : AppColors.divider,
            ),
          ),
          FilterChip(
            selected: excludeDone,
            onSelected: onExcludeDoneChanged,
            label: const Text('コレ済を除外'),
            avatar: const Icon(Icons.check_circle_outline, size: 18),
            selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
            showCheckmark: false,
            side: BorderSide(
              color: excludeDone ? AppColors.accentPrimary : AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

const List<_SearchShopOption> _mockShops = [
  _SearchShopOption(null, '指定なし'),
  _SearchShopOption('rakuten24', '楽天24'),
  _SearchShopOption('book', '楽天ブックス'),
  _SearchShopOption('biccamera', 'ビックカメラ楽天市場店'),
];

const List<_SearchGenreOption> _mockGenres = [
  _SearchGenreOption(null, '指定なし'),
  _SearchGenreOption('100939', 'インテリア・寝具・収納'),
  _SearchGenreOption('551167', '家電'),
  _SearchGenreOption('565004', '日用品雑貨・文房具・手芸'),
];
