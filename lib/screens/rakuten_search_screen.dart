import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/rakuten_api_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../navigation/app_route_observer.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/rakuten_search_result_card.dart';

/// 楽天API商品検索画面（最小構成）。
class RakutenSearchScreen extends StatefulWidget {
  const RakutenSearchScreen({super.key});

  @override
  State<RakutenSearchScreen> createState() => _RakutenSearchScreenState();
}

class _RakutenSearchScreenState extends State<RakutenSearchScreen>
    with RouteAware {
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
      TextEditingController(text: '20');
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
    _shopDiscoveryShopLimitController.text = '20';
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
    context.read<RakutenSearchProvider>().resetTransientState();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
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
        child: Consumer2<RakutenSearchProvider, RakutenManagedProductProvider>(
          builder: (context, search, managed, _) {
            return Column(
              children: [
                _buildModeAndInputArea(context, search),
                Expanded(
                  child: _buildResultArea(context, search, managed),
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
          Text(
            '検索モード',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _ModeSegmentedChips(
            currentMode: _mode,
            onChanged: (next) {
              if (_mode == next) return;
              setState(() => _mode = next);
              context.read<RakutenSearchProvider>().resetTransientState();
            },
          ),
          const SizedBox(height: 10),
          Text(
            _mode.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 10),
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
          'キーワードに加えて、価格・評価・ショップ・ジャンル条件を指定できます。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: const Text(
              '詳細条件を開く',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('価格・除外ワード・評価・ショップ・ジャンル'),
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenreInput(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _genreController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'ジャンル名を入力（例: インテリア）',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            onSubmitted: (_) => _showComingSoon(context, 'ジャンル検索'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showComingSoon(context, 'ジャンル検索'),
          child: const Text('検索'),
        ),
      ],
    );
  }

  Widget _buildShopDiscoveryInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'キーワードやジャンルから、売れ筋商品を扱うショップを探せます。',
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
        Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: const Text(
              '詳細条件を開く',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('除外ワード・評価条件・表示件数'),
            children: [
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
                        hintText: '20',
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
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _showComingSoon(context, 'ショップ発掘'),
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text(
              'ショップを発掘する',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureは次ステップで有効化します')),
    );
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

  Widget _buildResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
  ) {
    if (_mode != _RakutenSearchMode.product) {
      return _modePlaceholder();
    }
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return _centerText('商品名やキーワードを入力して検索してください');
      case RakutenSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RakutenSearchStatus.error:
        return _centerText(
          '検索に失敗しました。\n${search.errorMessage}',
          isError: true,
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return _centerText('検索結果は0件でした');
        }
        final filteredResults = _applyLocalStatusFilters(search.results, managed);
        final selectableCount =
            filteredResults.where((e) => _isSelectableForBulk(e, managed)).length;
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
                '表示 ${filteredResults.length} / 全${search.results.length}件',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            Expanded(
              child: filteredResults.isEmpty
                  ? _centerText(
                      '除外フィルタ条件に一致するため、表示できる商品がありません。\n'
                      'フィルタをOFFにすると表示されます。',
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
  product('商品検索', Icons.shopping_bag_outlined, '商品名・キーワードから商品を探します'),
  genre('ジャンル検索', Icons.category_outlined, 'ジャンル名から商品を探します（UI先行）'),
  shopDiscovery('ショップ発掘', Icons.storefront_outlined, '条件から有望なショップ候補を探します（UI先行）');

  const _RakutenSearchMode(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class _ModeSegmentedChips extends StatelessWidget {
  const _ModeSegmentedChips({
    required this.currentMode,
    required this.onChanged,
  });

  final _RakutenSearchMode currentMode;
  final ValueChanged<_RakutenSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _RakutenSearchMode.values.map((mode) {
        final selected = currentMode == mode;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onChanged(mode),
          avatar: Icon(
            mode.icon,
            size: 18,
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
          ),
          label: Text(
            mode.label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textOnAccent : AppColors.textPrimary,
            ),
          ),
          selectedColor: AppColors.accentPrimary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: selected
                ? AppColors.accentPrimary
                : AppColors.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          ),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        );
      }).toList(),
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
