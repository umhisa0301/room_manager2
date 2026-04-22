import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/shop_discovery_summary.dart';
import '../navigation/app_route_observer.dart';
import '../navigation/app_shell_controller.dart';
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
import '../widgets/add_candidate_entry_sheet.dart';
import '../widgets/search_group_screen_shell.dart';
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
  RakutenKeywordSearchSortMode _genreExploreSort =
      RakutenKeywordSearchSortMode.defaultOrder;
  RakutenKeywordSearchSortMode _keywordSort =
      RakutenKeywordSearchSortMode.defaultOrder;
  final ScrollController _keywordResultsScrollController = ScrollController();
  final ScrollController _genreResultsScrollController = ScrollController();
  RakutenSearchStatus _lastCompletionToastStatus = RakutenSearchStatus.idle;

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
    _genreExploreSort = RakutenKeywordSearchSortMode.defaultOrder;
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
    _genreResultsScrollController.dispose();
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
      body: SearchGroupScreenShell(
        backgroundColor: HomeScreenColors.canvas,
        contentPadding: EdgeInsets.zero,
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
                              child: _buildResultArea(
                                context,
                                search,
                                managed,
                                saved,
                              ),
                            )
                          : _buildResultArea(context, search, managed, saved),
                    ),
                  ],
                );
              },
            ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  void _returnToShellWithTab(BuildContext context, int index) {
    context.read<AppShellController>().selectTab(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openSavedShopsFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SavedShopsScreen()),
    );
  }

  Future<void> _showAddCandidateSheet() {
    return showAddCandidateEntryBottomSheet(
      context: context,
      onTapRakutenProductSearch: (sheetContext) async {
        Navigator.of(sheetContext).pop();
      },
      onTapSavedShops: _openSavedShopsFromSheet,
      onTapShopDiscovery: (sheetContext) async {
        Navigator.of(sheetContext).pop();
      },
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.85),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -1),
            blurRadius: 6,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: _RakutenSearchBottomNavItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'ホーム',
                  isSelected: false,
                  onTap: () => _returnToShellWithTab(context, 0),
                ),
              ),
              Expanded(
                child: _RakutenSearchBottomNavItem(
                  icon: Icons.travel_explore_outlined,
                  selectedIcon: Icons.travel_explore_rounded,
                  label: '探す',
                  isSelected: true,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: _RakutenSearchBottomNavItem(
                  icon: Icons.add_circle_outline_rounded,
                  selectedIcon: Icons.add_circle_rounded,
                  label: '＋',
                  isSelected: false,
                  onTap: () {
                    _showAddCandidateSheet();
                  },
                ),
              ),
              Expanded(
                child: _RakutenSearchBottomNavItem(
                  icon: Icons.collections_bookmark_outlined,
                  selectedIcon: Icons.collections_bookmark,
                  label: 'ROOMコレ',
                  isSelected: false,
                  onTap: () => _returnToShellWithTab(context, 1),
                ),
              ),
              Expanded(
                child: _RakutenSearchBottomNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'マイページ',
                  isSelected: false,
                  onTap: () => _returnToShellWithTab(context, 4),
                ),
              ),
            ],
          ),
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

  /// 詳細条件シート（ジャンルタブ）から。検証→閉じる→メインで検索。
  void _submitGenreSearchFromDetailSheet(
    BuildContext screenContext,
    BuildContext sheetContext,
  ) {
    if (_selectedGenreId == null || _selectedGenreId!.trim().isEmpty) {
      ScaffoldMessenger.of(
        sheetContext,
      ).showSnackBar(const SnackBar(content: Text('ジャンルを選択してください')));
      return;
    }
    final err = _validateGenreDetailInputs();
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
      _runGenreSearch(screenContext);
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
    if (kDebugMode) {
      final c = condition;
      debugPrint(
        '[Rakuten] keyword search execute keyword="${c.keyword}" '
        'genreId=${c.genreId ?? '-'} '
        'genreName(lookup)=${_labelForGenre(c.genreId) ?? '-'} '
        'shopCode=${c.shopCode ?? '-'} '
        'shopName(saved lookup)=${_savedShopNameForLog(context, c.shopCode)} hits=30 '
        'excludeRegistered=${excludeIds.length} savedShopExcludeSet=${savedShopCodes.length} '
        '(scoped shop はリポジトリで saved 除外対象外)',
      );
    }
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
      sort: _apiSortParamForMode(_keywordSort),
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
    // 3モードで入力デッキ周りの縦余白を揃える（旧商品名モードの 5 / 4 に合わせてジャンル・発掘を詰める）。
    final deckTopPad = 5.0;
    final deckBottomPad = 4.0;
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
                  _SearchModeSegmented(mode: _mode, onChanged: _onModeChanged),
                  SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
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
    final canSearch = !loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _buildResultSortControl(
            context,
            value: _keywordSort,
            resultsScrollController: _keywordResultsScrollController,
            onSortSelected: (next) => _onKeywordSortChanged(context, next),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        _buildUnifiedSearchControls(
          context,
          detailLabel: '検索キーワード',
          onOpenDetail: () => _openProductConditionsSheet(context),
          onClear: () {
            _dismissKeywordSearchKeyboard();
            _clearConditionsForCurrentMode();
          },
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        _buildPrimarySearchButton(
          context,
          label: 'キーワード検索を実行',
          onPressed: canSearch ? () => _runSearch(context) : null,
        ),
      ],
    );
  }

  Widget _buildGenreInput(BuildContext context, RakutenSearchProvider search) {
    final loading = search.status == RakutenSearchStatus.loading;
    final canSearch = !loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _buildResultSortControl(
            context,
            value: _genreExploreSort,
            resultsScrollController: _genreResultsScrollController,
            onSortSelected: (next) => _onGenreSortChanged(context, next),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        _buildUnifiedSearchControls(
          context,
          detailLabel: 'ジャンルを選ぶ',
          onOpenDetail: () => _openProductConditionsSheet(context),
          onClear: _clearConditionsForCurrentMode,
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        _buildPrimarySearchButton(
          context,
          label: 'ジャンル探索で検索',
          onPressed: canSearch ? () => _runGenreSearch(context) : null,
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
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openShopDiscoveryConditionsSheet(context),
            icon: Icon(
              Icons.tune_rounded,
              size: 17,
              color: HomeScreenColors.accentSectionHeading,
            ),
            label: const Text('検索キーワード'),
            style: _detailConditionsButtonStyle(),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedShopsScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: HomeScreenColors.leadOnSection,
              backgroundColor: Color.alphaBlend(
                HomeScreenColors.subActionRowFill.withValues(alpha: 0.45),
                HomeScreenColors.deckFill,
              ),
              side: BorderSide(color: HomeScreenColors.inlineDivider),
              minimumSize: const Size(0, 36),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.bookmarks_outlined, size: 16),
            label: Text('保存ショップ（$savedCount）'),
          ),
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
              'ショップ発掘を実行',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
    setState(() {
      _mode = next;
      _selectionMode = false;
      _selectedProductIds.clear();
    });
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

  /// ジャンル検索：ジャンル・補助キーワードは残し、価格・評価・ショップなど詳細だけ初期化する。
  void _clearGenreDetailConditionsOnly() {
    setState(() {
      _minPriceController.clear();
      _maxPriceController.clear();
      _excludeKeywordController.clear();
      _minReviewCountController.clear();
      _minReviewAverageController.clear();
      _minCommentCountController.clear();
      _selectedShopCode = null;
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
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  ButtonStyle _neutralConditionsButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.groupedSectionBody,
      backgroundColor: HomeScreenColors.deckFill,
      side: BorderSide(color: HomeScreenColors.deckOutline),
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  Widget _buildUnifiedSearchControls(
    BuildContext context, {
    required String detailLabel,
    required VoidCallback onOpenDetail,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenDetail,
            icon: Icon(
              Icons.tune_rounded,
              size: 17,
              color: HomeScreenColors.accentSectionHeading,
            ),
            label: Text(detailLabel),
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
            onPressed: onClear,
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
    );
  }

  Widget _buildPrimarySearchButton(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.search_rounded, size: 22),
        label: Text(
          '検索',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
    );
  }

  /// キーワード詳細シート下部の補助操作（閉じる／絞り込みリセット）。主CTAより弱く、輪郭で押せる範囲をはっきりさせる。
  ButtonStyle _keywordDetailSheetAuxiliaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.leadOnSection,
      backgroundColor: HomeScreenColors.deckFill,
      side: BorderSide(color: HomeScreenColors.deckOutline, width: 1),
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: 1.2,
      ),
    );
  }

  Future<void> _openProductConditionsSheet(BuildContext screenContext) async {
    const denseGap = 8.0;
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
                              ? 'キーワード検索の条件'
                              : 'ジャンル探索の条件',
                          style: RakutenSearchScreenUi.sectionHeadingAccent(
                            context,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mode == _RakutenSearchMode.product
                              ? 'まず検索キーワードを入力してください。'
                              : 'まず検索ジャンル（必須）を選んでください。',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: HomeScreenColors.groupedSectionBody,
                                height: 1.3,
                              ),
                        ),
                        if (_mode == _RakutenSearchMode.genre) ...[
                          const SizedBox(height: denseGap),
                          Text(
                            '最初に「検索ジャンル（必須）」を選択',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: HomeScreenColors.accentSectionHeading,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          DecoratedBox(
                            decoration:
                                RakutenSearchScreenUi.modeTabDeckDecoration(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  RakutenSearchGenreDropdownField(
                                    labelText: '検索ジャンル（必須）',
                                    value: _selectedGenreId,
                                    options: _mockGenres,
                                    onChanged: (value) {
                                      _setSelectedGenreId(value);
                                      setModalState(() {});
                                    },
                                  ),
                                  SizedBox(
                                    height: RakutenSearchScreenUi.gapFieldStack,
                                  ),
                                  TextField(
                                    controller: _genreController,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) =>
                                        _submitGenreSearchFromDetailSheet(
                                          screenContext,
                                          sheetContext,
                                        ),
                                    onChanged: (_) => setModalState(() {}),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          height: 1.22,
                                          color: HomeScreenColors.titlePrimary,
                                        ),
                                    decoration:
                                        RakutenSearchScreenUi.searchField(
                                          labelText: '補助キーワード（任意）',
                                          hintText: '例: 収納 ボックス',
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color:
                                                HomeScreenColors.leadOnSection,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: denseGap),
                        ] else ...[
                          const SizedBox(height: denseGap),
                          TextField(
                            controller: _keywordController,
                            autofocus: true,
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
                          const SizedBox(height: denseGap),
                        ],
                        RakutenSearchPriceRangeRow(
                          minPriceController: _minPriceController,
                          maxPriceController: _maxPriceController,
                          digitsOnlyFormatters:
                              RakutenKeywordDetailConditionsInput
                                  .digitsOnlyField,
                        ),
                        const SizedBox(height: denseGap),
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
                        const SizedBox(height: denseGap),
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
                        const SizedBox(height: denseGap),
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
                        const SizedBox(height: denseGap),
                        Consumer<SavedShopProvider>(
                          builder: (context, savedProv, _) {
                            final shops = _sanitizedSavedShopsForSearch(
                              savedProv.shops,
                            );
                            return RakutenSearchSavedShopPicker(
                              shops: shops,
                              selectedShopCode: _selectedShopCode,
                              onShopChanged: (value) {
                                _setSelectedShopCode(context, value);
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
                        if (_mode == _RakutenSearchMode.product) ...[
                          const SizedBox(height: denseGap),
                          RakutenSearchGenreDropdownField(
                            labelText: 'ジャンル（任意）',
                            value: _selectedGenreId,
                            options: _mockGenres,
                            onChanged: (value) {
                              _setSelectedGenreId(value);
                              setModalState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: denseGap),
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
                                      '条件を保存して検索',
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
                                  const SizedBox(height: denseGap),
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
                                          label: const Text('閉じる（検索しない）'),
                                          style:
                                              _keywordDetailSheetAuxiliaryButtonStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                          Consumer<RakutenSearchProvider>(
                            builder: (context, search, _) {
                              final loading =
                                  search.status == RakutenSearchStatus.loading;
                              final genreOk =
                                  _selectedGenreId != null &&
                                  _selectedGenreId!.trim().isNotEmpty;
                              final canSearch = !loading && genreOk;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: !canSearch
                                        ? null
                                        : () =>
                                              _submitGenreSearchFromDetailSheet(
                                                screenContext,
                                                sheetContext,
                                              ),
                                    icon: const Icon(
                                      Icons.search_rounded,
                                      size: 22,
                                    ),
                                    label: const Text(
                                      '条件を保存して検索',
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
                                  const SizedBox(height: denseGap),
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
                                          label: const Text('閉じる（検索しない）'),
                                          style:
                                              _keywordDetailSheetAuxiliaryButtonStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            _clearGenreDetailConditionsOnly();
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
    const denseGap = 8.0;
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
                      'ショップ発掘の条件',
                      style: RakutenSearchScreenUi.sectionHeadingAccent(
                        context,
                      ),
                    ),
                    const SizedBox(height: denseGap),
                    TextField(
                      controller: _shopDiscoveryKeywordController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: RakutenSearchScreenUi.searchField(
                        labelText: 'キーワード',
                        hintText: '例: おしゃれ 家具',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: HomeScreenColors.leadOnSection,
                        ),
                      ),
                    ),
                    const SizedBox(height: denseGap),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: HomeScreenColors.titlePrimary),
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
                    const SizedBox(height: denseGap),
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
                    const SizedBox(height: denseGap),
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
                    const SizedBox(height: denseGap),
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
                    const SizedBox(height: denseGap),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: AppColors.textOnAccent,
                        minimumSize: const Size(0, 44),
                        visualDensity: VisualDensity.compact,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ショップ発掘では、キーワードまたはジャンルを指定してください')),
      );
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

  String _genreUiLabelForId(String? id) {
    if (id == null || id.trim().isEmpty) return '指定なし';
    for (final o in _mockGenres) {
      if (o.id == id) return o.label;
    }
    return id;
  }

  void _setSelectedGenreId(String? value) {
    if (kDebugMode) {
      debugPrint(
        '[Rakuten] genre UI selected label=${_genreUiLabelForId(value)} '
        'genreId=${value ?? '(null)'} '
        'genreName(lookup)=${_labelForGenre(value) ?? '(null)'}',
      );
    }
    setState(() => _selectedGenreId = value);
  }

  void _setSelectedShopCode(BuildContext context, String? value) {
    if (kDebugMode) {
      final shop = value != null && value.trim().isNotEmpty
          ? context.read<SavedShopProvider>().findById(value.trim())
          : null;
      debugPrint(
        '[Rakuten] shop UI selected label=${shop?.shopName ?? value ?? '指定なし'} '
        'shopCode=${value ?? '(null)'} shopName=${shop?.shopName ?? '(null)'} '
        'shopUrl=${shop?.shopUrl ?? '-'} savedModel shopId=${shop?.shopId ?? '-'}',
      );
    }
    setState(() => _selectedShopCode = value);
  }

  String _savedShopNameForLog(BuildContext context, String? shopCode) {
    final c = shopCode?.trim();
    if (c == null || c.isEmpty) return '-';
    return context.read<SavedShopProvider>().findById(c)?.shopName ??
        '(unknown)';
  }

  /// キーワード／ジャンル結果メタ用。保存済ショップで API 絞り込み中のときのみ。
  String? _shopScopeEmphasisLineForMeta(BuildContext context) {
    final scoped = _effectiveShopCodeForApi(context);
    if (scoped == null || scoped.isEmpty) return null;
    final nm = _savedShopNameForLog(context, scoped);
    if (nm != '-' && nm != '(unknown)') {
      return 'ショップで絞り込み: 「$nm」';
    }
    return 'ショップで絞り込み（店舗コード: $scoped）';
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
      sort: _apiSortParamForMode(_genreExploreSort),
    ).normalized();
    if (kDebugMode) {
      debugPrint(
        '[Rakuten] genreSearch execute keyword="${condition.keyword}" '
        'keywordLen=${condition.keyword.length} '
        'genreId=${condition.genreId ?? '-'} '
        'genreName(lookup)=${_labelForGenre(condition.genreId) ?? '-'} '
        'shopCode=${condition.shopCode ?? '-'} '
        'shopName(saved lookup)=${_savedShopNameForLog(context, condition.shopCode)} hits=20',
      );
    }
    if (_genreResultsScrollController.hasClients) {
      _genreResultsScrollController.jumpTo(0);
    }
    final excludeIds = context
        .read<RakutenManagedProductProvider>()
        .productIdsExcludedFromKeywordSearch();
    final savedShopCodes = context
        .read<SavedShopProvider>()
        .shops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    await context.read<RakutenSearchProvider>().searchWithCondition(
      condition,
      excludeRegisteredProductIds: excludeIds,
      excludeSavedShopCodes: savedShopCodes,
    );
  }

  /// 候補済・コレ済の商品や保存済みショップの商品を優先的に除外したリストを返す。
  /// ただし、除外しすぎて極端に件数が減る場合は元のリストをそのまま使う前提で呼び出し元でフォールバックする。
  ///
  /// [searchScopeShopCode] に API 検索で絞り込んだ shopCode があるとき、当該ショップは
  /// 「保存済み」であっても一覧から落とさない（ショップ指定検索の結果が 0 件にならないようにする）。
  List<RakutenSearchItem> _applyPreferredExcludes(
    List<RakutenSearchItem> source,
    RakutenManagedProductProvider managed,
    SavedShopProvider saved, {
    String? searchScopeShopCode,
  }) {
    if (source.isEmpty) return source;
    final scoped = searchScopeShopCode?.trim() ?? '';
    final out = <RakutenSearchItem>[];
    var exclCandidate = 0;
    var exclDone = 0;
    var exclSavedShop = 0;
    for (final item in source) {
      final status = managed.statusForProduct(item.productId);
      final itemShop = item.shopCode.trim();
      final fromSavedShop = itemShop.isNotEmpty && saved.isSaved(itemShop);
      if (status == RakutenManagedProductStatus.candidate) {
        exclCandidate++;
        continue;
      }
      if (status == RakutenManagedProductStatus.done) {
        exclDone++;
        continue;
      }
      if (fromSavedShop) {
        if (scoped.isNotEmpty && itemShop == scoped) {
          out.add(item);
          continue;
        }
        exclSavedShop++;
        continue;
      }
      out.add(item);
    }
    if (kDebugMode) {
      debugPrint(
        '[Rakuten] UI preferred excludes before=${source.length} after=${out.length} '
        'candidateExclude=$exclCandidate doneExclude=$exclDone savedShopExclude=$exclSavedShop '
        'searchScopeShopCode=${scoped.isEmpty ? '-' : scoped}',
      );
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

  String? _apiSortParamForMode(RakutenKeywordSearchSortMode mode) {
    switch (mode) {
      case RakutenKeywordSearchSortMode.defaultOrder:
        return null;
      case RakutenKeywordSearchSortMode.priceAscending:
        return '+itemPrice';
      case RakutenKeywordSearchSortMode.ratingDescending:
        return '-reviewAverage';
      case RakutenKeywordSearchSortMode.reviewCountDescending:
        return '-reviewCount';
    }
  }

  void _onKeywordSortChanged(
    BuildContext context,
    RakutenKeywordSearchSortMode next,
  ) {
    if (_keywordSort == next) return;
    setState(() => _keywordSort = next);
    final search = context.read<RakutenSearchProvider>();
    if (_mode == _RakutenSearchMode.product &&
        search.status == RakutenSearchStatus.success) {
      _runSearch(context);
    }
  }

  void _onGenreSortChanged(
    BuildContext context,
    RakutenKeywordSearchSortMode next,
  ) {
    if (_genreExploreSort == next) return;
    setState(() => _genreExploreSort = next);
    final search = context.read<RakutenSearchProvider>();
    if (_mode == _RakutenSearchMode.genre &&
        search.status == RakutenSearchStatus.success) {
      _runGenreSearch(context);
    }
  }

  Widget _buildResultSortControl(
    BuildContext context, {
    required RakutenKeywordSearchSortMode value,
    required ScrollController resultsScrollController,
    required void Function(RakutenKeywordSearchSortMode next) onSortSelected,
  }) {
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
              value: value,
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
                if (next == null || next == value) return;
                onSortSelected(next);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (resultsScrollController.hasClients) {
                    resultsScrollController.jumpTo(0);
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 選択モード行（キーワード／ジャンルで同一）。
  Widget _buildResultsSelectionRow(
    BuildContext context,
    RakutenManagedProductProvider managed,
    List<RakutenSearchItem> orderedResults,
  ) {
    final selectableCount = orderedResults
        .where((e) => _isSelectableForBulk(e, managed))
        .length;
    return Padding(
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
              onPressed: _selectedProductIds.isEmpty || _isBulkRegistering
                  ? null
                  : _clearBulkSelection,
              child: const Text('全部解除'),
            ),
          ],
        ],
      ),
    );
  }

  void _showCompletionFeedbackIfNeeded(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    final status = search.status;
    final shouldShow =
        status == RakutenSearchStatus.success &&
        _lastCompletionToastStatus != RakutenSearchStatus.success;
    _lastCompletionToastStatus = status;
    if (!shouldShow) return;

    final text = switch (_mode) {
      _RakutenSearchMode.product => '検索が完了しました（${search.results.length}件）',
      _RakutenSearchMode.genre => '検索が完了しました（${search.results.length}件）',
      _RakutenSearchMode.shopDiscovery =>
        '商品の取得が完了しました（${search.results.length}件）',
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
      messenger.showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  /// 件数説明・補足・除外脚注（キーワード／ジャンルで同一スタイル）。
  Widget _buildResultsMetaAndExcludeFootnote(
    BuildContext context, {
    required String primaryLine,
    String? emphasisLine,
    String? secondEmphasisLine,
  }) {
    Widget emphasisText(String line) {
      return Text(
        line,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: HomeScreenColors.leadOnSection,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Padding(
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
            primaryLine,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.footnoteMuted,
            ),
          ),
          if (emphasisLine != null) ...[
            const SizedBox(height: 4),
            emphasisText(emphasisLine),
          ],
          if (secondEmphasisLine != null) ...[
            const SizedBox(height: 4),
            emphasisText(secondEmphasisLine),
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
    );
  }

  /// 帯・選択行・メタとリストを縦分割する。キーボード表示などで下ペインが低いとき、
  /// 固定高さヘッダの合計が領域を超えて [RenderFlex] オーバーフローしないよう、
  /// 上部は割当て高さ内でスクロール可能にする。
  Widget _buildSearchResultsHeaderAndListColumn({
    required List<Widget> headerChildren,
    required Widget listPane,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: headerChildren,
            ),
          ),
        ),
        Expanded(flex: 5, child: listPane),
      ],
    );
  }

  /// 結果リストまたは（キーワード用）空の内訳別表示＋一括登録バー。
  ///
  /// [emptyPreferredFilteredOut] / [emptyGenericFilteredOut] がともに null のとき、
  /// 件数0では [SizedBox.shrink] を返す（ジャンル成功ブロックなど）。
  Widget _buildResultsListWithBulkBar(
    BuildContext context, {
    required RakutenManagedProductProvider managed,
    required List<RakutenSearchItem> orderedResults,
    required ScrollController scrollController,
    bool keywordPreferredFilteredAllOut = false,
    Widget? emptyPreferredFilteredOut,
    Widget? emptyGenericFilteredOut,
  }) {
    final bottomPad = _selectionMode
        ? RakutenSearchScreenUi.listBottomPadWithSelectionBar
        : RakutenSearchScreenUi.listBottomPad + 6;

    Widget listOrEmpty() {
      if (orderedResults.isNotEmpty) {
        return Consumer<RakutenSearchProvider>(
          builder: (context, search, _) {
            return ListView.separated(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                RakutenSearchScreenUi.screenPadH,
                RakutenSearchScreenUi.listScrollTopPad,
                RakutenSearchScreenUi.screenPadH,
                bottomPad,
              ),
              itemCount: orderedResults.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: RakutenSearchScreenUi.listCardGap),
              itemBuilder: (context, index) {
                final item = orderedResults[index];
                final isSelectable = _isSelectableForBulk(item, managed);
                return RakutenSearchResultCard(
                  item: item,
                  localStatus: managed.statusForProduct(item.productId),
                  isRegistering: managed.isRegistering(item.productId),
                  selectionMode: _selectionMode,
                  isSelected: _selectedProductIds.contains(item.productId),
                  isSelectionEnabled: isSelectable && !_isBulkRegistering,
                  selectionDisabledLabel: _selectionDisabledReason(
                    item,
                    managed,
                  ),
                  genreDisplayLineOverride: search.genreLineForItem(item),
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                );
              },
            );
          },
        );
      }
      if (keywordPreferredFilteredAllOut && emptyPreferredFilteredOut != null) {
        return emptyPreferredFilteredOut;
      }
      if (emptyGenericFilteredOut != null) {
        return emptyGenericFilteredOut;
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: listOrEmpty()),
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
                  onPressed: _selectedProductIds.isEmpty || _isBulkRegistering
                      ? null
                      : () => _bulkRegisterCandidates(managed, orderedResults),
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

  Widget _buildResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
    SavedShopProvider saved,
  ) {
    _showCompletionFeedbackIfNeeded(context, search);
    if (_mode == _RakutenSearchMode.shopDiscovery) {
      return _buildShopDiscoveryResultArea(context, search);
    }
    if (_mode == _RakutenSearchMode.genre) {
      return _buildGenreResultArea(context, search, managed, saved);
    }
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return const RakutenSearchIdleView(
          icon: Icons.manage_search_outlined,
          title: '商品がここに表示されます',
          subtitle: '上でキーワードを設定して「検索」。条件は「検索キーワード」から調整できます。',
          stateFootnote: '登録済み候補・コレ済は除外します（最大100件まで取得）。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const RakutenSearchLoadingView(
          title: '商品を探しています',
          subtitle: '楽天の商品情報を読み込んでいます。',
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
          adjustLabel: '検索キーワードを開く',
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          if (search.keywordSearchHadApiHitsButNoVisibleResults) {
            return RakutenSearchEmptyView(
              icon: Icons.playlist_remove_rounded,
              title: '表示できる新しい候補が見つかりませんでした',
              body: '登録済み（コレ候補・コレ済）を除くと、表示できる商品がありませんでした。',
              hints: const [
                'キーワードや条件を変える',
                '登録済みが多いと、同じ条件では新しい候補は出にくくなります',
                '「ジャンル探索」「ショップ発掘」で別の探し方を試す',
              ],
              onRefine: () => _openProductConditionsSheet(context),
              refineLabel: '検索キーワードを開く',
              stateFootnote: '楽天側に商品があっても、候補・コレ済を除くと0件になることがあります。',
            );
          }
          return RakutenSearchEmptyView(
            icon: Icons.inventory_2_outlined,
            title: '条件に合う商品は見つかりませんでした',
            body: '該当商品がないか、条件が厳しすぎる可能性があります。',
            hints: const [
              'キーワードの言い回しを変えてみる',
              '条件（価格・評価など）を緩める',
              '除外ワードを減らす、または空にする',
              'ショップ絞り込みを外す、または「ジャンル探索」を試す',
            ],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: '検索キーワードを開く',
            stateFootnote: '読み込みは完了していますが、この条件では0件です。',
          );
        }
        final managedPreferred = _applyPreferredExcludes(
          search.results,
          managed,
          saved,
          searchScopeShopCode: _effectiveShopCodeForApi(context),
        );
        // キーワードタブ: API 側で候補・コレ済・保存ショップを除いて最大100件まで集約済み。
        // ここでは一覧表示の一貫性のため同条件で再フィルタし、
        // その結果が空でも登録済み商品を一覧に戻さない（新しい候補探索の体験を優先）。
        final filteredResults = managedPreferred;
        final orderedResults = filteredResults;
        final keywordPreferredFilteredAllOut =
            _mode == _RakutenSearchMode.product &&
            managedPreferred.isEmpty &&
            search.results.isNotEmpty;
        final totalCount = search.results.length;
        final showingCount = filteredResults.length;
        final kwMeta = search.keywordManagedFetchSummary;
        final shortfallNote = search.keywordManagedVisibleShortfallNote();
        final primaryMeta = kwMeta != null
            ? '一覧は $showingCount件です（コレ候補・コレ済・保存ショップを除き、最大${kwMeta.targetVisibleCap}件までAPIから集めた結果）。'
            : (totalCount == showingCount
                  ? '一覧 $showingCount件です。'
                  : '一覧 $showingCount件です（全体 $totalCount件から表示用に除外）。');
        final shopScopeLine = _shopScopeEmphasisLineForMeta(context);
        return _buildSearchResultsHeaderAndListColumn(
          headerChildren: [
            _buildResultsSelectionRow(context, managed, orderedResults),
            _buildResultsMetaAndExcludeFootnote(
              context,
              primaryLine: primaryMeta,
              emphasisLine: shopScopeLine ?? shortfallNote,
              secondEmphasisLine: shopScopeLine != null && shortfallNote != null
                  ? shortfallNote
                  : null,
            ),
          ],
          listPane: _buildResultsListWithBulkBar(
            context,
            managed: managed,
            orderedResults: orderedResults,
            scrollController: _keywordResultsScrollController,
            keywordPreferredFilteredAllOut: keywordPreferredFilteredAllOut,
            emptyPreferredFilteredOut: RakutenSearchEmptyView(
              icon: Icons.store_mall_directory_outlined,
              title: 'この条件では一覧を表示できませんでした',
              body: 'ヒットはありましたが、保存済みショップの商品だけだったため一覧表示できませんでした。',
              hints: const ['キーワードや条件を変えて再検索する', 'ジャンル探索など別の切り口も試せます'],
              onRefine: () => _openProductConditionsSheet(context),
              refineLabel: '検索キーワードを開く',
              stateFootnote: 'コレ候補・コレ済以外の商品は、すでに結果に含めています。',
            ),
            emptyGenericFilteredOut: RakutenSearchEmptyView(
              icon: Icons.filter_alt_off_outlined,
              title: 'この一覧では表示できる商品がありません',
              body: '検索結果は取得できていますが、表示条件により0件になっています。',
              hints: const ['キーワードや条件を変えて再検索する', '「ジャンル探索」に切り替えて別の切り口を試す'],
              onRefine: () => _openProductConditionsSheet(context),
              refineLabel: '検索キーワードを開く',
              stateFootnote: 'データ取得は完了しています。条件を変えて試せます。',
            ),
          ),
        );
    }
  }

  Widget _buildGenreResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
    SavedShopProvider saved,
  ) {
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return const RakutenSearchIdleView(
          icon: Icons.explore_outlined,
          title: 'ジャンルから広く候補を眺める',
          subtitle: 'まずジャンルを選んで「検索」。条件は「ジャンルを選ぶ」から調整できます。',
          stateFootnote: '検索が始まるまで、このエリアは更新されません。登録済み候補・コレ済は除外します（最大100件まで取得）。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const RakutenSearchLoadingView(
          title: '商品を探しています',
          subtitle: '楽天の商品情報を読み込んでいます。',
          footnote: '除外・複数ページ取得のため、このままお待ちください。',
        );
      case RakutenSearchStatus.error:
        return RakutenSearchErrorView(
          title: '検索結果を表示できませんでした',
          stateLine: '状態: 通信または楽天APIの応答に失敗しました',
          message: search.errorMessage.isNotEmpty
              ? search.errorMessage
              : '時間をおいて「もう一度検索する」を押すか、条件を緩めて試してください。',
          onRetry: () => _runGenreSearch(context),
          onAdjustConditions: () => _openProductConditionsSheet(context),
          adjustLabel: 'ジャンルを選ぶ',
        );
      case RakutenSearchStatus.success:
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] genreSearch before render count=${search.results.length}',
          );
        }
        if (search.results.isEmpty) {
          return RakutenSearchEmptyView(
            icon: Icons.inventory_2_outlined,
            title: '条件に合う商品は見つかりませんでした',
            body: '該当商品がないか、条件が厳しすぎる可能性があります。',
            hints: const [
              '補助キーワードを空にするか、別の言い方に変える',
              '条件（価格・評価など）を緩める',
              '別のジャンルを選ぶ',
            ],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: 'ジャンルを選ぶ',
            stateFootnote: '読み込みは完了していますが、この条件では0件です。',
          );
        }
        final managedPreferred = _applyPreferredExcludes(
          search.results,
          managed,
          saved,
          searchScopeShopCode: _effectiveShopCodeForApi(context),
        );
        final filteredResults = managedPreferred;
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
                ? '楽天からは $n 件取得できましたが、コレ候補・コレ済・保存済みショップを除いた新規候補はありませんでした。'
                : '検索の取得はできていますが、表示対象が0件です。',
            hints: const ['条件を緩めて再検索する', '「キーワード検索」に切り替える'],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: 'ジャンルを選ぶ',
            stateFootnote: 'データ取得は完了しています。条件を変えて試せます。',
          );
        }
        final showingCount = filteredResults.length;
        final orderedResults = filteredResults;
        final genreLabel = _labelForGenre(_selectedGenreId) ?? '選択中のジャンル';
        final totalCount = search.results.length;
        final primaryMeta = totalCount == showingCount
            ? '一覧 $showingCount件です。'
            : '一覧 $showingCount件です（全体 $totalCount件から表示用に除外）。';
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] genreSearch itemBuilder count=${orderedResults.length}',
          );
        }
        return _buildSearchResultsHeaderAndListColumn(
          headerChildren: [
            _buildResultsSelectionRow(context, managed, orderedResults),
            _buildResultsMetaAndExcludeFootnote(
              context,
              primaryLine: primaryMeta,
              emphasisLine: 'ジャンル探索中: 「$genreLabel」',
              secondEmphasisLine: _shopScopeEmphasisLineForMeta(context),
            ),
          ],
          listPane: _buildResultsListWithBulkBar(
            context,
            managed: managed,
            orderedResults: orderedResults,
            scrollController: _genreResultsScrollController,
          ),
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
          title: 'ここではまだショップ発掘の結果を表示していません',
          subtitle: 'キーワードかジャンルを指定して「ショップ発掘を実行」。条件は「検索キーワード」から調整できます。',
          stateFootnote: 'ショップ発掘が始まるまで、このエリアは更新されません。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const RakutenSearchLoadingView(
          title: 'ショップ発掘のためデータを読み込んでいます',
          subtitle: '商品を読み込み、ショップ単位で集計しています。',
          footnote: '取得中はこの画面を開いたままお待ちください。長く応答がないときは回線や楽天側の混雑も考えられます。',
        );
      case RakutenSearchStatus.error:
        return RakutenSearchErrorView(
          title: 'ショップ発掘を完了できませんでした',
          stateLine: '状態: 通信または楽天APIの応答に失敗しました',
          message: search.errorMessage.isNotEmpty
              ? search.errorMessage
              : '時間をおいて「もう一度検索する」を押すか、ショップ発掘の条件を緩めて試してください。',
          onRetry: () => _runShopDiscovery(context),
          onAdjustConditions: () => _openShopDiscoveryConditionsSheet(context),
          adjustLabel: 'ショップ発掘の条件を開く',
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return RakutenSearchEmptyView(
            icon: Icons.travel_explore_outlined,
            title: 'ショップ発掘のもとになる商品がありませんでした',
            body: '該当商品がないか、条件が厳しすぎる可能性があります。',
            hints: const [
              'キーワードを広げる、または別のジャンルも試す',
              'ショップ発掘の条件の評価数・評価点を緩める',
              '除外ワードを減らす',
            ],
            onRefine: () => _openShopDiscoveryConditionsSheet(context),
            refineLabel: 'ショップ発掘の条件を調整',
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
            body: '商品は取得できましたが、ショップ候補を作成できませんでした。',
            hints: const ['ショップ発掘の条件を緩めて再実行する', 'キーワードやジャンルを変えて商品数を増やす'],
            onRefine: () => _openShopDiscoveryConditionsSheet(context),
            refineLabel: 'ショップ発掘の条件を開く',
            stateFootnote: '読み込みは完了していますが、表示できるショップは0件です。',
          );
        }
        return Consumer<SavedShopProvider>(
          builder: (context, saved, _) {
            final raw = summaries;
            final visible = raw
                .where((s) => !saved.isSaved(s.shopKey))
                .toList(growable: false);
            final removedCount = raw.length - visible.length;
            if (visible.isEmpty) {
              return RakutenSearchEmptyView(
                icon: Icons.store_mall_directory_outlined,
                title: '保存済みを除く新規ショップがありません',
                body: '今回の結果はすべて保存済みショップでした。新規候補のみ表示しています。',
                hints: const ['キーワードやジャンルを変えて再実行する', 'ショップ発掘の条件を緩める'],
                onRefine: () => _openShopDiscoveryConditionsSheet(context),
                refineLabel: 'ショップ発掘の条件を開く',
                stateFootnote: '検索自体は成功しています。',
              );
            }
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapListAfterDivider,
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
                          'ショップ発掘の結果 ${visible.length}件のショップ（スコア順）',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomeScreenColors.metricTileTitleColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'スコアはヒット商品数・評価数・評価点から算出しています。',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: HomeScreenColors.metricTileCaptionColor,
                                height: 1.35,
                              ),
                        ),
                        Text(
                          '※ 保存済みショップは除外しています（除外 $removedCount件）。',
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
  product('商品名で探す', Icons.shopping_bag_outlined, '商品名や用途の言葉で、新しい候補商品を探します。'),
  genre('ジャンルから探す', Icons.explore_outlined, 'カテゴリを起点に、キーワードなしでも候補商品を探せます。'),
  shopDiscovery(
    'ショップを発掘',
    Icons.storefront_outlined,
    '条件を整えて実行すると、保存したいショップ候補を見つけられます。',
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
              'ショップ発掘 → 詳細で比較 → 保存で次回もすぐ開く',
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
  const _SearchModeSegmented({required this.mode, required this.onChanged});

  final _RakutenSearchMode mode;
  final ValueChanged<_RakutenSearchMode> onChanged;

  /// 長いタブラベルでも1行内に収まるよう縮小。折り返しは最大2行。
  Widget _tabSegmentLabel(
    BuildContext context,
    String text, {
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.15,
          color: isSelected
              ? AppColors.textOnAccent
              : HomeScreenColors.groupedSectionBody,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        SegmentedButton<_RakutenSearchMode>(
          expandedInsets: EdgeInsets.zero,
          segments: [
            ButtonSegment<_RakutenSearchMode>(
              value: _RakutenSearchMode.product,
              label: _tabSegmentLabel(
                context,
                _RakutenSearchMode.product.label,
                isSelected: mode == _RakutenSearchMode.product,
              ),
            ),
            ButtonSegment<_RakutenSearchMode>(
              value: _RakutenSearchMode.genre,
              label: _tabSegmentLabel(
                context,
                _RakutenSearchMode.genre.label,
                isSelected: mode == _RakutenSearchMode.genre,
              ),
            ),
            ButtonSegment<_RakutenSearchMode>(
              value: _RakutenSearchMode.shopDiscovery,
              label: _tabSegmentLabel(
                context,
                _RakutenSearchMode.shopDiscovery.label,
                isSelected: mode == _RakutenSearchMode.shopDiscovery,
              ),
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
            minimumSize: WidgetStateProperty.all(const Size(0, 48)),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            side: WidgetStateProperty.all(
              BorderSide(color: HomeScreenColors.deckOutline),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.accentPrimary;
              }
              return HomeScreenColors.deckFill;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.textOnAccent;
              }
              return HomeScreenColors.groupedSectionBody;
            }),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        Text(
          mode.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: HomeScreenColors.groupedSectionBody,
            height: 1.3,
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RakutenSearchBottomNavItem extends StatelessWidget {
  const _RakutenSearchBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: AppDimensions.iconNav,
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: isSelected
                      ? AppTextStyles.navLabelSelected
                      : AppTextStyles.navLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

List<RakutenSearchGenreOption>? _searchGenreDropdownMemo;

/// ドロップダウン用。再ビルドのたびに [orderedMasterEntriesForDropdown] を走らせない。
List<RakutenSearchGenreOption> get _mockGenres {
  final m = _searchGenreDropdownMemo;
  if (m != null) return m;
  final built = <RakutenSearchGenreOption>[
    const RakutenSearchGenreOption(id: null, label: '指定なし'),
    ...RakutenGenreMasterService.instance.orderedMasterEntriesForDropdown().map(
      (e) => RakutenSearchGenreOption(id: e.genreId, label: e.genreName),
    ),
  ];
  _searchGenreDropdownMemo = built;
  return built;
}
