import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/shop_discovery_summary.dart';
import '../navigation/app_route_observer.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/shop_discovery_aggregator.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../utils/rakuten_keyword_search_sort.dart';
import '../validation/rakuten_keyword_detail_conditions_validation.dart';
import '../widgets/rakuten_search_condition_fields.dart';
import '../widgets/rakuten_search_feedback.dart';
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
    with RouteAware {
  _RakutenSearchMode _mode = _RakutenSearchMode.product;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _excludeKeywordController =
      TextEditingController();
  final TextEditingController _minReviewCountController =
      TextEditingController();
  final TextEditingController _minReviewAverageController =
      TextEditingController();
  final TextEditingController _minCommentCountController =
      TextEditingController();
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
  bool _selectionMode = false;
  bool _isBulkRegistering = false;
  final Set<String> _selectedProductIds = <String>{};
  bool _routeSubscribed = false;
  _GenreSort _genreSort = _GenreSort.reviewCount;
  RakutenKeywordSearchSortMode _keywordSort =
      RakutenKeywordSearchSortMode.defaultOrder;
  final ScrollController _keywordResultsScrollController = ScrollController();
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
    _selectionMode = false;
    _isBulkRegistering = false;
    _selectedProductIds.clear();
    _mode = _RakutenSearchMode.product;
    _genreSort = _GenreSort.reviewCount;
    _keywordSort = RakutenKeywordSearchSortMode.defaultOrder;
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
    _keywordResultsScrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _resetSearchUi();
  }

  /// キーワード検索タブ: フォーカスを外してキーボードを閉じる。
  void _dismissKeywordSearchKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      appBar: AppBar(
        title: const Text('楽天検索'),
        backgroundColor: HomeScreenColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: HomeScreenColors.titlePrimary,
      ),
      body: SafeArea(
        child:
            Consumer3<
              RakutenSearchProvider,
              RakutenManagedProductProvider,
              SavedShopProvider
            >(
              builder: (context, search, managed, saved, _) {
                return Column(
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      flex: 0,
                      child: ListView(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [_buildModeAndInputArea(context, search)],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: HomeScreenColors.inlineDivider,
                    ),
                    Expanded(
                      child: _mode == _RakutenSearchMode.product
                          ? GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _dismissKeywordSearchKeyboard,
                              child: ColoredBox(
                                color: HomeScreenColors.canvas,
                                child: _buildResultArea(
                                  context,
                                  search,
                                  managed,
                                  saved,
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: HomeScreenColors.canvas,
                              child: _buildResultArea(
                                context,
                                search,
                                managed,
                                saved,
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

  String? _validateKeywordSearchInputs() {
    return RakutenKeywordDetailConditionsValidation.validateKeywordSearchBeforeRun(
      keywordText: _keywordController.text,
      minPriceText: _minPriceController.text,
      maxPriceText: _maxPriceController.text,
      minReviewCountText: _minReviewCountController.text,
      minReviewAverageText: _minReviewAverageController.text,
      minCommentCountText: _minCommentCountController.text,
    );
  }

  /// ジャンル検索：詳細条件フィールドのみ検証（キーワード主入力は別）。
  String? _validateGenreDetailInputs() {
    return RakutenKeywordDetailConditionsValidation.validateAll(
      minPriceText: _minPriceController.text,
      maxPriceText: _maxPriceController.text,
      minReviewCountText: _minReviewCountController.text,
      minReviewAverageText: _minReviewAverageController.text,
      minCommentCountText: _minCommentCountController.text,
    );
  }

  /// 詳細条件シートの「この条件で検索」から。検証→閉じる→メインで検索。
  void _submitKeywordSearchFromDetailSheet(
    BuildContext screenContext,
    BuildContext sheetContext,
  ) {
    final err = _validateKeywordSearchInputs();
    if (err != null) {
      ScaffoldMessenger.of(
        sheetContext,
      ).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(sheetContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runSearch(screenContext);
    });
  }

  void _runSearch(BuildContext context) {
    _dismissKeywordSearchKeyboard();
    final detailError = _validateKeywordSearchInputs();
    if (detailError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detailError)));
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedProductIds.clear();
      _keywordSort = RakutenKeywordSearchSortMode.defaultOrder;
    });
    final condition = _buildProductCondition(context);
    final excludeIds = context
        .read<RakutenManagedProductProvider>()
        .productIdsExcludedFromKeywordSearch();
    final savedShopCodes = context
        .read<SavedShopProvider>()
        .shops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    context.read<RakutenSearchProvider>().searchWithCondition(
      condition,
      excludeRegisteredProductIds: excludeIds,
      excludeSavedShopCodes: savedShopCodes,
    );
  }

  RakutenProductSearchCondition _buildProductCondition(BuildContext context) {
    return RakutenProductSearchCondition(
      keyword: _keywordController.text,
      minPrice: _parseInt(_minPriceController.text),
      maxPrice: _parseInt(_maxPriceController.text),
      excludeKeyword: _excludeKeywordController.text,
      minReviewCount: _parseInt(_minReviewCountController.text),
      minReviewAverage: _parseDouble(_minReviewAverageController.text),
      minCommentCount: _parseInt(_minCommentCountController.text),
      shopCode: _effectiveShopCodeForApi(context),
      genreId: _selectedGenreId,
    ).normalized();
  }

  /// 保存済ショップに存在する [shopId] だけを API の shopCode として渡す。
  String? _effectiveShopCodeForApi(BuildContext context) {
    final code = _selectedShopCode?.trim();
    if (code == null || code.isEmpty) return null;
    if (!context.mounted) return null;
    final shops = _sanitizedSavedShopsForSearch(
      context.read<SavedShopProvider>().shops,
    );
    for (final s in shops) {
      if (s.shopId == code) return code;
    }
    return null;
  }

  /// 詳細条件シートを開く前に、保存から消えたショップの選択を外す。
  void _syncSelectedShopWithSaved(BuildContext context) {
    final code = _selectedShopCode?.trim();
    if (code == null || code.isEmpty) return;
    final shops = _sanitizedSavedShopsForSearch(
      context.read<SavedShopProvider>().shops,
    );
    if (shops.isEmpty || !shops.any((s) => s.shopId == code)) {
      setState(() => _selectedShopCode = null);
    }
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
    final deckTopPad = _mode == _RakutenSearchMode.product
        ? 5.0
        : RakutenSearchScreenUi.gapSection;
    final deckBottomPad = _mode == _RakutenSearchMode.product
        ? 4.0
        : RakutenSearchScreenUi.gapFieldStack;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.screenPadH,
        deckTopPad,
        RakutenSearchScreenUi.screenPadH,
        deckBottomPad,
      ),
      child: DecoratedBox(
        decoration: RakutenSearchScreenUi.outerSectionShellDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            RakutenSearchScreenUi.radiusSectionOuter,
          ),
          clipBehavior: Clip.antiAlias,
          child: ColoredBox(
            color: HomeScreenColors.roomContentWellFill,
            child: Padding(
              padding: const EdgeInsets.all(
                RakutenSearchScreenUi.inputDeckPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mode == _RakutenSearchMode.shopDiscovery)
                    const _DiscoveryFlowGuideCompact(),
                  _SearchModeSegmented(
                    mode: _mode,
                    compact: _mode == _RakutenSearchMode.product,
                    onChanged: _onModeChanged,
                  ),
                  SizedBox(
                    height: _mode == _RakutenSearchMode.product
                        ? 6.0
                        : RakutenSearchScreenUi.gapKeywordToControls,
                  ),
                  switch (_mode) {
                    _RakutenSearchMode.product => _buildProductInput(
                      context,
                      search,
                    ),
                    _RakutenSearchMode.genre => _buildGenreInput(
                      context,
                      search,
                    ),
                    _RakutenSearchMode.shopDiscovery =>
                      _buildShopDiscoveryInput(context, search),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInput(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    final loading = search.status == RakutenSearchStatus.loading;
    final kwEmpty = _keywordController.text.trim().isEmpty;
    final canSearch = !loading && !kwEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _keywordController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  if (canSearch) _runSearch(context);
                },
                onChanged: (_) => setState(() {}),
                onTapOutside: (_) => _dismissKeywordSearchKeyboard(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.22,
                  color: HomeScreenColors.titlePrimary,
                ),
                decoration: RakutenSearchScreenUi.searchField(
                  labelText: '検索キーワード（必須）',
                  hintText: '例: ワイヤレスイヤホン',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: HomeScreenColors.leadOnSection,
                  ),
                ),
              ),
            ),
            SizedBox(width: RakutenSearchScreenUi.gapFieldStack + 2),
            Semantics(
              button: true,
              label: 'キーワードで検索',
              child: FilledButton.icon(
                onPressed: canSearch ? () => _runSearch(context) : null,
                icon: const Icon(Icons.search_rounded, size: 22),
                label: const Text(
                  '検索',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: AppColors.textOnAccent,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  elevation: 1,
                  shadowColor: AppColors.textPrimary.withValues(alpha: 0.18),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: RakutenSearchScreenUi.gapKeywordToControls),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openProductConditionsSheet(context),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: HomeScreenColors.accentSectionHeading,
                ),
                label: const Text('詳細条件'),
                style: _detailConditionsButtonStyle().copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ),
            SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _dismissKeywordSearchKeyboard();
                  _clearConditionsForCurrentMode();
                },
                icon: Icon(
                  Icons.restart_alt_rounded,
                  size: 17,
                  color: HomeScreenColors.groupedSectionBody,
                ),
                label: const Text('条件クリア'),
                style: _neutralConditionsButtonStyle().copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenreInput(BuildContext context, RakutenSearchProvider search) {
    final loading = search.status == RakutenSearchStatus.loading;
    final genreOk =
        _selectedGenreId != null && _selectedGenreId!.trim().isNotEmpty;
    final canSearch = !loading && genreOk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RakutenSearchGenreDropdownField(
          labelText: 'ジャンルを選択（必須）',
          value: _selectedGenreId,
          options: _mockGenres,
          onChanged: (value) => setState(() => _selectedGenreId = value),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        TextField(
          controller: _genreController,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.22,
            color: HomeScreenColors.titlePrimary,
          ),
          decoration: RakutenSearchScreenUi.searchField(
            labelText: '補助キーワード（任意）',
            hintText: '例: 収納 ボックス',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: HomeScreenColors.leadOnSection,
            ),
          ),
          onSubmitted: (_) {
            if (canSearch) _runGenreSearch(context);
          },
        ),
        SizedBox(height: RakutenSearchScreenUi.gapKeywordToControls),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openProductConditionsSheet(context),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: HomeScreenColors.accentSectionHeading,
                ),
                label: const Text('詳細条件'),
                style: _detailConditionsButtonStyle().copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ),
            SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearConditionsForCurrentMode,
                icon: Icon(
                  Icons.restart_alt_rounded,
                  size: 17,
                  color: HomeScreenColors.groupedSectionBody,
                ),
                label: const Text('条件クリア'),
                style: _neutralConditionsButtonStyle().copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        Semantics(
          button: true,
          label: 'ジャンルで検索',
          child: FilledButton.icon(
            onPressed: canSearch ? () => _runGenreSearch(context) : null,
            icon: const Icon(Icons.search_rounded, size: 22),
            label: const Text(
              '検索',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 1,
              shadowColor: AppColors.textPrimary.withValues(alpha: 0.18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShopDiscoveryInput(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    final savedCount = context.watch<SavedShopProvider>().shops.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _shopDiscoveryKeywordController,
          textInputAction: TextInputAction.next,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.22,
            color: HomeScreenColors.titlePrimary,
          ),
          decoration: RakutenSearchScreenUi.searchField(
            labelText: 'キーワード',
            hintText: '例: おしゃれ 家具',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: HomeScreenColors.leadOnSection,
            ),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        InputDecorator(
          decoration: RakutenSearchScreenUi.searchField(
            labelText: 'ジャンル',
            prefixIcon: Icon(
              Icons.category_outlined,
              color: HomeScreenColors.leadOnSection,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedDiscoveryGenreId,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HomeScreenColors.titlePrimary,
              ),
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
        SizedBox(height: RakutenSearchScreenUi.gapKeywordToControls),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openShopDiscoveryConditionsSheet(context),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: HomeScreenColors.accentSectionHeading,
                ),
                label: const Text('発掘条件'),
                style: _detailConditionsButtonStyle(),
              ),
            ),
            SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
            Expanded(
              child: OutlinedButton(
                onPressed: _clearConditionsForCurrentMode,
                style: _neutralConditionsButtonStyle(),
                child: const Text('条件クリア'),
              ),
            ),
          ],
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: search.status == RakutenSearchStatus.loading
                ? null
                : () => _runShopDiscovery(context),
            style: FilledButton.styleFrom(
              backgroundColor: HomeScreenColors.heroCtaBackground,
              foregroundColor: AppColors.textOnAccent,
              elevation: 0,
            ),
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text(
              'ショップを発掘する',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SavedShopsScreen()),
            );
          },
          icon: Icon(
            Icons.bookmarks_outlined,
            size: 17,
            color: HomeScreenColors.leadOnSection,
          ),
          label: Text('保存ショップを見る（$savedCount件）'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeScreenColors.leadOnSection,
            backgroundColor: Color.alphaBlend(
              HomeScreenColors.subActionRowFill.withValues(alpha: 0.55),
              HomeScreenColors.deckFill,
            ),
            side: BorderSide(color: HomeScreenColors.inlineDivider),
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _onModeChanged(_RakutenSearchMode next) {
    if (_mode == next) return;
    if (_mode == _RakutenSearchMode.product) {
      _dismissKeywordSearchKeyboard();
    }
    setState(() => _mode = next);
    context.read<RakutenSearchProvider>().resetTransientState();
  }

  /// キーワード・発掘の主入力は残し、シート側の付加条件だけリセットする。
  void _clearConditionsForCurrentMode() {
    setState(() {
      _minPriceController.clear();
      _maxPriceController.clear();
      _excludeKeywordController.clear();
      _minReviewCountController.clear();
      _minReviewAverageController.clear();
      _minCommentCountController.clear();
      _selectedShopCode = null;
      if (_mode == _RakutenSearchMode.product) {
        _selectedGenreId = null;
      }
      if (_mode == _RakutenSearchMode.genre) {
        _genreController.clear();
      }
      if (_mode == _RakutenSearchMode.shopDiscovery) {
        _shopDiscoveryExcludeController.clear();
        _shopDiscoveryMinReviewCountController.clear();
        _shopDiscoveryMinReviewAverageController.clear();
        _shopDiscoveryShopLimitController.text = '10';
        _shopDiscoveryItemsPerShopController.text = '5';
      }
    });
  }

  /// キーワード検索の主キーワードは残し、詳細条件（シート内の項目）だけを初期化する。
  void _clearKeywordDetailConditionsOnly() {
    setState(() {
      _minPriceController.clear();
      _maxPriceController.clear();
      _excludeKeywordController.clear();
      _minReviewCountController.clear();
      _minReviewAverageController.clear();
      _minCommentCountController.clear();
      _selectedShopCode = null;
      _selectedGenreId = null;
    });
  }

  /// 詳細条件シート（キーワードタブ）の最低評価数プルダウン用。不正な文字列は未選択扱い。
  int? _keywordSheetSelectedReviewCount() {
    final t = _minReviewCountController.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null) return null;
    return RakutenKeywordDetailConditionsValidation.keywordMinReviewCountChoices
            .contains(v)
        ? v
        : null;
  }

  /// 詳細条件シート（キーワードタブ）の最低評価点数プルダウン用。
  double? _keywordSheetSelectedReviewAverage() {
    final t = _minReviewAverageController.text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    for (final a
        in RakutenKeywordDetailConditionsValidation
            .keywordMinReviewAverageChoices) {
      if ((v - a).abs() < 0.001) return a;
    }
    return null;
  }

  ButtonStyle _detailConditionsButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.accentSectionHeading,
      backgroundColor: Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.2),
        HomeScreenColors.deckFill,
      ),
      side: BorderSide(color: HomeScreenColors.sectionOutlineAccent),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }

  ButtonStyle _neutralConditionsButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.groupedSectionBody,
      backgroundColor: HomeScreenColors.deckFill,
      side: BorderSide(color: HomeScreenColors.deckOutline),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }

  /// キーワード詳細シート下部の補助操作（閉じる／絞り込みリセット）。主CTAより弱く、輪郭で押せる範囲をはっきりさせる。
  ButtonStyle _keywordDetailSheetAuxiliaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.leadOnSection,
      backgroundColor: HomeScreenColors.deckFill,
      side: BorderSide(color: HomeScreenColors.deckOutline, width: 1),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
        height: 1.2,
      ),
    );
  }

  Future<void> _openProductConditionsSheet(BuildContext screenContext) async {
    if (_mode == _RakutenSearchMode.product) {
      _dismissKeywordSearchKeyboard();
    }
    _syncSelectedShopWithSaved(screenContext);
    await showModalBottomSheet<void>(
      context: screenContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Material(
              color: HomeScreenColors.canvas,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.sheetPadH,
                    8,
                    RakutenSearchScreenUi.sheetPadH,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _mode == _RakutenSearchMode.product
                              ? 'キーワード検索の詳細条件'
                              : 'ジャンル検索の詳細条件',
                          style: RakutenSearchScreenUi.sectionHeadingAccent(
                            context,
                          ),
                        ),
                        if (_mode == _RakutenSearchMode.genre) ...[
                          const SizedBox(height: 8),
                          Text(
                            '価格・評価・ショップなどを調整します。結果はメイン画面の「検索」で表示します。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: HomeScreenColors.groupedSectionBody,
                                  height: 1.4,
                                ),
                          ),
                          SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                        ] else
                          const SizedBox(height: 10),
                        if (_mode == _RakutenSearchMode.product) ...[
                          TextField(
                            controller: _keywordController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) =>
                                _submitKeywordSearchFromDetailSheet(
                                  screenContext,
                                  sheetContext,
                                ),
                            onChanged: (_) => setModalState(() {}),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 14,
                                  height: 1.22,
                                  color: HomeScreenColors.titlePrimary,
                                ),
                            decoration: RakutenSearchScreenUi.searchField(
                              labelText: '検索キーワード（必須）',
                              hintText: '例: ステンレス ボトル',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: HomeScreenColors.leadOnSection,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(
                          height: RakutenSearchScreenUi.gapKeywordToControls,
                        ),
                        RakutenSearchPriceRangeRow(
                          minPriceController: _minPriceController,
                          maxPriceController: _maxPriceController,
                          digitsOnlyFormatters:
                              RakutenKeywordDetailConditionsInput
                                  .digitsOnlyField,
                        ),
                        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                        TextField(
                          controller: _excludeKeywordController,
                          onChanged: (_) => setModalState(() {}),
                          decoration: RakutenSearchScreenUi.searchField(
                            labelText: '除外ワード（任意）',
                            hintText: '中古 訳あり',
                            prefixIcon: Icon(
                              Icons.block_outlined,
                              color: HomeScreenColors.leadOnSection,
                            ),
                          ),
                        ),
                        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                        RakutenSearchMinReviewDropdownRow(
                          selectedReviewCount:
                              _keywordSheetSelectedReviewCount(),
                          selectedReviewAverage:
                              _keywordSheetSelectedReviewAverage(),
                          onReviewCountChanged: (v) {
                            setState(() {
                              _minReviewCountController.text = v == null
                                  ? ''
                                  : '$v';
                            });
                            setModalState(() {});
                          },
                          onReviewAverageChanged: (v) {
                            setState(() {
                              _minReviewAverageController.text = v == null
                                  ? ''
                                  : v.toStringAsFixed(1);
                            });
                            setModalState(() {});
                          },
                        ),
                        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                        TextField(
                          controller: _minCommentCountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          inputFormatters: RakutenKeywordDetailConditionsInput
                              .digitsOnlyField,
                          onChanged: (_) => setModalState(() {}),
                          decoration: RakutenSearchScreenUi.searchField(
                            labelText: '最低コメント数（任意）',
                            hintText: '30',
                            prefixIcon: Icon(
                              Icons.comment_outlined,
                              color: HomeScreenColors.leadOnSection,
                            ),
                          ),
                        ),
                        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                        Consumer<SavedShopProvider>(
                          builder: (context, savedProv, _) {
                            final shops = _sanitizedSavedShopsForSearch(
                              savedProv.shops,
                            );
                            return RakutenSearchSavedShopPicker(
                              shops: shops,
                              selectedShopCode: _selectedShopCode,
                              onShopChanged: (value) {
                                setState(() => _selectedShopCode = value);
                                setModalState(() {});
                              },
                              onNavigateToSavedShops: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.of(sheetContext).pop();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!screenContext.mounted) return;
                                  Navigator.of(screenContext).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SavedShopsScreen(),
                                    ),
                                  );
                                });
                              },
                            );
                          },
                        ),
                        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                        RakutenSearchGenreDropdownField(
                          labelText: _mode == _RakutenSearchMode.product
                              ? 'ジャンル（任意）'
                              : 'ジャンル（必須）',
                          value: _selectedGenreId,
                          options: _mockGenres,
                          onChanged: (value) {
                            setState(() => _selectedGenreId = value);
                            setModalState(() {});
                          },
                        ),
                        SizedBox(
                          height: RakutenSearchScreenUi.gapKeywordToControls,
                        ),
                        if (_mode == _RakutenSearchMode.product) ...[
                          Consumer<RakutenSearchProvider>(
                            builder: (context, search, _) {
                              final loading =
                                  search.status == RakutenSearchStatus.loading;
                              final kwOk = _keywordController.text
                                  .trim()
                                  .isNotEmpty;
                              final canSearch = !loading && kwOk;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: !canSearch
                                        ? null
                                        : () =>
                                              _submitKeywordSearchFromDetailSheet(
                                                screenContext,
                                                sheetContext,
                                              ),
                                    icon: const Icon(
                                      Icons.search_rounded,
                                      size: 22,
                                    ),
                                    label: const Text(
                                      'この条件で検索',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accentPrimary,
                                      foregroundColor: AppColors.textOnAccent,
                                      minimumSize: const Size(0, 50),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            Navigator.of(sheetContext).pop();
                                          },
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 20,
                                            color:
                                                HomeScreenColors.leadOnSection,
                                          ),
                                          label: const Text('閉じる'),
                                          style:
                                              _keywordDetailSheetAuxiliaryButtonStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            _clearKeywordDetailConditionsOnly();
                                            setModalState(() {});
                                          },
                                          icon: Icon(
                                            Icons.filter_alt_off_outlined,
                                            size: 20,
                                            color:
                                                HomeScreenColors.leadOnSection,
                                          ),
                                          label: const Text(
                                            '絞り込みだけリセット',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          style:
                                              _keywordDetailSheetAuxiliaryButtonStyle(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ] else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.of(sheetContext).pop();
                                },
                                icon: Icon(
                                  Icons.check_rounded,
                                  color: HomeScreenColors.leadOnSection,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      HomeScreenColors.leadOnSection,
                                  side: BorderSide(
                                    color: HomeScreenColors.deckOutline,
                                  ),
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                label: const Text('完了して閉じる'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
        return Material(
          color: HomeScreenColors.canvas,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.sheetPadH,
                8,
                RakutenSearchScreenUi.sheetPadH,
                MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ショップ発掘の詳細条件',
                      style: RakutenSearchScreenUi.sectionHeadingAccent(
                        context,
                      ),
                    ),
                    SizedBox(
                      height: RakutenSearchScreenUi.gapKeywordToControls,
                    ),
                    TextField(
                      controller: _shopDiscoveryExcludeController,
                      decoration: RakutenSearchScreenUi.searchField(
                        labelText: '除外ワード',
                        hintText: '例: 中古 訳あり',
                        prefixIcon: Icon(
                          Icons.block_outlined,
                          color: HomeScreenColors.leadOnSection,
                        ),
                      ),
                    ),
                    SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _shopDiscoveryMinReviewCountController,
                            keyboardType: TextInputType.number,
                            decoration: RakutenSearchScreenUi.searchField(
                              labelText: '最低評価数',
                              hintText: '100',
                              prefixIcon: Icon(
                                Icons.reviews_outlined,
                                color: HomeScreenColors.leadOnSection,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
                        Expanded(
                          child: TextField(
                            controller:
                                _shopDiscoveryMinReviewAverageController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: RakutenSearchScreenUi.searchField(
                              labelText: '最低評価点',
                              hintText: '4.2',
                              prefixIcon: Icon(
                                Icons.star_outline_rounded,
                                color: HomeScreenColors.leadOnSection,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _shopDiscoveryShopLimitController,
                            keyboardType: TextInputType.number,
                            decoration: RakutenSearchScreenUi.searchField(
                              labelText: '表示ショップ数',
                              hintText: '10',
                              prefixIcon: Icon(
                                Icons.store_mall_directory_outlined,
                                color: HomeScreenColors.leadOnSection,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
                        Expanded(
                          child: TextField(
                            controller: _shopDiscoveryItemsPerShopController,
                            keyboardType: TextInputType.number,
                            decoration: RakutenSearchScreenUi.searchField(
                              labelText: '1ショップあたり表示商品数',
                              hintText: '5',
                              prefixIcon: Icon(
                                Icons.view_stream_outlined,
                                color: HomeScreenColors.leadOnSection,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: RakutenSearchScreenUi.gapKeywordToControls,
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: AppColors.textOnAccent,
                      ),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('キーワードまたはジャンルを指定してください')));
      return;
    }
    final fallbackKeyword = _labelForGenre(genreId) ?? '楽天';
    final condition = RakutenProductSearchCondition(
      keyword: keyword.isNotEmpty ? keyword : fallbackKeyword,
      excludeKeyword: _shopDiscoveryExcludeController.text,
      minReviewCount: _parseInt(_shopDiscoveryMinReviewCountController.text),
      minReviewAverage: _parseDouble(
        _shopDiscoveryMinReviewAverageController.text,
      ),
      genreId: genreId,
    ).normalized();
    context.read<RakutenSearchProvider>().searchWithCondition(condition);
  }

  String? _labelForGenre(String? id) {
    if (id == null) return null;
    return RakutenGenreMasterService.instance.genreNameIfKnown(id);
  }

  Future<void> _runGenreSearch(BuildContext context) async {
    if (_selectedGenreId == null || _selectedGenreId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ジャンルを選択してください')));
      return;
    }
    final detailErr = _validateGenreDetailInputs();
    if (detailErr != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detailErr)));
      return;
    }
    final condition = RakutenProductSearchCondition(
      keyword: _genreController.text,
      minPrice: _parseInt(_minPriceController.text),
      maxPrice: _parseInt(_maxPriceController.text),
      excludeKeyword: _excludeKeywordController.text,
      minReviewCount: _parseInt(_minReviewCountController.text),
      minReviewAverage: _parseDouble(_minReviewAverageController.text),
      minCommentCount: _parseInt(_minCommentCountController.text),
      shopCode: _effectiveShopCodeForApi(context),
      genreId: _selectedGenreId,
    ).normalized();
    if (kDebugMode) {
      debugPrint(
        '[Rakuten] genreSearch request start genreId=${condition.genreId} '
        'keywordLen=${condition.keyword.length}',
      );
    }
    await context.read<RakutenSearchProvider>().searchWithCondition(condition);
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
          item.shopCode.trim().isNotEmpty &&
          saved.isSaved(item.shopCode.trim());
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
      return '候補に登録済のため選択不可';
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

  String _keywordSortModeLabel(RakutenKeywordSearchSortMode mode) {
    switch (mode) {
      case RakutenKeywordSearchSortMode.defaultOrder:
        return 'デフォルト';
      case RakutenKeywordSearchSortMode.priceAscending:
        return '価格順';
      case RakutenKeywordSearchSortMode.ratingDescending:
        return '評価順';
      case RakutenKeywordSearchSortMode.reviewCountDescending:
        return '件数順';
    }
  }

  Widget _buildKeywordResultSortControl(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '並び順',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: HomeScreenColors.footnoteMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Theme(
          data: Theme.of(
            context,
          ).copyWith(visualDensity: VisualDensity.compact),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<RakutenKeywordSearchSortMode>(
              value: _keywordSort,
              isDense: true,
              alignment: AlignmentDirectional.centerEnd,
              icon: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: HomeScreenColors.leadOnSection,
              ),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.leadOnSection,
                fontWeight: FontWeight.w700,
              ),
              items: RakutenKeywordSearchSortMode.values.map((mode) {
                return DropdownMenuItem<RakutenKeywordSearchSortMode>(
                  value: mode,
                  child: Text(_keywordSortModeLabel(mode)),
                );
              }).toList(),
              onChanged: (RakutenKeywordSearchSortMode? next) {
                if (next == null || next == _keywordSort) return;
                setState(() => _keywordSort = next);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_keywordResultsScrollController.hasClients) {
                    _keywordResultsScrollController.jumpTo(0);
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
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
        return const RakutenSearchIdleView(
          icon: Icons.manage_search_outlined,
          title: '商品がここに表示されます',
          subtitle: '上のキーワードを入れて「検索」。価格やショップの細かい条件は「詳細条件」から。',
          stateFootnote: '登録済み候補・コレ済は除外します（最大100件まで取得）。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const RakutenSearchLoadingView(
          title: '商品を探しています',
          subtitle: '楽天の商品情報を読み込んでいます。混雑時は30秒ほどかかることがあります。',
          footnote: '除外・複数ページ取得のため、このままお待ちください。',
        );
      case RakutenSearchStatus.error:
        return RakutenSearchErrorView(
          title: '検索結果を表示できませんでした',
          stateLine: '状態: 通信または楽天APIの応答に失敗しました',
          message: search.errorMessage.isNotEmpty
              ? search.errorMessage
              : '時間をおいて「もう一度検索する」を押すか、条件を緩めて試してください。',
          onRetry: () => _runSearch(context),
          onAdjustConditions: () => _openProductConditionsSheet(context),
          adjustLabel: '詳細条件を開く',
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          if (search.keywordSearchHadApiHitsButNoVisibleResults) {
            return RakutenSearchEmptyView(
              icon: Icons.playlist_remove_rounded,
              title: '表示できる新しい候補が見つかりませんでした',
              body:
                  'コレ候補・コレ済に登録済みの商品は検索結果に含めていません。'
                  'この条件では、登録済みを除いたあとに残る商品がありませんでした（複数ページまで取得済みです）。',
              hints: const [
                'キーワードや詳細条件を変えてみる',
                '登録済みが多いと、同じ条件では新しい候補は出にくくなります',
              ],
              onRefine: () => _openProductConditionsSheet(context),
              refineLabel: '詳細条件を調整',
              stateFootnote: '楽天側に商品があっても、候補・コレ済を除くと0件になることがあります。',
            );
          }
          return RakutenSearchEmptyView(
            icon: Icons.inventory_2_outlined,
            title: '条件に合う商品は見つかりませんでした',
            body: '楽天側に該当がないか、除外ワードや価格・評価の下限などが厳しすぎている可能性があります。',
            hints: const [
              'キーワードの言い回しを変えてみる',
              '詳細条件の下限（評価数・価格など）を緩める',
              '除外ワードを減らす、または空にする',
            ],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: '詳細条件を調整',
            stateFootnote: '読み込みは完了していますが、この条件では0件です。',
          );
        }
        final managedPreferred = _applyPreferredExcludes(
          search.results,
          managed,
          saved,
        );
        // キーワードタブ: API 側で候補・コレ済・保存ショップを除いて最大100件まで集約済み。
        // ここでは一覧表示の一貫性のため同条件で再フィルタし、
        // その結果が空でも登録済み商品を一覧に戻さない（新しい候補探索の体験を優先）。
        final base = _mode == _RakutenSearchMode.product
            ? managedPreferred
            : (managedPreferred.isNotEmpty ? managedPreferred : search.results);
        final filteredResults = base;
        final orderedResults = sortedRakutenKeywordSearchItems(
          filteredResults,
          _keywordSort,
        );
        final keywordPreferredFilteredAllOut =
            _mode == _RakutenSearchMode.product &&
            managedPreferred.isEmpty &&
            search.results.isNotEmpty;
        final selectableCount = orderedResults
            .where((e) => _isSelectableForBulk(e, managed))
            .length;
        final totalCount = search.results.length;
        final showingCount = filteredResults.length;
        final kwMeta = search.keywordManagedFetchSummary;
        final shortfallNote = search.keywordManagedVisibleShortfallNote();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                2,
                RakutenSearchScreenUi.screenPadH,
                RakutenSearchScreenUi.gapResultStatusRowBottom,
              ),
              child: DecoratedBox(
                decoration: RakutenSearchScreenUi.listFilterStripDecoration(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 17,
                        color: HomeScreenColors.statusAccentStrong,
                      ),
                      SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                      Expanded(
                        child: Text(
                          '検索が完了しました（一覧 $showingCount件）',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomeScreenColors.leadOnSection,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (_mode == _RakutenSearchMode.product) ...[
                        SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _buildKeywordResultSortControl(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                0,
                RakutenSearchScreenUi.screenPadH,
                4,
              ),
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
                  SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                  if (_selectionMode)
                    Expanded(
                      child: Text(
                        '選択中 ${_selectedProductIds.length}件 / 選択可能 $selectableCount件',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HomeScreenColors.groupedSectionBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_selectionMode) ...[
                    SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                    TextButton(
                      onPressed: orderedResults.isEmpty || _isBulkRegistering
                          ? null
                          : () => _selectAllForBulk(orderedResults, managed),
                      child: const Text('全部選択'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed:
                          _selectedProductIds.isEmpty || _isBulkRegistering
                          ? null
                          : _clearBulkSelection,
                      child: const Text('全部解除'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                0,
                RakutenSearchScreenUi.screenPadH,
                6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kwMeta != null
                        ? '一覧は $showingCount件です（コレ候補・コレ済・保存ショップを除き、最大${kwMeta.targetVisibleCap}件までAPIから集めた結果）。'
                        : (totalCount == showingCount
                              ? '一覧 $showingCount件です。'
                              : '一覧 $showingCount件です（全体 $totalCount件から表示用に除外）。'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: HomeScreenColors.footnoteMuted,
                    ),
                  ),
                  if (shortfallNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      shortfallNote,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: HomeScreenColors.leadOnSection,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '※ コレ候補・コレ済・保存ショップの商品はこの一覧に含めません。',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: HomeScreenColors.footnoteMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orderedResults.isEmpty
                  ? keywordPreferredFilteredAllOut
                        ? RakutenSearchEmptyView(
                            icon: Icons.store_mall_directory_outlined,
                            title: 'この条件では一覧を表示できませんでした',
                            body:
                                'ヒットはありましたが、保存ショップ登録済みの店の商品だけでした。'
                                'キーワード検索ではそのままでは一覧に出さないようにしています。',
                            hints: const [
                              'キーワードや詳細条件を変えて、別のショップの商品を探す',
                              'ジャンル検索など別の切り口も試せます',
                            ],
                            onRefine: () =>
                                _openProductConditionsSheet(context),
                            refineLabel: '詳細条件を開く',
                            stateFootnote: 'コレ候補・コレ済以外の商品は、すでに結果に含めています。',
                          )
                        : RakutenSearchEmptyView(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'この一覧では表示できる商品がありません',
                            body:
                                '検索の取得はできていますが、保存ショップ登録済みの店の商品のみヒットしたなど、表示上の理由で0件になっている可能性があります。',
                            hints: const [
                              'キーワードや詳細条件を変えて、もう一度検索する',
                              'ジャンル検索に切り替えて別の切り口を試す',
                            ],
                            onRefine: () =>
                                _openProductConditionsSheet(context),
                            refineLabel: '詳細条件を開く',
                            stateFootnote: 'データ取得は完了しています。条件を変えて試せます。',
                          )
                  : ListView.separated(
                      controller: _keywordResultsScrollController,
                      padding: EdgeInsets.fromLTRB(
                        RakutenSearchScreenUi.screenPadH,
                        RakutenSearchScreenUi.listScrollTopPad,
                        RakutenSearchScreenUi.screenPadH,
                        _selectionMode
                            ? RakutenSearchScreenUi
                                  .listBottomPadWithSelectionBar
                            : RakutenSearchScreenUi.listBottomPad + 6,
                      ),
                      itemCount: orderedResults.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: RakutenSearchScreenUi.listCardGap),
                      itemBuilder: (context, index) {
                        final item = orderedResults[index];
                        final isSelectable = _isSelectableForBulk(
                          item,
                          managed,
                        );
                        return RakutenSearchResultCard(
                          item: item,
                          localStatus: managed.statusForProduct(item.productId),
                          isRegistering: managed.isRegistering(item.productId),
                          selectionMode: _selectionMode,
                          isSelected: _selectedProductIds.contains(
                            item.productId,
                          ),
                          isSelectionEnabled:
                              isSelectable && !_isBulkRegistering,
                          selectionDisabledLabel: _selectionDisabledReason(
                            item,
                            managed,
                          ),
                          onToggleSelected: () {
                            if (!isSelectable || _isBulkRegistering) return;
                            setState(() {
                              if (_selectedProductIds.contains(
                                item.productId,
                              )) {
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
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(err)));
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
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapFieldStack,
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapFloatingBarPad,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _selectedProductIds.isEmpty || _isBulkRegistering
                          ? null
                          : () => _bulkRegisterCandidates(
                              managed,
                              orderedResults,
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
        return const RakutenSearchIdleView(
          icon: Icons.category_outlined,
          title: 'ここではまだ結果を表示していません',
          subtitle: 'ジャンルを選び、必要なら補助キーワードを入力してから「検索」を押してください。絞り込みは「詳細条件」から開けます。',
          stateFootnote: '検索が始まるまで、このエリアは更新されません。コレ候補・コレ済登録済みの商品は結果に含みません。',
        );
      case RakutenSearchStatus.loading:
        return const RakutenSearchLoadingView(
          title: 'ジャンルに沿って商品を読み込んでいます',
          subtitle: '楽天の商品情報を読み込んでいます。回線状況によっては30秒ほどかかることがあります。',
          footnote: '最大約100件まで順に取得しています。この画面を閉じずにお待ちください。',
        );
      case RakutenSearchStatus.error:
        return RakutenSearchErrorView(
          title: 'ジャンル検索の結果を表示できませんでした',
          stateLine: '状態: 通信または楽天APIの応答に失敗しました',
          message: search.errorMessage.isNotEmpty
              ? search.errorMessage
              : '時間をおいて「もう一度検索する」を押すか、条件を緩めて試してください。',
          onRetry: () => _runGenreSearch(context),
          onAdjustConditions: () => _openProductConditionsSheet(context),
          adjustLabel: '詳細条件を開く',
        );
      case RakutenSearchStatus.success:
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] genreSearch before render count=${search.results.length}',
          );
        }
        if (search.results.isEmpty) {
          return RakutenSearchEmptyView(
            icon: Icons.category_outlined,
            title: 'このジャンルでは商品は見つかりませんでした',
            body:
                'APIの応答に商品が無かったか、アプリ側の絞り込み後に0件になりました。補助キーワードや詳細条件を緩めて試してください。',
            hints: const [
              '補助キーワードを空にするか、別の言い方に変える',
              '詳細条件の評価数・価格帯を緩める',
              '別のジャンルを選ぶ',
            ],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: '詳細条件を調整',
            stateFootnote: '読み込みは完了していますが、この条件では0件です。',
          );
        }
        final managedPreferred = _applyPreferredExcludes(
          search.results,
          managed,
          context.read<SavedShopProvider>(),
        );
        final base = managedPreferred.isNotEmpty
            ? managedPreferred
            : search.results;
        final filteredResults = base;
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] genreSearch after filter count (preferred excludes)=${filteredResults.length}',
          );
        }
        if (filteredResults.isEmpty) {
          final n = search.results.length;
          return RakutenSearchEmptyView(
            icon: Icons.filter_alt_off_outlined,
            title: 'この一覧では表示できる商品がありません',
            body: n > 0
                ? '楽天からは $n 件取得できましたが、コレ候補・コレ済・保存ショップの除外のため、この一覧では0件です。'
                : '検索の取得はできていますが、表示上の理由で0件になっている可能性があります。',
            hints: const ['詳細条件を緩めて、もう一度検索する', 'モードを「キーワード」に切り替えて別の切り口を試す'],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: '詳細条件を開く',
            stateFootnote: 'データ取得は完了しています。条件の組み合わせを変えてみましょう。',
          );
        }
        final sorted = [...filteredResults];
        if (_genreSort == _GenreSort.reviewCount) {
          sorted.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        } else {
          sorted.sort((a, b) => b.reviewAverage.compareTo(a.reviewAverage));
        }
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] genreSearch itemBuilder count=${sorted.length}',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                RakutenSearchScreenUi.gapListAfterDivider,
                RakutenSearchScreenUi.screenPadH,
                4,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: HomeScreenColors.statusAccentStrong,
                  ),
                  SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                  Expanded(
                    child: Text(
                      '検索が完了しました（${search.results.length}件を取得・表示${sorted.length}件）',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomeScreenColors.leadOnSection,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                0,
                RakutenSearchScreenUi.screenPadH,
                4,
              ),
              child: Text(
                '※ コレ候補・コレ済に登録済みの商品は検索結果に含まれません。',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: HomeScreenColors.footnoteMuted,
                  height: 1.25,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                0,
                RakutenSearchScreenUi.screenPadH,
                RakutenSearchScreenUi.gapFieldStack,
              ),
              child: Row(
                children: [
                  Text(
                    'ジャンル検索結果（${sorted.length}件）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomeScreenColors.titlePrimary,
                      fontWeight: FontWeight.w700,
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
                padding: EdgeInsets.fromLTRB(
                  RakutenSearchScreenUi.screenPadH,
                  RakutenSearchScreenUi.listScrollTopPad,
                  RakutenSearchScreenUi.screenPadH,
                  RakutenSearchScreenUi.listBottomPad +
                      RakutenSearchScreenUi.listScrollExtraPadGenre,
                ),
                itemCount: sorted.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: RakutenSearchScreenUi.listCardGap),
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  if (kDebugMode && index == 0) {
                    debugPrint(
                      '[Rakuten] genreSearch first visible item summary '
                      'id=${item.productId} name=${item.itemName} '
                      'price=${item.itemPrice} genreId=${item.genreId}',
                    );
                  }
                  try {
                    return RakutenSearchResultCard(
                      item: item,
                      localStatus: managed.statusForProduct(item.productId),
                      isRegistering: managed.isRegistering(item.productId),
                      onRegisterCandidate: () async {
                        final err = await managed.registerCandidate(item);
                        if (!context.mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    );
                  } catch (e, st) {
                    if (kDebugMode) {
                      debugPrint(
                        '[Rakuten] genreSearch itemBuilder row failed index=$index: $e',
                      );
                      debugPrint('$st');
                    }
                    return ListTile(
                      title: Text(
                        item.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('表示をスキップ: $e'),
                    );
                  }
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
        return const RakutenSearchIdleView(
          icon: Icons.storefront_outlined,
          title: 'ここではまだ発掘結果を表示していません',
          subtitle:
              'キーワードかジャンルを指定し、「ショップを発掘する」を押すと、商品から有望なショップ候補をまとめます。しきい値は「発掘条件」から調整できます。',
          stateFootnote: '発掘が始まるまで、このエリアは更新されません。',
        );
      case RakutenSearchStatus.loading:
        return const RakutenSearchLoadingView(
          title: 'ショップを発掘しています',
          subtitle: 'まず商品を読み込み、ショップ単位に集計しています。まとまった件数があると、少し時間がかかることがあります。',
          footnote: '取得中はこの画面を開いたままお待ちください。長く応答がないときは回線や楽天側の混雑も考えられます。',
        );
      case RakutenSearchStatus.error:
        return RakutenSearchErrorView(
          title: 'ショップ発掘を完了できませんでした',
          stateLine: '状態: 通信または楽天APIの応答に失敗しました',
          message: search.errorMessage.isNotEmpty
              ? search.errorMessage
              : '時間をおいて「もう一度検索する」を押すか、発掘条件を緩めて試してください。',
          onRetry: () => _runShopDiscovery(context),
          onAdjustConditions: () => _openShopDiscoveryConditionsSheet(context),
          adjustLabel: '発掘条件を開く',
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return RakutenSearchEmptyView(
            icon: Icons.travel_explore_outlined,
            title: '発掘のもとになる商品がありませんでした',
            body: '条件にヒットする商品がないか、除外や評価の下限が厳しすぎる可能性があります。',
            hints: const [
              'キーワードを広げる、または別のジャンルも試す',
              '発掘条件の評価数・評価点を緩める',
              '除外ワードを減らす',
            ],
            onRefine: () => _openShopDiscoveryConditionsSheet(context),
            refineLabel: '発掘条件を調整',
            stateFootnote: '読み込みは完了していますが、この条件では0件です。',
          );
        }
        final shopLimit =
            _parseInt(_shopDiscoveryShopLimitController.text) ?? 10;
        final itemsPerShop =
            _parseInt(_shopDiscoveryItemsPerShopController.text) ?? 5;
        final summaries = ShopDiscoveryAggregator.aggregate(
          search.results,
          shopLimit: shopLimit,
          itemsPerShop: itemsPerShop,
        );
        if (summaries.isEmpty) {
          return RakutenSearchEmptyView(
            icon: Icons.groups_outlined,
            title: 'ショップ候補を組み立てられませんでした',
            body: '商品の取得はできていますが、ショップ単位の集計結果が空でした。条件を変えるか、しばらくしてからもう一度試せます。',
            hints: const ['発掘条件を緩めて再実行する', 'キーワードやジャンルを変えて商品数を増やす'],
            onRefine: () => _openShopDiscoveryConditionsSheet(context),
            refineLabel: '発掘条件を開く',
            stateFootnote: '読み込みは完了していますが、表示できるショップは0件です。',
          );
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
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapListAfterDivider,
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapDiscoveryStatusRowBottom,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: HomeScreenColors.statusAccentStrong,
                      ),
                      SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                      Expanded(
                        child: Text(
                          '商品の取得が完了しました（${search.results.length}件からショップを集計）',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomeScreenColors.leadOnSection,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.screenPadH,
                    0,
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapFieldStack,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: HomeScreenColors.roomMetricTileFill,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      border: Border.all(
                        color: HomeScreenColors.roomMetricTileBorder,
                      ),
                      boxShadow: HomeScreenColors.roomMetricTileShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '発掘結果 ${visible.length}ショップ（スコア順）',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomeScreenColors.metricTileTitleColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '売れ筋度は「ヒット商品数」「評価数」「評価点」から計算した、このアプリ独自のスコアです。',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: HomeScreenColors.metricTileCaptionColor,
                                height: 1.35,
                              ),
                        ),
                        if (_excludeSavedShops)
                          Text(
                            removedCount > 0
                                ? '※ 保存済みショップを除外しています（除外 $removedCount件）。'
                                : '※ 保存済みショップも含めて表示されています。',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: HomeScreenColors.footnoteMuted,
                                  height: 1.3,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.screenPadH,
                    0,
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapFieldStack,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      selected: _excludeSavedShops,
                      onSelected: (next) {
                        setState(() => _excludeSavedShops = next);
                      },
                      label: const Text('保存済ショップを除外'),
                      avatar: const Icon(Icons.bookmarks_outlined, size: 18),
                      selectedColor: AppColors.accentPrimary.withValues(
                        alpha: 0.15,
                      ),
                      showCheckmark: false,
                      side: BorderSide(
                        color: _excludeSavedShops
                            ? HomeScreenColors.sectionOutlineAccent
                            : HomeScreenColors.deckOutline,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      RakutenSearchScreenUi.screenPadH,
                      RakutenSearchScreenUi.listScrollTopPad,
                      RakutenSearchScreenUi.screenPadH,
                      RakutenSearchScreenUi.listBottomPad +
                          RakutenSearchScreenUi.listScrollExtraPadDiscovery,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: RakutenSearchScreenUi.listCardGap),
                    itemBuilder: (context, index) {
                      final summary = visible[index];
                      final shopItems = search.results
                          .where(
                            (e) => _shopDiscoveryGroupKey(e) == summary.shopKey,
                          )
                          .toList(growable: false);
                      final isSaved = saved.isSaved(summary.shopKey);
                      return ShopDiscoveryCard(
                        summary: summary,
                        rank: index + 1,
                        isSaved: isSaved,
                        onOpenShop: () =>
                            _openShopDetail(context, summary, shopItems),
                        onSave: () =>
                            _saveDiscoveredShop(context, summary, isSaved),
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
        builder: (_) =>
            ShopDiscoveryDetailScreen(summary: summary, items: items),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(isSaved ? '保存解除しました' : '保存しました')));
  }
}

enum _RakutenSearchMode {
  product(
    'キーワード検索',
    Icons.shopping_bag_outlined,
    'キーワード中心で商品を探し、必要に応じて詳細条件で絞り込みます',
  ),
  genre('ジャンル検索', Icons.category_outlined, '楽天のジャンルIDを軸に、商品をまとめて探します'),
  shopDiscovery(
    'ショップ発掘',
    Icons.storefront_outlined,
    'キーワードやジャンルから強いショップ候補を見つけます',
  );

  const _RakutenSearchMode(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class _DiscoveryFlowGuideCompact extends StatelessWidget {
  const _DiscoveryFlowGuideCompact();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.route_outlined,
            size: 16,
            color: HomeScreenColors.statusAccentMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '発掘 → 詳細で比較 → 保存で次回もすぐ開く',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.groupedSectionBody,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchModeSegmented extends StatelessWidget {
  const _SearchModeSegmented({
    required this.mode,
    required this.onChanged,
    this.compact = false,
  });

  final _RakutenSearchMode mode;
  final ValueChanged<_RakutenSearchMode> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: compact ? 15 : 17,
              color: HomeScreenColors.footnoteMuted,
            ),
            const SizedBox(width: 6),
            Text(
              '検索の種類',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.footnoteMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                fontSize: compact ? 11.5 : null,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 5),
        SegmentedButton<_RakutenSearchMode>(
          segments: const [
            ButtonSegment<_RakutenSearchMode>(
              value: _RakutenSearchMode.product,
              label: Text('キーワード'),
              icon: Icon(Icons.shopping_bag_outlined, size: 15),
            ),
            ButtonSegment<_RakutenSearchMode>(
              value: _RakutenSearchMode.genre,
              label: Text('ジャンル'),
              icon: Icon(Icons.category_outlined, size: 15),
            ),
            ButtonSegment<_RakutenSearchMode>(
              value: _RakutenSearchMode.shopDiscovery,
              label: Text('発掘'),
              icon: Icon(Icons.storefront_outlined, size: 15),
            ),
          ],
          selected: <_RakutenSearchMode>{mode},
          onSelectionChanged: (Set<_RakutenSearchMode> next) {
            if (next.isEmpty) return;
            onChanged(next.first);
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(
                horizontal: compact ? 6 : 10,
                vertical: compact ? 6 : 10,
              ),
            ),
            side: WidgetStateProperty.all(
              BorderSide(color: HomeScreenColors.deckOutline),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Color.alphaBlend(
                  HomeScreenColors.inkAccentSplash,
                  HomeScreenColors.deckFill,
                );
              }
              return HomeScreenColors.deckFill;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return HomeScreenColors.statusAccentStrong;
              }
              return HomeScreenColors.groupedSectionBody;
            }),
          ),
        ),
      ],
    );
  }
}

enum _GenreSort { reviewCount, reviewAverage }

/// 検索 UI 用に保存済ショップを正規化（空 ID・空名を除き、重複 shopId は先勝ち）。
List<SavedShop> _sanitizedSavedShopsForSearch(List<SavedShop> raw) {
  final out = <SavedShop>[];
  final seen = <String>{};
  for (final e in raw) {
    try {
      final id = e.shopId.trim();
      final name = e.shopName.trim();
      if (id.isEmpty || name.isEmpty) continue;
      if (seen.contains(id)) continue;
      seen.add(id);
      out.add(e);
    } catch (_) {}
  }
  try {
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  } catch (_) {}
  return out;
}

List<RakutenSearchGenreOption> get _mockGenres => [
  const RakutenSearchGenreOption(id: null, label: '指定なし'),
  ...RakutenGenreMasterService.instance.orderedMasterEntriesForDropdown().map(
    (e) => RakutenSearchGenreOption(id: e.genreId, label: e.genreName),
  ),
];
