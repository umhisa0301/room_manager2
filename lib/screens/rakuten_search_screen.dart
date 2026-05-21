import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/debug_log_flags.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/shop_discovery_summary.dart';
import '../navigation/app_route_observer.dart';
import '../navigation/app_shell_controller.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/shop_discovery_aggregator.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../utils/app_input_limits.dart';
import '../utils/genre_display_resolve.dart';
import '../utils/rakuten_search_session_cache.dart';
import '../utils/product_safety_filter.dart';
import '../utils/rakuten_keyword_search_sort.dart';
import '../utils/room_sync_log.dart';
import '../validation/rakuten_keyword_detail_conditions_validation.dart';
import '../widgets/rakuten_search_condition_fields.dart';
import '../widgets/rakuten_search_detail_condition_entry_chrome.dart';
import '../widgets/rakuten_search_feedback.dart';
import '../widgets/rakuten_search_result_card.dart';
import '../widgets/add_candidate_entry_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_draggable_edge_fab.dart';
import '../widgets/search_group_screen_shell.dart';
import '../widgets/shop_discovery_card.dart';
import '../widgets/search_bulk_selection_header.dart';
import '../widgets/search_mode_segment_bar.dart';
import '../utils/search_tab_ui_audit_log.dart';
import 'add_candidate_from_url_screen.dart';
import 'saved_shops_screen.dart';
import 'shop_discovery_detail_screen.dart';

/// 楽天API商品検索画面（最小構成）。
enum RakutenSearchInitialMode { product, genre, shopDiscovery }

/// 探す画面の表示フェーズ（build 内の boolean 分岐を一本化）。
enum SearchSurfacePhase { input, loading, result, empty, error }

class RakutenSearchScreen extends StatefulWidget {
  const RakutenSearchScreen({
    super.key,
    this.initialMode = RakutenSearchInitialMode.product,
    this.savedShopKeywordEntry = false,
    this.initialSavedShopCode,
    this.initialScopedShopCode,
    this.initialGenreId,
  });

  final RakutenSearchInitialMode initialMode;

  /// true のとき「保存ショップで探す」として、[SavedShopProvider] のショップ＋キーワードで検索する。
  final bool savedShopKeywordEntry;

  /// [savedShopKeywordEntry] で開いたときの初期選択ショップ（`SavedShop.shopId`）。
  final String? initialSavedShopCode;

  /// 商品名検索で API shopCode を事前指定（保存ショップ未登録でも可）。
  final String? initialScopedShopCode;

  /// ジャンル探索で事前選択する genreId。
  final String? initialGenreId;

  @override
  State<RakutenSearchScreen> createState() => _RakutenSearchScreenState();
}

class _RakutenSearchScreenState extends State<RakutenSearchScreen>
    with RouteAware, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
  String? _analyticsScopedShopCode;
  String? _selectedGenreId;
  String? _productDetailGenreId;
  String? _selectedDiscoveryGenreId;
  bool _isBulkRegistering = false;
  int _bulkRegisterProcessed = 0;
  int _bulkRegisterTotal = 0;
  bool _savedShopKeywordFlow = false;
  final Set<String> _selectedProductIds = <String>{};
  bool _routeSubscribed = false;
  bool _initialSavedShopPresetApplied = false;
  RakutenKeywordSearchSortMode _genreExploreSort =
      RakutenKeywordSearchSortMode.defaultOrder;
  RakutenKeywordSearchSortMode _keywordSort =
      RakutenKeywordSearchSortMode.defaultOrder;
  final ScrollController _keywordResultsScrollController = ScrollController();
  final ScrollController _genreResultsScrollController = ScrollController();
  final ScrollController _shopDiscoveryResultsScrollController =
      ScrollController();

  /// 結果ありでは常にコンパクトヘッダー固定（リスト内デッキ再表示は廃止）。
  bool _searchHeaderCollapsed = true;
  RakutenSearchStatus _lastCompletionToastStatus = RakutenSearchStatus.idle;
  String? _detailSheetFormError;
  String? _savedShopSearchFieldError;
  final GlobalKey<FormState> _detailSearchFormKey = GlobalKey<FormState>();
  bool _detailSearchAutovalidate = false;
  final FocusNode _productDetailSheetKeywordFocus = FocusNode(
    debugLabel: 'productDetailSheetKeyword',
  );
  final FocusNode _genreDetailSheetDropdownFocus = FocusNode(
    debugLabel: 'genreDetailSheetDropdown',
  );
  final FocusNode _discoveryDetailSheetKeywordFocus = FocusNode(
    debugLabel: 'discoveryDetailSheetKeyword',
  );
  final FocusNode _savedShopKeywordFocusNode = FocusNode(
    debugLabel: 'savedShopKeyword',
  );
  bool _savedShopSearchCanSubmit = false;
  SearchSurfacePhase _previousSearchPhase = SearchSurfacePhase.input;

  RakutenSearchProvider? _cachedSearchProvider;
  BulkOperationStateController? _cachedBulkCtl;

  _RakutenSearchMode get _initialSearchMode {
    switch (widget.initialMode) {
      case RakutenSearchInitialMode.product:
        return _RakutenSearchMode.product;
      case RakutenSearchInitialMode.genre:
        return _RakutenSearchMode.genre;
      case RakutenSearchInitialMode.shopDiscovery:
        return _RakutenSearchMode.shopDiscovery;
    }
  }

  bool get _savedShopKeywordEntryEffective =>
      widget.savedShopKeywordEntry || _savedShopKeywordFlow;

  void _applyInitialSavedShopPresetOnce() {
    if (_initialSavedShopPresetApplied) return;
    final preset = widget.initialSavedShopCode?.trim();
    if (preset == null || preset.isEmpty) return;
    if (!widget.savedShopKeywordEntry) return;
    _initialSavedShopPresetApplied = true;
    setState(() => _selectedShopCode = preset);
  }

  void _applyInitialScopedPresetsOnce() {
    final scoped = widget.initialScopedShopCode?.trim();
    if (scoped != null && scoped.isNotEmpty) {
      _analyticsScopedShopCode = scoped;
    }
    final gid = widget.initialGenreId?.trim();
    if (gid != null && gid.isNotEmpty && _selectedGenreId == null) {
      _selectedGenreId = gid;
    }
  }

  @override
  void initState() {
    super.initState();
    _mode = _initialSearchMode;
    _applyInitialScopedPresetsOnce();
    if (widget.savedShopKeywordEntry) {
      _savedShopKeywordFlow = true;
    }
    _savedShopKeywordFocusNode.addListener(_onSavedShopKeywordFocusChanged);
    _keywordController.addListener(_onSavedShopKeywordTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreSearchSession(_modeCacheKey());
      _applyInitialSavedShopPresetOnce();
    });
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_RENDER_ERROR_AUDIT] checkedTerminal=true overflowFound=pending '
        'overflowFixed=pending target=searchHeader|savedShop',
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedSearchProvider = context.read<RakutenSearchProvider>();
    _cachedBulkCtl = context.read<BulkOperationStateController>();
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
    _shopDiscoveryResultsScrollController.dispose();
    _productDetailSheetKeywordFocus.dispose();
    _genreDetailSheetDropdownFocus.dispose();
    _discoveryDetailSheetKeywordFocus.dispose();
    _savedShopKeywordFocusNode.removeListener(_onSavedShopKeywordFocusChanged);
    _keywordController.removeListener(_onSavedShopKeywordTextChanged);
    _savedShopKeywordFocusNode.dispose();
    _saveCurrentSearchSession();
    super.dispose();
  }

  void _onSavedShopKeywordFocusChanged() {
    if (!_savedShopKeywordEntryEffective) return;
    _logSavedShopKeywordFocusAudit(
      event: _savedShopKeywordFocusNode.hasFocus ? 'focusGained' : 'focusLost',
    );
  }

  void _onSavedShopKeywordTextChanged() {
    if (!_savedShopKeywordEntryEffective) return;
    _logSavedShopKeywordFocusAudit(event: 'onChanged');
    final nextCan = _keywordController.text.trim().isNotEmpty;
    if (nextCan != _savedShopSearchCanSubmit) {
      setState(() => _savedShopSearchCanSubmit = nextCan);
    }
  }

  void _logSavedShopKeywordFocusAudit({
    required String event,
    String reason = '-',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[SAVED_SHOP_KEYWORD_FOCUS_AUDIT] event=$event '
      'hasFocus=${_savedShopKeywordFocusNode.hasFocus} '
      'keywordLength=${_keywordController.text.length} '
      'controllerHash=${_keywordController.hashCode} '
      'focusNodeHash=${_savedShopKeywordFocusNode.hashCode} reason=$reason',
    );
  }

  void _logSavedShopKeywordRebuildAudit() {
    if (!kDebugMode) return;
    debugPrint(
      '[SAVED_SHOP_KEYWORD_REBUILD_AUDIT] selectedShopCode=${_selectedShopCode ?? '-'} '
      'keyword=${_keywordController.text.trim()} controllerPreserved=true '
      'focusNodePreserved=true',
    );
  }

  @override
  void didPopNext() {
    // 同一セッション内は検索結果・条件を保持する（タブ往復で消さない）。
  }

  String _modeCacheKey() {
    if (_savedShopKeywordEntryEffective) {
      return RakutenSearchSessionCache.modeSavedShop;
    }
    return switch (_mode) {
      _RakutenSearchMode.product => RakutenSearchSessionCache.modeProduct,
      _RakutenSearchMode.genre => RakutenSearchSessionCache.modeGenre,
      _RakutenSearchMode.shopDiscovery =>
        RakutenSearchSessionCache.modeShopDiscovery,
    };
  }

  RakutenSearchUiSnapshot _captureUiSnapshot() {
    final key = _modeCacheKey();
    final shared = (
      minPrice: _minPriceController.text,
      maxPrice: _maxPriceController.text,
      excludeKeyword: _excludeKeywordController.text,
      minReviewCount: _minReviewCountController.text,
      minReviewAverage: _minReviewAverageController.text,
      minCommentCount: _minCommentCountController.text,
      selectionMode: false,
      selectedProductIds: Set<String>.from(_selectedProductIds),
      searchHeaderCollapsed: _searchHeaderCollapsed,
      savedShopKeywordFlow: _savedShopKeywordFlow,
    );
    return switch (key) {
      RakutenSearchSessionCache.modeSavedShop => RakutenSearchUiSnapshot(
        keyword: _keywordController.text,
        selectedShopCode: _selectedShopCode,
        selectedGenreId: null,
        productDetailGenreId: null,
        selectedDiscoveryGenreId: null,
        genreAux: '',
        shopDiscoveryKeyword: '',
        shopDiscoveryExclude: '',
        shopDiscoveryMinReviewCount: '',
        shopDiscoveryMinReviewAverage: '',
        shopDiscoveryShopLimit: '10',
        shopDiscoveryItemsPerShop: '5',
        minPrice: shared.minPrice,
        maxPrice: shared.maxPrice,
        excludeKeyword: shared.excludeKeyword,
        minReviewCount: shared.minReviewCount,
        minReviewAverage: shared.minReviewAverage,
        minCommentCount: shared.minCommentCount,
        selectionMode: shared.selectionMode,
        selectedProductIds: shared.selectedProductIds,
        searchHeaderCollapsed: shared.searchHeaderCollapsed,
        savedShopKeywordFlow: shared.savedShopKeywordFlow,
      ),
      RakutenSearchSessionCache.modeGenre => RakutenSearchUiSnapshot(
        keyword: '',
        genreAux: _genreController.text,
        selectedGenreId: _selectedGenreId,
        productDetailGenreId: null,
        selectedShopCode: null,
        selectedDiscoveryGenreId: null,
        shopDiscoveryKeyword: '',
        shopDiscoveryExclude: '',
        shopDiscoveryMinReviewCount: '',
        shopDiscoveryMinReviewAverage: '',
        shopDiscoveryShopLimit: '10',
        shopDiscoveryItemsPerShop: '5',
        minPrice: shared.minPrice,
        maxPrice: shared.maxPrice,
        excludeKeyword: shared.excludeKeyword,
        minReviewCount: shared.minReviewCount,
        minReviewAverage: shared.minReviewAverage,
        minCommentCount: shared.minCommentCount,
        selectionMode: shared.selectionMode,
        selectedProductIds: shared.selectedProductIds,
        searchHeaderCollapsed: shared.searchHeaderCollapsed,
        savedShopKeywordFlow: false,
      ),
      RakutenSearchSessionCache.modeShopDiscovery => RakutenSearchUiSnapshot(
        keyword: '',
        genreAux: '',
        selectedGenreId: null,
        productDetailGenreId: null,
        selectedShopCode: null,
        selectedDiscoveryGenreId: _selectedDiscoveryGenreId,
        shopDiscoveryKeyword: _shopDiscoveryKeywordController.text,
        shopDiscoveryExclude: _shopDiscoveryExcludeController.text,
        shopDiscoveryMinReviewCount: _shopDiscoveryMinReviewCountController.text,
        shopDiscoveryMinReviewAverage:
            _shopDiscoveryMinReviewAverageController.text,
        shopDiscoveryShopLimit: _shopDiscoveryShopLimitController.text,
        shopDiscoveryItemsPerShop: _shopDiscoveryItemsPerShopController.text,
        minPrice: '',
        maxPrice: '',
        excludeKeyword: '',
        minReviewCount: '',
        minReviewAverage: '',
        minCommentCount: '',
        selectionMode: shared.selectionMode,
        selectedProductIds: shared.selectedProductIds,
        searchHeaderCollapsed: shared.searchHeaderCollapsed,
        savedShopKeywordFlow: false,
      ),
      _ => RakutenSearchUiSnapshot(
        keyword: _keywordController.text,
        selectedGenreId: null,
        productDetailGenreId: _productDetailGenreId,
        selectedShopCode: null,
        selectedDiscoveryGenreId: null,
        genreAux: '',
        shopDiscoveryKeyword: '',
        shopDiscoveryExclude: '',
        shopDiscoveryMinReviewCount: '',
        shopDiscoveryMinReviewAverage: '',
        shopDiscoveryShopLimit: '10',
        shopDiscoveryItemsPerShop: '5',
        minPrice: shared.minPrice,
        maxPrice: shared.maxPrice,
        excludeKeyword: shared.excludeKeyword,
        minReviewCount: shared.minReviewCount,
        minReviewAverage: shared.minReviewAverage,
        minCommentCount: shared.minCommentCount,
        selectionMode: shared.selectionMode,
        selectedProductIds: shared.selectedProductIds,
        searchHeaderCollapsed: shared.searchHeaderCollapsed,
        savedShopKeywordFlow: false,
      ),
    };
  }

  void _applyUiSnapshot(RakutenSearchUiSnapshot ui) {
    _minPriceController.text = ui.minPrice;
    _maxPriceController.text = ui.maxPrice;
    _excludeKeywordController.text = ui.excludeKeyword;
    _minReviewCountController.text = ui.minReviewCount;
    _minReviewAverageController.text = ui.minReviewAverage;
    _minCommentCountController.text = ui.minCommentCount;
    _keywordController.text = ui.keyword;
    _genreController.text = ui.genreAux;
    _shopDiscoveryKeywordController.text = ui.shopDiscoveryKeyword;
    _shopDiscoveryExcludeController.text = ui.shopDiscoveryExclude;
    _shopDiscoveryMinReviewCountController.text = ui.shopDiscoveryMinReviewCount;
    _shopDiscoveryMinReviewAverageController.text =
        ui.shopDiscoveryMinReviewAverage;
    _shopDiscoveryShopLimitController.text = ui.shopDiscoveryShopLimit;
    _shopDiscoveryItemsPerShopController.text = ui.shopDiscoveryItemsPerShop;
    _selectedShopCode = ui.selectedShopCode;
    _selectedGenreId = ui.selectedGenreId;
    _productDetailGenreId = ui.productDetailGenreId;
    _selectedDiscoveryGenreId = ui.selectedDiscoveryGenreId;
    _selectedProductIds
      ..clear()
      ..addAll(ui.selectedProductIds);
    _searchHeaderCollapsed = ui.searchHeaderCollapsed;
    _savedShopKeywordFlow = ui.savedShopKeywordFlow;
    _purgeCrossModeFieldsAfterRestore();
  }

  void _purgeCrossModeFieldsAfterRestore() {
    if (_savedShopKeywordEntryEffective) {
      _selectedGenreId = null;
      _productDetailGenreId = null;
      _selectedDiscoveryGenreId = null;
      _genreController.clear();
      _shopDiscoveryKeywordController.clear();
      return;
    }
    switch (_mode) {
      case _RakutenSearchMode.product:
        _selectedGenreId = null;
        _selectedDiscoveryGenreId = null;
        _genreController.clear();
        _shopDiscoveryKeywordController.clear();
        break;
      case _RakutenSearchMode.genre:
        _selectedShopCode = null;
        _productDetailGenreId = null;
        _keywordController.clear();
        _selectedDiscoveryGenreId = null;
        break;
      case _RakutenSearchMode.shopDiscovery:
        _selectedShopCode = null;
        _selectedGenreId = null;
        _productDetailGenreId = null;
        _keywordController.clear();
        _genreController.clear();
        break;
    }
  }

  void _saveCurrentSearchSession() {
    final search = _cachedSearchProvider;
    if (search == null) return;
    final cache = RakutenSearchSessionCache.instance;
    final key = _modeCacheKey();
    cache.saveProviderSnapshot(key, search);
    cache.saveUiSnapshot(key, _captureUiSnapshot());
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_DISPOSE_SAVE_FIX] providerCached=true contextReadInDispose=false saved=true',
      );
    }
  }

  void _restoreSearchSession(String key) {
    if (!mounted) return;
    final search = _cachedSearchProvider;
    if (search == null) return;
    final cache = RakutenSearchSessionCache.instance;
    cache.restoreProviderSnapshot(key, search);
    final ui = cache.uiSnapshot(key);
    if (ui != null) {
      setState(() {
        _applyUiSnapshot(ui);
        _savedShopSearchCanSubmit = _keywordController.text.trim().isNotEmpty;
      });
    }
  }

  String _providerModeTag() {
    if (_savedShopKeywordEntryEffective) return 'savedShop';
    return switch (_mode) {
      _RakutenSearchMode.product => 'product',
      _RakutenSearchMode.genre => 'genre',
      _RakutenSearchMode.shopDiscovery => 'shopDiscovery',
    };
  }

  SearchSurfacePhase _resolveSearchSurfacePhase(RakutenSearchProvider search) {
    if (search.status == RakutenSearchStatus.loading) {
      return SearchSurfacePhase.loading;
    }
    final modeTag = _providerModeTag();
    if (search.isErrorVisibleForMode(modeTag)) {
      return SearchSurfacePhase.error;
    }
    if (search.status == RakutenSearchStatus.success) {
      if (search.results.isEmpty) return SearchSurfacePhase.empty;
      return SearchSurfacePhase.result;
    }
    return SearchSurfacePhase.input;
  }

  bool _showInputDeckForPhase(SearchSurfacePhase phase) =>
      phase == SearchSurfacePhase.input;

  bool _showCompactHeaderForPhase(SearchSurfacePhase phase) =>
      phase == SearchSurfacePhase.result || phase == SearchSurfacePhase.empty;

  void _logSearchSurfacePhaseAudit({
    required SearchSurfacePhase phase,
    required RakutenSearchProvider search,
    required bool keyboardVisible,
  }) {
    if (!kDebugMode) return;
    final mode = _searchResultScreenTag();
    final hasResult = search.results.isNotEmpty;
    final hasError = search.isErrorVisibleForMode(_providerModeTag());
    debugPrint(
      '[SEARCH_SURFACE_PHASE_AUDIT] mode=$mode phase=${phase.name} '
      'isLoading=${search.status == RakutenSearchStatus.loading} '
      'hasResult=$hasResult hasError=$hasError '
      'inputDeckVisible=${_showInputDeckForPhase(phase)} '
      'compactHeaderVisible=${_showCompactHeaderForPhase(phase)} '
      'emptyCardVisible=${phase == SearchSurfacePhase.empty} '
      'errorCardVisible=${phase == SearchSurfacePhase.error} '
      'listVisible=${phase == SearchSurfacePhase.result}',
    );
  }

  void _logSearchLayoutPhaseTransition({
    required SearchSurfacePhase nextPhase,
    required String reason,
  }) {
    if (!kDebugMode) return;
    if (_previousSearchPhase == nextPhase) return;
    debugPrint(
      '[SEARCH_LAYOUT_PHASE_AUDIT] previousPhase=${_previousSearchPhase.name} '
      'nextPhase=${nextPhase.name} mode=${_searchResultScreenTag()} reason=$reason',
    );
    _previousSearchPhase = nextPhase;
  }

  void _logSearchOverflowGuardAudit({
    required BuildContext context,
    required SearchSurfacePhase phase,
    required RakutenSearchProvider search,
    required bool keyboardVisible,
  }) {
    if (!kDebugMode) return;
    final mq = MediaQuery.of(context);
    final availableHeight = mq.size.height - mq.padding.top - mq.padding.bottom;
    final phaseName = switch (phase) {
      SearchSurfacePhase.input => 'beforeSearch',
      SearchSurfacePhase.loading => 'loading',
      SearchSurfacePhase.result => 'success',
      SearchSurfacePhase.empty => 'empty',
      SearchSurfacePhase.error => 'error',
    };
    debugPrint(
      '[SEARCH_OVERFLOW_GUARD_AUDIT] mode=${_searchResultScreenTag()} '
      'phase=$phaseName keyboardVisible=$keyboardVisible '
      'hasResult=${search.results.isNotEmpty} '
      'hasError=${search.isErrorVisibleForMode(_providerModeTag())} '
      'headerVisible=${_showCompactHeaderForPhase(phase)} '
      'inputDeckVisible=${_showInputDeckForPhase(phase)} '
      'resultAreaExpanded=true '
      'errorCardInsideExpanded=${phase == SearchSurfacePhase.error} '
      'availableHeight=$availableHeight bottomInset=${mq.viewInsets.bottom}',
    );
  }

  void _logSearchKeyboardLayoutAudit({
    required bool keyboardVisible,
    required SearchSurfacePhase phase,
    required bool errorCardCompact,
    required BuildContext context,
  }) {
    if (!kDebugMode) return;
    final focusField = _savedShopKeywordFocusNode.hasFocus
        ? 'savedShopKeyword'
        : (_productDetailSheetKeywordFocus.hasFocus ? 'productKeyword' : '-');
    final mq = MediaQuery.of(context);
    final availableHeight = mq.size.height - mq.viewInsets.bottom;
    debugPrint(
      '[SEARCH_KEYBOARD_LAYOUT_AUDIT] mode=${_searchResultScreenTag()} '
      'keyboardVisible=$keyboardVisible focusField=$focusField '
      'onSearchUnfocusCalled=true errorCardCompact=$errorCardCompact '
      'availableHeight=$availableHeight',
    );
  }

  void _logSearchErrorStateAudit({
    required RakutenSearchProvider search,
    required SearchSurfacePhase phase,
  }) {
    if (!kDebugMode) return;
    final visibleSurface = switch (phase) {
      SearchSurfacePhase.loading => 'loading',
      SearchSurfacePhase.result => 'result',
      SearchSurfacePhase.empty => 'empty',
      SearchSurfacePhase.error => 'error',
      SearchSurfacePhase.input => search.results.isNotEmpty
          ? 'result'
          : 'input',
    };
    final withWarning =
        search.retryFailureBannerMessage != null ? 'resultWithWarning' : visibleSurface;
    debugPrint(
      '[SEARCH_ERROR_STATE_AUDIT] mode=${_searchResultScreenTag()} '
      'hasPreviousResult=${search.hasPreviousResult} '
      'hasError=${search.isErrorVisibleForMode(_providerModeTag())} '
      'isLoading=${search.status == RakutenSearchStatus.loading} '
      'visibleSurface=$withWarning',
    );
  }

  void _logSearchLayoutGuard(
    BuildContext context, {
    required double keyboardInset,
    required bool compactSetup,
  }) {
    if (!kDebugMode || !DebugLogFlags.enableVerboseSearchStateLog) return;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    debugPrint(
      '[SEARCH_LAYOUT_GUARD] mode=${_searchResultScreenTag()} '
      'keyboardInset=$keyboardInset bottomSafeArea=$bottomSafe '
      'usesExpandedList=true usesBottomPadding=true compactSetup=$compactSetup',
    );
  }

  void _logSavedShopSearchUxAudit({
    required bool selectedShop,
    required bool keywordEmpty,
    required bool searchEnabled,
    String? disabledReason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[SAVED_SHOP_SEARCH_UX_AUDIT] selectedShop=$selectedShop '
      'keywordEmpty=$keywordEmpty duplicateGuideTextCount=0 '
      'keywordTapOpensDetailSheet=false conditionButtonVisible=$selectedShop '
      'searchEnabled=$searchEnabled disabledReason=${disabledReason ?? '-'}',
    );
  }

  void _logSearchHeaderDuplicateAudit({
    required bool hasResults,
  }) {
    if (!kDebugMode) return;
    final compactHeaderVisible = hasResults;
    final expandedInputDeckVisible = !hasResults;
    final inputDeckRenderedInList = false;
    final modeSelectorCount = hasResults ? 1 : 1;
    final searchInputCount = hasResults ? 0 : 1;
    debugPrint(
      '[SEARCH_HEADER_DUPLICATE_AUDIT] mode=${_searchResultScreenTag()} '
      'hasResult=$hasResults compactHeaderVisible=$compactHeaderVisible '
      'expandedInputDeckVisible=$expandedInputDeckVisible '
      'inputDeckRenderedInList=$inputDeckRenderedInList '
      'renderCountOfModeSelector=$modeSelectorCount '
      'renderCountOfSearchInput=$searchInputCount '
      'reason=${hasResults ? 'resultsUseCompactHeaderOnly' : 'preSearchInputDeck'}',
    );
  }

  void _logSearchHeaderWidgetTreeAudit({
    required bool compactSetup,
    required bool hasResults,
  }) {
    if (!kDebugMode || !DebugLogFlags.enableVerboseSearchStateLog) return;
    final mode = _searchResultScreenTag();
    debugPrint(
      '[SEARCH_HEADER_WIDGET_TREE_AUDIT] mode=$mode usesSharedHeader=true '
      'legacyModeHeaderVisible=false extraTopTitleVisible=false '
      'setupHeaderVisible=${!compactSetup} compactHeaderVisible=$compactSetup '
      'hasResults=$hasResults',
    );
    if (_savedShopKeywordEntryEffective) {
      debugPrint(
        '[SAVED_SHOP_HEADER_AUDIT] legacyHeaderRemoved=true usesSharedSearchHeader=true '
        'giantShopSelectCard=false disabledReasonVisible=true',
      );
    }
    debugPrint(
      '[SEARCH_RESULT_AREA_AUDIT] mode=$mode hasResults=$hasResults '
      'setupHeaderVisible=${!compactSetup} compactHeaderVisible=$compactSetup '
      'resultAreaExpanded=$hasResults selectAllVisibleWithoutScroll=$hasResults '
      'firstItemVisibleWithoutScroll=$hasResults',
    );
    debugPrint(
      '[SEARCH_HEADER_HEIGHT] mode=$mode phase=${compactSetup ? 'afterSearch' : 'beforeSearch'} '
      'height=${compactSetup ? 'compact' : 'setup'}',
    );
  }

  String? _savedShopSearchDisabledReason(BuildContext context, bool loading) {
    if (loading) return null;
    final bulk = _cachedBulkCtl ?? context.read<BulkOperationStateController>();
    if (bulk.isBulkCandidateRegistering || _isBulkRegistering) {
      return '登録処理中です。完了後にお試しください';
    }
    if (bulk.isRoomTourSearchBlocking) {
      return 'ROOM同期中です。完了後にお試しください';
    }
    final scoped = _effectiveShopCodeForApi(context);
    if (scoped == null) return 'ショップを選択してください';
    if (_keywordController.text.trim().isEmpty) {
      return 'キーワードを入力してください';
    }
    final kwErr = AppInputLimits.validateSavedShopSearchKeyword(
      _keywordController.text,
    );
    if (kwErr != null && kwErr != '商品名やキーワードを入力してください') {
      return kwErr;
    }
    return null;
  }

  Widget _buildBulkOperationBanner(BuildContext context) {
    return Consumer<BulkOperationStateController>(
      builder: (context, bulk, _) {
        final running = bulk.isBulkCandidateRegistering || _isBulkRegistering;
        if (!running && !bulk.isRoomImportRunning) {
          return const SizedBox.shrink();
        }
        if (kDebugMode && running) {
          debugPrint(
            '[BULK_REGISTER_UI_STATE] isRunning=true mode=candidate '
            'processed=$_bulkRegisterProcessed total=$_bulkRegisterTotal',
          );
        }
        final message = running
            ? '候補に追加中です：$_bulkRegisterProcessed / $_bulkRegisterTotal件\n登録中は他の商品登録を実行できません'
            : (bulk.blockingRoomTourUserMessage ?? '処理中です。完了後にお試しください');
        return Material(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        );
      },
    );
  }

  /// キーワード検索タブ: フォーカスを外してキーボードを閉じる。
  void _dismissKeywordSearchKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 一覧が出ているときは並び順を結果ヘッダ側へ寄せ、入力デッキの縦寸を削る。
  bool _sortLivesInResultsHeader(RakutenSearchProvider search) {
    if (_mode == _RakutenSearchMode.shopDiscovery) return false;
    return search.status == RakutenSearchStatus.success &&
        search.results.isNotEmpty;
  }

  List<String> _searchResultConditionSummaryLines(BuildContext context) {
    final price = _priceRangeSummaryLine();
    if (_savedShopKeywordEntryEffective) {
      final shopCode = _effectiveShopCodeForApi(context);
      final shopName = _savedShopNameForLog(context, shopCode);
      final kw = _keywordController.text.trim();
      return [
        shopName != '-' ? '保存ショップ：$shopName' : '保存ショップ：未選択',
        kw.isEmpty ? 'キーワード：未入力' : 'キーワード：$kw',
        '条件：$price',
      ];
    }
    return switch (_mode) {
      _RakutenSearchMode.product => () {
        final k = _keywordController.text.trim();
        return [
          k.isEmpty ? 'キーワード未入力' : k,
          '条件：$price',
        ];
      }(),
      _RakutenSearchMode.genre => () {
        final g = GenreDisplayResolve.collapsedTitleForGenreId(
          _selectedGenreId,
          screen: 'genreSearch',
        );
        return [
          'ジャンル：$g',
          '条件：$price',
        ];
      }(),
      _RakutenSearchMode.shopDiscovery => () {
        final k = _shopDiscoveryKeywordController.text.trim();
        return [
          k.isEmpty ? 'キーワード未入力' : k,
          '条件：$price',
        ];
      }(),
    };
  }

  void _logSearchResultConditionSummaryAudit(BuildContext context) {
    if (!kDebugMode) return;
    final lines = _searchResultConditionSummaryLines(context);
    debugPrint(
      '[SEARCH_RESULT_CONDITION_SUMMARY_AUDIT] mode=${_searchResultScreenTag()} '
      'summaryLine1=${lines.isNotEmpty ? lines.first : '-'} '
      'summaryLine2=${lines.length > 1 ? lines[1] : '-'} '
      'shopNameShown=$_savedShopKeywordEntryEffective '
      'genreNameShown=${_mode == _RakutenSearchMode.genre} '
      'keywordShown=${lines.any((l) => l.contains('キーワード') || (!_savedShopKeywordEntryEffective && _mode == _RakutenSearchMode.product))}',
    );
  }

  void _logSearchHeaderActionAudit({required bool hasResults}) {
    if (!kDebugMode) return;
    debugPrint(
      '[SEARCH_HEADER_ACTION_AUDIT] mode=${_searchResultScreenTag()} '
      'hasResult=$hasResults conditionSummaryTapEnabled=$hasResults '
      'conditionButtonVisible=true sortButtonVisible=${_mode != _RakutenSearchMode.shopDiscovery} '
      'searchButtonVisible=${!hasResults} retryButtonVisible=$hasResults',
    );
  }

  void _openConditionsForCurrentMode(BuildContext context) {
    switch (_mode) {
      case _RakutenSearchMode.product:
      case _RakutenSearchMode.genre:
        _openProductConditionsSheet(context);
        break;
      case _RakutenSearchMode.shopDiscovery:
        _openShopDiscoveryConditionsSheet(context);
        break;
    }
  }

  void _rerunSearchForCurrentMode(BuildContext context) {
    switch (_mode) {
      case _RakutenSearchMode.product:
        _runSearch(context);
        break;
      case _RakutenSearchMode.genre:
        _runGenreSearch(context);
        break;
      case _RakutenSearchMode.shopDiscovery:
        _runShopDiscovery(context);
        break;
    }
  }

  String _priceRangeSummaryLine() {
    final min = _parseInt(_minPriceController.text);
    final max = _parseInt(_maxPriceController.text);
    if (min == null && max == null) return '価格指定なし';
    if (min != null && max != null) return '¥$min〜$max';
    if (min != null) return '¥$min以上';
    return '¥$max以下';
  }

  String _searchResultScreenTag() {
    if (_savedShopKeywordEntryEffective) return 'savedShopSearch';
    return switch (_mode) {
      _RakutenSearchMode.product => 'productSearch',
      _RakutenSearchMode.genre => 'genreSearch',
      _RakutenSearchMode.shopDiscovery => 'shopDiscovery',
    };
  }

  void _logSavedShopSearchExecute(
    BuildContext context, {
    required int resultCount,
    required bool success,
    String? error,
  }) {
    if (!kDebugMode || !_savedShopKeywordEntryEffective) return;
    final c = _buildProductCondition(context);
    debugPrint(
      '[SAVED_SHOP_SEARCH_EXECUTE] shopCode=${c.shopCode ?? '-'} '
      'keyword="${c.keyword}" genreId=${c.genreId ?? '-'} '
      'minPrice=${c.minPrice ?? '-'} maxPrice=${c.maxPrice ?? '-'} '
      'resultCount=$resultCount success=$success error=${error ?? '-'}',
    );
  }

  Widget _buildInlineBackButton(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeScreenColors.leadOnSection,
            side: BorderSide(color: HomeScreenColors.sectionOutlineNeutral),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: Text(
            '戻る',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          SearchGroupScreenShell(
            backgroundColor: HomeScreenColors.canvas,
            contentPadding: EdgeInsets.zero,
            child:
                Consumer3<
                  RakutenSearchProvider,
                  RakutenManagedProductProvider,
                  SavedShopProvider
                >(
                  builder: (context, search, managed, saved, _) {
                    final phase = _resolveSearchSurfacePhase(search);
                    final hasResults = phase == SearchSurfacePhase.result;
                    final compactSetup = _showCompactHeaderForPhase(phase);
                    _logSearchLayoutPhaseTransition(
                      nextPhase: phase,
                      reason: 'build',
                    );
                    if (kDebugMode) {
                      _logSearchHeaderActionAudit(hasResults: hasResults);
                      _logSearchHeaderDuplicateAudit(hasResults: hasResults);
                      _logSearchHeaderWidgetTreeAudit(
                        compactSetup: compactSetup,
                        hasResults: hasResults,
                      );
                      _logSearchLayoutGuard(
                        context,
                        keyboardInset: keyboardInset,
                        compactSetup: compactSetup,
                      );
                      _logSearchSurfacePhaseAudit(
                        phase: phase,
                        search: search,
                        keyboardVisible: keyboardVisible,
                      );
                      _logSearchOverflowGuardAudit(
                        context: context,
                        phase: phase,
                        search: search,
                        keyboardVisible: keyboardVisible,
                      );
                      _logSearchErrorStateAudit(search: search, phase: phase);
                      debugPrint(
                        '[SEARCH_LAYOUT_STABILITY] phase=${phase.name} '
                        'keyboardVisible=$keyboardVisible overflowGuard=true',
                      );
                    }
                    final showInputDeck = _showInputDeckForPhase(phase);
                    final showCompactHeader = _showCompactHeaderForPhase(phase);
                    return Column(
                      children: [
                        _buildBulkOperationBanner(context),
                        if (showInputDeck)
                          Flexible(
                            fit: FlexFit.loose,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final maxHeader = keyboardVisible
                                    ? (constraints.maxHeight * 0.55)
                                          .clamp(120.0, constraints.maxHeight)
                                    : constraints.maxHeight;
                                return ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: maxHeader.isFinite
                                        ? maxHeader
                                        : 480,
                                  ),
                                  child: SingleChildScrollView(
                                    key: const ValueKey<String>(
                                      'search_mode_input_scroll',
                                    ),
                                    physics: const ClampingScrollPhysics(),
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    child: _buildModeAndInputArea(
                                      context,
                                      search,
                                      saved,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else if (showCompactHeader)
                          Flexible(
                            fit: FlexFit.loose,
                            child: SingleChildScrollView(
                              key: const ValueKey<String>(
                                'search_compact_header_scroll',
                              ),
                              physics: const ClampingScrollPhysics(),
                              child: _buildPostSearchCompactSetupBar(
                                context,
                                search,
                                saved,
                              ),
                            ),
                          ),
                        if (showInputDeck || showCompactHeader)
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
                                    phase: phase,
                                    keyboardVisible: keyboardVisible,
                                  ),
                                )
                              : _buildResultArea(
                                  context,
                                  search,
                                  managed,
                                  saved,
                                  phase: phase,
                                  keyboardVisible: keyboardVisible,
                                ),
                        ),
                      ],
                    );
                  },
                ),
          ),
          CommonDraggableEdgeFab(
            shellTabIndex: context.watch<AppShellController>().currentIndex,
            onCommentTap: () => _returnToShellWithTab(context, 2),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  void _returnToShellWithTab(BuildContext context, int index) {
    context.read<AppShellController>().selectTab(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openGenreSearchFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    _onSearchWayPicked(_SearchWayPicker.genre);
  }

  Future<void> _openAddFromUrlFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AddCandidateFromUrlScreen(),
      ),
    );
  }

  Future<void> _openSavedShopsFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() {
      _savedShopKeywordFlow = true;
    });
    _onModeChanged(_RakutenSearchMode.product);
  }

  Future<void> _showAddCandidateSheet() {
    return showAddCandidateEntryBottomSheet(
      context: context,
      onTapRakutenProductSearch: (sheetContext) async {
        Navigator.of(sheetContext).pop();
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        _onModeChanged(_RakutenSearchMode.product);
      },
      onTapGenreSearch: _openGenreSearchFromSheet,
      onTapSavedShops: _openSavedShopsFromSheet,
      onTapAddFromUrl: _openAddFromUrlFromSheet,
      onTapShopDiscovery: (sheetContext) async {
        Navigator.of(sheetContext).pop();
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        _onSearchWayPicked(_SearchWayPicker.shopDiscovery);
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
                  icon: Icons.add_circle_outline_rounded,
                  selectedIcon: Icons.add_circle_rounded,
                  label: '探す',
                  isSelected: true,
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
                  icon: Icons.insights_outlined,
                  selectedIcon: Icons.insights_rounded,
                  label: '分析',
                  isSelected: false,
                  onTap: () => _returnToShellWithTab(context, 3),
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

  AutovalidateMode get _detailSearchAutovalidateMode => _detailSearchAutovalidate
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  String? _detailSearchKeywordValidator(String? raw) {
    if (_savedShopKeywordEntryEffective) {
      if ((raw ?? '').trim().isEmpty) {
        const msg = '商品名を入力してください';
        AppInputLimits.detailSearchFieldValidationLog(
          field: 'keyword',
          valid: false,
          reason: msg,
        );
        return msg;
      }
      return AppInputLimits.validateOptionalSearchKeyword(raw);
    }
    final err = AppInputLimits.validateSearchKeyword(raw);
    if (err != null) {
      AppInputLimits.detailSearchFieldValidationLog(
        field: 'keyword',
        valid: false,
        reason: err,
      );
    } else {
      AppInputLimits.detailSearchFieldValidationLog(
        field: 'keyword',
        valid: true,
      );
    }
    return err;
  }

  String? _detailSearchExcludeKeywordValidator(String? raw) {
    final err = AppInputLimits.validateExcludeKeyword(raw);
    if (err != null) {
      AppInputLimits.detailSearchFieldValidationLog(
        field: 'excludeKeyword',
        valid: false,
        reason: err,
      );
    }
    return err;
  }

  String? _detailSearchGenreAuxKeywordValidator(String? raw) {
    final err = AppInputLimits.validateOptionalSearchKeyword(raw);
    if (err != null) {
      AppInputLimits.detailSearchFieldValidationLog(
        field: 'genreAuxKeyword',
        valid: false,
        reason: err,
      );
    }
    return err;
  }

  String? _detailSearchMinCommentValidator(String? raw) {
    final err = AppInputLimits.validateOptionalCountField(
      raw,
      label: '最低コメント数',
    );
    if (err != null) {
      AppInputLimits.detailSearchFieldValidationLog(
        field: 'minCommentCount',
        valid: false,
        reason: err,
      );
    }
    return err;
  }

  bool _validateDetailSearchForm({VoidCallback? refreshSheet}) {
    setState(() => _detailSearchAutovalidate = true);
    final ok = _detailSearchFormKey.currentState?.validate() ?? true;
    refreshSheet?.call();
    return ok;
  }

  String? _validateKeywordSearchInputs() {
    if (_savedShopKeywordEntryEffective) {
      return AppInputLimits.validateSavedShopSearchKeyword(
        _keywordController.text,
      );
    } else {
      final kwErr =
          RakutenKeywordDetailConditionsValidation.validateKeywordTabSearchKeyword(
            _keywordController.text,
          );
      if (kwErr != null) return kwErr;
    }
    return RakutenKeywordDetailConditionsValidation.validateAll(
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
    BuildContext sheetContext, {
    VoidCallback? refreshSheet,
  }) {
    if (!_validateDetailSearchForm(refreshSheet: refreshSheet)) {
      final err = _validateKeywordSearchInputs() ?? '入力内容を確認してください';
      setState(() => _detailSheetFormError = err);
      searchValidationErrorLog(
        screen: 'detailSearch',
        field: 'keyword',
        message: err,
        shownNearField: true,
      );
      return;
    }
    final err = _validateKeywordSearchInputs();
    if (err != null) {
      setState(() => _detailSheetFormError = err);
      searchValidationErrorLog(
        screen: 'detailSearch',
        field: 'keyword',
        message: err,
        shownNearField: true,
      );
      refreshSheet?.call();
      return;
    }
    setState(() => _detailSheetFormError = null);
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
    BuildContext sheetContext, {
    VoidCallback? refreshSheet,
  }) {
    if (!_validateDetailSearchForm(refreshSheet: refreshSheet)) {
      final err = _validateGenreDetailInputs() ?? '入力内容を確認してください';
      setState(() => _detailSheetFormError = err);
      searchValidationErrorLog(
        screen: 'detailSearch',
        field: 'form',
        message: err,
        shownNearField: true,
      );
      return;
    }
    if (_selectedGenreId == null || _selectedGenreId!.trim().isEmpty) {
      const msg = 'ジャンルを選択してください';
      setState(() => _detailSheetFormError = msg);
      searchValidationErrorLog(
        screen: 'detailSearch',
        field: 'genre',
        message: msg,
        shownNearField: false,
      );
      refreshSheet?.call();
      return;
    }
    final err = _validateGenreDetailInputs();
    if (err != null) {
      setState(() => _detailSheetFormError = err);
      searchValidationErrorLog(
        screen: 'detailSearch',
        field: 'price',
        message: err,
        shownNearField: true,
      );
      refreshSheet?.call();
      return;
    }
    setState(() => _detailSheetFormError = null);
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(sheetContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runGenreSearch(screenContext);
    });
  }

  bool _blockRoomTourSearchForSnack(String blockedAction) {
    final bulk = context.read<BulkOperationStateController>();
    if (!bulk.isRoomTourSearchBlocking) return false;
    roomSyncUiGuardLog(
      'blockedAction=$blockedAction currentJob=${bulk.roomTourBlockingJobLabel} '
      'message=searchPaused',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          BulkOperationStateController.roomTourSearchBlockedUserMessage,
        ),
      ),
    );
    return true;
  }

  void _runSearch(BuildContext context) {
    if (_blockRoomTourSearchForSnack('search')) return;
    FocusScope.of(context).unfocus();
    _dismissKeywordSearchKeyboard();
    if (_savedShopKeywordEntryEffective) {
      final scopedShop = _effectiveShopCodeForApi(context);
      final keyword = _keywordController.text;
      final validation = AppInputLimits.validateSavedShopSearch(
        shopSelected: scopedShop != null,
        keyword: keyword,
      );
      AppInputLimits.logSavedShopSearchValidation(
        shopSelected: scopedShop != null,
        keyword: keyword,
        result: validation,
      );
      if (!validation.valid) {
        AppInputLimits.logSavedShopSearchBlocked(reason: validation.reason);
        setState(() => _savedShopSearchFieldError = validation.message);
        return;
      }
      setState(() => _savedShopSearchFieldError = null);
    }
    final detailError = _validateKeywordSearchInputs();
    if (detailError != null) {
      if (_savedShopKeywordEntryEffective) {
        setState(() => _savedShopSearchFieldError = detailError);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detailError)));
      return;
    }
    setState(() {
      _selectedProductIds.clear();
      _searchHeaderCollapsed = true;
    });
    if (kDebugMode) {
      _logSearchKeyboardLayoutAudit(
        keyboardVisible: false,
        phase: SearchSurfacePhase.loading,
        errorCardCompact: false,
        context: context,
      );
      debugPrint(
        '[SEARCH_LAYOUT_STABILITY] phase=loading keyboardVisible=false overflowGuard=true',
      );
    }
    _logSearchModeStateAudit(event: 'beforeSearch', context: context);
    final condition = _buildProductCondition(context);
    final managedProv = context.read<RakutenManagedProductProvider>();
    final excludeIds = managedProv.productIdsExcludedFromKeywordSearch();
    final excludeCandidateIds =
        managedProv.candidateProductIdsExcludedFromKeywordSearch();
    final excludeDoneIds = managedProv.doneProductIdsExcludedFromKeywordSearch();
    final savedShopCodes = context
        .read<SavedShopProvider>()
        .shops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final scopedShopFilter = _effectiveShopCodeForApi(context);
    final excludeSavedForKeywordPass =
        _savedShopKeywordEntryEffective && scopedShopFilter != null
        ? savedShopCodes.difference({scopedShopFilter})
        : savedShopCodes;
    if (kDebugMode) {
      final c = condition;
      if (_savedShopKeywordEntryEffective) {
        debugPrint(
          '[SAVED_SHOP_SEARCH_PARAMS] shopCode=${c.shopCode ?? '-'} '
          'keyword="${c.keyword}" genreId=${c.genreId ?? '-'} '
          'minPrice=${c.minPrice ?? '-'} maxPrice=${c.maxPrice ?? '-'}',
        );
      }
      debugPrint(
        '[Rakuten] keyword search execute keyword="${c.keyword}" '
        'genreId=${c.genreId ?? '-'} '
        'genreName(lookup)=${_labelForGenre(c.genreId) ?? '-'} '
        'shopCode=${c.shopCode ?? '-'} '
        'shopName(saved lookup)=${_savedShopNameForLog(context, c.shopCode)} hits=30 '
        'excludeRegistered=${excludeIds.length} '
        'savedShopExcludeSet=${excludeSavedForKeywordPass.length} ',
      );
      if (_savedShopKeywordEntryEffective) {
        debugPrint(
          '[SAVED_SHOP_SEARCH] apiShopCode=${c.shopCode ?? '-'} '
          'keyword="${c.keyword}" itemCode=${c.itemCode ?? '-'}',
        );
      }
    }
    searchTabUiAuditLog(
      'screen=${_savedShopKeywordEntryEffective ? 'savedShopSearch' : 'productSearch'} '
      'hasGenreDrilldown=true hasSelectAllCheckbox=true hasInputLimits=true '
      'hasSafetyFilter=true hasFixedFooter=true',
    );
    final modeTag = _savedShopKeywordEntryEffective ? 'savedShop' : 'product';
    final searchProv = context.read<RakutenSearchProvider>();
    final sessionId = searchProv.beginSearchSession(modeTag: modeTag);
    searchProv.clearErrorForNewSearch(modeTag: modeTag, requestId: sessionId);
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_EXECUTE_TRACE] sessionId=$sessionId mode=$modeTag '
        'keyword="${condition.keyword}" selectedShopCode=${condition.shopCode ?? '-'} '
        'genreId=${condition.genreId ?? '-'} startedAt=${DateTime.now().toIso8601String()}',
      );
    }
    unawaited(
      searchProv.searchWithCondition(
        condition,
        excludeRegisteredProductIds: excludeIds,
        excludeCandidateProductIds: excludeCandidateIds,
        excludeDoneProductIds: excludeDoneIds,
        excludeSavedShopCodes: excludeSavedForKeywordPass,
        sessionId: sessionId,
        modeTag: modeTag,
      ),
    );
  }

  RakutenProductSearchCondition _buildProductCondition(BuildContext context) {
    final raw = RakutenProductSearchCondition(
      keyword: _keywordController.text,
      minPrice: _parseInt(_minPriceController.text),
      maxPrice: _parseInt(_maxPriceController.text),
      excludeKeyword: _excludeKeywordController.text,
      minReviewCount: _parseInt(_minReviewCountController.text),
      minReviewAverage: _parseDouble(_minReviewAverageController.text),
      minCommentCount: _parseInt(_minCommentCountController.text),
      shopCode: _effectiveShopCodeForApi(context),
      genreId: _savedShopKeywordEntryEffective ? null : _productDetailGenreId,
      sort: _apiSortParamForMode(_keywordSort),
    ).normalized();
    return _sanitizeConditionForActiveMode(context, raw);
  }

  /// 保存ショップモード専用: 保存済ショップに存在する [shopId] だけを API の shopCode として渡す。
  String? _effectiveShopCodeForApi(BuildContext context) {
    if (!_savedShopKeywordEntryEffective) return null;
    final scoped = _analyticsScopedShopCode?.trim();
    if (scoped != null && scoped.isNotEmpty) return scoped;
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

  RakutenProductSearchCondition _sanitizeConditionForActiveMode(
    BuildContext context,
    RakutenProductSearchCondition raw,
  ) {
    final beforeKw = raw.keyword;
    final beforeG = raw.genreId ?? '-';
    final beforeS = raw.shopCode ?? '-';
    final removed = <String>[];
    late final RakutenProductSearchCondition out;
    if (_savedShopKeywordEntryEffective) {
      out = RakutenProductSearchCondition(
        keyword: raw.keyword,
        minPrice: raw.minPrice,
        maxPrice: raw.maxPrice,
        excludeKeyword: raw.excludeKeyword,
        minReviewCount: raw.minReviewCount,
        minReviewAverage: raw.minReviewAverage,
        minCommentCount: raw.minCommentCount,
        shopCode: _effectiveShopCodeForApi(context),
        genreId: null,
        sort: raw.sort,
      ).normalized();
      if (beforeG != '-') removed.add('genreId');
    } else if (_mode == _RakutenSearchMode.genre) {
      out = RakutenProductSearchCondition(
        keyword: raw.keyword,
        minPrice: raw.minPrice,
        maxPrice: raw.maxPrice,
        excludeKeyword: raw.excludeKeyword,
        minReviewCount: raw.minReviewCount,
        minReviewAverage: raw.minReviewAverage,
        minCommentCount: raw.minCommentCount,
        shopCode: null,
        genreId: _selectedGenreId,
        sort: raw.sort,
      ).normalized();
      if (beforeS != '-') removed.add('shopCode');
    } else if (_mode == _RakutenSearchMode.shopDiscovery) {
      out = raw;
    } else {
      out = RakutenProductSearchCondition(
        keyword: raw.keyword,
        minPrice: raw.minPrice,
        maxPrice: raw.maxPrice,
        excludeKeyword: raw.excludeKeyword,
        minReviewCount: raw.minReviewCount,
        minReviewAverage: raw.minReviewAverage,
        minCommentCount: raw.minCommentCount,
        shopCode: null,
        genreId: _productDetailGenreId,
        sort: raw.sort,
      ).normalized();
      if (beforeS != '-') removed.add('shopCode');
      if (beforeG != '-' && (_productDetailGenreId == null || _productDetailGenreId!.isEmpty)) {
        removed.add('genreId');
      }
    }
    final n = out.normalized();
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_FILTER_SANITIZE_AUDIT] mode=${_searchResultScreenTag()} '
        'beforeKeyword=$beforeKw beforeGenreId=$beforeG beforeShopCode=$beforeS '
        'afterKeyword=${n.keyword} afterGenreId=${n.genreId ?? '-'} '
        'afterShopCode=${n.shopCode ?? '-'} removedFields=${removed.isEmpty ? '-' : removed.join(',')}',
      );
    }
    return n;
  }

  void _logSearchModeStateAudit({
    required String event,
    required BuildContext context,
    String? sourceMode,
  }) {
    if (!kDebugMode) return;
    final savedName = _savedShopKeywordEntryEffective
        ? (_savedShopNameForLog(context, _selectedShopCode))
        : '-';
    debugPrint(
      '[SEARCH_MODE_STATE_AUDIT] event=$event mode=${_searchResultScreenTag()} '
      'sourceMode=${sourceMode ?? '-'} '
      'keyword=${_keywordController.text.trim().isEmpty ? '-' : _keywordController.text.trim()} '
      'genreId=${_selectedGenreId ?? '-'} '
      'genreName=${_labelForGenre(_selectedGenreId) ?? '-'} '
      'productDetailGenreId=${_productDetailGenreId ?? '-'} '
      'savedShopCode=${_savedShopKeywordEntryEffective ? (_selectedShopCode ?? '-') : '-'} '
      'savedShopName=$savedName '
      'discoveryKeyword=${_shopDiscoveryKeywordController.text.trim().isEmpty ? '-' : _shopDiscoveryKeywordController.text.trim()} '
      'discoveryGenreId=${_selectedDiscoveryGenreId ?? '-'} '
      'sort=${_mode == _RakutenSearchMode.genre ? _genreExploreSort.name : _keywordSort.name}',
    );
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

  Future<void> _openSavedShopKeywordShopPicker(
    BuildContext context,
    SavedShopProvider savedProv,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final shops = _sanitizedSavedShopsForSearch(savedProv.shops);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                ...shops.map(
                  (s) => ListTile(
                    title: Text(s.shopName),
                    subtitle: Text(
                      s.shopId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: _selectedShopCode == s.shopId
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.accentPrimary,
                          )
                        : null,
                    onTap: () {
                      _setSelectedShopCode(context, s.shopId);
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.bookmarks_outlined),
                  title: const Text('保存ショップを管理'),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SavedShopsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedShopEmptyState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.screenPadH,
        RakutenSearchScreenUi.gapDeckOuterTop,
        RakutenSearchScreenUi.screenPadH,
        RakutenSearchScreenUi.gapDeckOuterBottom,
      ),
      child: AppScreenEmptyCenter(
        icon: Icons.bookmarks_outlined,
        title: '保存ショップはまだありません',
        body: 'ショップ発掘などでショップを保存すると、ここから店内検索に使えます。',
        actions: [
          AppPrimaryButton(
            label: 'ショップ発掘を開く',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RakutenSearchScreen(
                    initialMode: RakutenSearchInitialMode.shopDiscovery,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedShopInput(
    BuildContext context,
    RakutenSearchProvider search,
    SavedShopProvider savedProv,
  ) {
    _logSavedShopKeywordRebuildAudit();
    final loading = search.status == RakutenSearchStatus.loading;
    final shops = _sanitizedSavedShopsForSearch(savedProv.shops);
    final scoped = _effectiveShopCodeForApi(context);
    final disabledReason = _savedShopSearchDisabledReason(context, loading);
    final canSearch =
        _savedShopSearchCanSubmit && disabledReason == null && !loading;
    final keywordEmpty = _keywordController.text.trim().isEmpty;
    _logSavedShopSearchUxAudit(
      selectedShop: scoped != null,
      keywordEmpty: keywordEmpty,
      searchEnabled: canSearch,
      disabledReason: disabledReason,
    );
    if (kDebugMode) {
      final picked = scoped != null ? savedProv.findById(scoped) : null;
      debugPrint(
        '[SAVED_SHOP_SEARCH_STATE] selectedShopCode=${scoped ?? '-'} '
        'selectedShopName=${picked?.shopName ?? '-'} keyword=${_keywordController.text.trim()} '
        'canSearch=$canSearch disabledReason=${disabledReason ?? '-'}',
      );
    }

    if (scoped == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '保存済みショップから検索対象のショップを選択してください。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (shops.isEmpty) ...[
            Text(
              '保存済みショップがありません。ショップ発掘から保存できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _onSegmentChanged(SearchModeSegment.shopDiscovery),
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('ショップを発掘する'),
              ),
            ),
          ] else
            AppPrimaryButton(
              label: 'ショップを選択',
              icon: const Icon(Icons.storefront_outlined, size: 20),
              height: 48,
              onPressed: () =>
                  _openSavedShopKeywordShopPicker(context, savedProv),
            ),
        ],
      );
    }

    final picked = savedProv.findById(scoped);
    final shopLabel = picked?.shopName.trim().isNotEmpty == true
        ? picked!.shopName.trim()
        : scoped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '選択中のショップ',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: HomeScreenColors.metricTileTitleColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                shopLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  _openSavedShopKeywordShopPicker(context, savedProv),
              child: const Text('変更'),
            ),
          ],
        ),
        SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
        Text(
          'キーワード',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: HomeScreenColors.metricTileTitleColor,
          ),
        ),
        const SizedBox(height: 4),
        AppTextField(
          key: const ValueKey<String>('saved_shop_keyword_field'),
          controller: _keywordController,
          focusNode: _savedShopKeywordFocusNode,
          hintText: '例：さかな、干物、ギフト',
          textInputAction: TextInputAction.search,
          onTap: () => _logSavedShopKeywordFocusAudit(event: 'tap'),
          onSubmitted: canSearch ? (_) => _runSearch(context) : null,
        ),
        if (_savedShopSearchFieldError != null) ...[
          const SizedBox(height: 4),
          Text(
            _savedShopSearchFieldError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ] else if (disabledReason != null &&
            disabledReason != 'キーワードを入力してください') ...[
          const SizedBox(height: 4),
          Text(
            disabledReason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openProductConditionsSheet(context),
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: const Text('条件を変更'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentPrimary,
            side: BorderSide(color: AppColors.accentPrimary),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapBeforePrimaryCta),
        AppPrimaryButton(
          label: 'このショップで探す',
          icon: const Icon(Icons.search_rounded, size: 22),
          onPressed: canSearch ? () => _runSearch(context) : null,
        ),
      ],
    );
  }

  Widget _buildPostSearchCompactSetupBar(
    BuildContext context,
    RakutenSearchProvider search,
    SavedShopProvider savedProv,
  ) {
    final summaryLines = _searchResultConditionSummaryLines(context);
    if (kDebugMode) {
      _logSearchResultConditionSummaryAudit(context);
      _logSearchHeaderActionAudit(hasResults: true);
      if (_savedShopKeywordEntryEffective) {
        final shopCode = _effectiveShopCodeForApi(context);
        debugPrint(
          '[SAVED_SHOP_HEADER_UI_AUDIT] selectedShopCode=${shopCode ?? '-'} '
          'selectedShopName=${_savedShopNameForLog(context, shopCode)} '
          'duplicateGuideTextCount=0 primaryButtonStyleAligned=true '
          'resultHeaderShowsShopName=${summaryLines.isNotEmpty && summaryLines.first.startsWith('保存ショップ')}',
        );
      }
      debugPrint(
        '[SEARCH_RESULT_HEADER_RENDER] screen=${_searchResultScreenTag()} '
        'resultCount=${search.results.length} hasLongDescription=false '
        'actions=changeCondition,sort,retry',
      );
    }
    final sortMode = _mode == _RakutenSearchMode.genre
        ? _genreExploreSort
        : _keywordSort;
    final onSort = _mode == _RakutenSearchMode.genre
        ? (RakutenKeywordSearchSortMode next) =>
            _onGenreSortChanged(context, next)
        : (RakutenKeywordSearchSortMode next) =>
            _onKeywordSortChanged(context, next);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.screenPadH,
        4,
        RakutenSearchScreenUi.screenPadH,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInlineBackButton(context),
          const SizedBox(height: 4),
          SearchModeSegmentBar(
            selected: _currentSearchModeSegment(),
            onChanged: _onSegmentChanged,
          ),
          const SizedBox(height: 6),
          Material(
            color: HomeScreenColors.roomContentWellFill,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => _openConditionsForCurrentMode(context),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in summaryLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: HomeScreenColors.metricTileTitleColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openConditionsForCurrentMode(context),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('条件変更'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.accentPrimary,
                  side: BorderSide(color: AppColors.accentPrimary),
                ),
              ),
              if (_sortLivesInResultsHeader(search))
                _buildResultSortActionChip(
                  context,
                  value: sortMode,
                  onSortSelected: onSort,
                ),
              OutlinedButton.icon(
                onPressed: _isBulkRegistering
                    ? null
                    : () => _rerunSearchForCurrentMode(context),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('再検索'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: HomeScreenColors.leadOnSection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeAndInputArea(
    BuildContext context,
    RakutenSearchProvider search,
    SavedShopProvider savedProv,
  ) {
    final shops = _sanitizedSavedShopsForSearch(savedProv.shops);
    if (_savedShopKeywordEntryEffective && shops.isEmpty) {
      return _buildSavedShopEmptyState(context);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.screenPadH,
        RakutenSearchScreenUi.gapDeckOuterTop,
        RakutenSearchScreenUi.screenPadH,
        RakutenSearchScreenUi.gapDeckOuterBottom,
      ),
      child: AppCard(
        // 共通AppCardへ置換: 検索条件デッキのカード外観を共通化。
        padding: EdgeInsets.zero,
        backgroundColor: HomeScreenColors.roomGroupedShellFill,
        borderColor: HomeScreenColors.sectionOutlineNeutral,
        radius: RakutenSearchScreenUi.radiusSectionOuter,
        elevated: true,
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
                                  _buildInlineBackButton(context),
                                  if (Navigator.of(context).canPop())
                                    const SizedBox(
                                      height: RakutenSearchScreenUi.gapFieldStack,
                                    ),
                  SearchModeSegmentBar(
                    selected: _currentSearchModeSegment(),
                    onChanged: _onSegmentChanged,
                  ),
                  SizedBox(
                    height: RakutenSearchScreenUi.gapKeywordToControls - 1,
                  ),
                  switch (_mode) {
                    _RakutenSearchMode.product =>
                      _savedShopKeywordEntryEffective
                          ? _buildSavedShopInput(context, search, savedProv)
                          : _buildProductInput(context, search),
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
        if (!_sortLivesInResultsHeader(search)) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _buildResultSortControl(
              context,
              value: _keywordSort,
              resultsScrollController: _keywordResultsScrollController,
              onSortSelected: (next) => _onKeywordSortChanged(context, next),
            ),
          ),
          SizedBox(height: RakutenSearchScreenUi.gapSortToFields),
        ],
        _buildUnifiedSearchControls(
          context,
          detailEntry: RakutenSearchPseudoSearchFieldEntry(
            controller: _keywordController,
            onTap: () => _openProductConditionsSheet(context),
            labelText: 'キーワード',
            hintText: '例：水筒 / イヤホン / バッグ',
            prefixIcon: Icons.search_rounded,
          ),
          onClear: () {
            _dismissKeywordSearchKeyboard();
            _clearConditionsForCurrentMode();
          },
        ),
        SizedBox(height: RakutenSearchScreenUi.gapBeforePrimaryCta),
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
        if (!_sortLivesInResultsHeader(search)) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _buildResultSortControl(
              context,
              value: _genreExploreSort,
              resultsScrollController: _genreResultsScrollController,
              onSortSelected: (next) => _onGenreSortChanged(context, next),
            ),
          ),
          SizedBox(height: RakutenSearchScreenUi.gapSortToFields),
        ],
        _buildUnifiedSearchControls(
          context,
          detailEntry: RakutenSearchPseudoGenreDropdownEntry(
            labelText: '検索ジャンル（必須）',
            displayText:
                _selectedGenreId == null || _selectedGenreId!.trim().isEmpty
                ? 'ジャンルを選択してください（必須）'
                : _genreUiLabelForId(_selectedGenreId),
            onTap: () => _openProductConditionsSheet(context),
          ),
          onClear: _clearConditionsForCurrentMode,
        ),
        SizedBox(height: RakutenSearchScreenUi.gapBeforePrimaryCta),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '新しいショップを見つけて保存するためのモードです。保存済みショップの商品一覧専用ではありません。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: HomeScreenColors.groupedSectionBody,
            height: 1.38,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        RakutenSearchPseudoSearchFieldEntry(
          controller: _shopDiscoveryKeywordController,
          onTap: () => _openShopDiscoveryConditionsSheet(context),
          labelText: 'キーワード',
          hintText: '例: おしゃれ 家具',
          prefixIcon: Icons.search_rounded,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedShopsScreen(),
                ),
              );
            },
            child: const Text('保存ショップ一覧'),
          ),
        ),
        SizedBox(height: RakutenSearchScreenUi.gapBeforePrimaryCta),
        SizedBox(
          height: 52,
          child: AppPrimaryButton(
            // 共通AppPrimaryButtonへ置換: ショップ発掘の主CTA。
            label: 'ショップを探す',
            icon: const Icon(Icons.travel_explore_rounded, size: 22),
            onPressed: search.status == RakutenSearchStatus.loading
                ? null
                : () => _runShopDiscovery(context),
          ),
        ),
      ],
    );
  }

  SearchModeSegment _currentSearchModeSegment() {
    if (_savedShopKeywordEntryEffective) {
      return SearchModeSegment.savedShop;
    }
    return switch (_mode) {
      _RakutenSearchMode.product => SearchModeSegment.product,
      _RakutenSearchMode.genre => SearchModeSegment.genre,
      _RakutenSearchMode.shopDiscovery => SearchModeSegment.shopDiscovery,
    };
  }

  void _onSegmentChanged(SearchModeSegment seg) {
    final way = switch (seg) {
      SearchModeSegment.product => _SearchWayPicker.product,
      SearchModeSegment.genre => _SearchWayPicker.genre,
      SearchModeSegment.savedShop => _SearchWayPicker.savedShop,
      SearchModeSegment.shopDiscovery => _SearchWayPicker.shopDiscovery,
    };
    _onSearchWayPicked(way);
  }

  void _onSearchWayPicked(_SearchWayPicker way) {
    if (_mode == _RakutenSearchMode.product &&
        way != _SearchWayPicker.savedShop &&
        !_savedShopKeywordEntryEffective) {
      _dismissKeywordSearchKeyboard();
    }
    final fromMode = _mode.name;
    final fromSavedShop = _savedShopKeywordFlow;
    _saveCurrentSearchSession();
    setState(() {
      _savedShopKeywordFlow = way == _SearchWayPicker.savedShop;
      _mode = switch (way) {
        _SearchWayPicker.product => _RakutenSearchMode.product,
        _SearchWayPicker.genre => _RakutenSearchMode.genre,
        _SearchWayPicker.savedShop => _RakutenSearchMode.product,
        _SearchWayPicker.shopDiscovery => _RakutenSearchMode.shopDiscovery,
      };
      _selectedProductIds.clear();
      if (way == _SearchWayPicker.savedShop) {
        _selectedGenreId = null;
        _productDetailGenreId = null;
      }
      if (way == _SearchWayPicker.product) {
        _selectedGenreId = null;
      }
      if (way == _SearchWayPicker.genre) {
        _selectedShopCode = null;
        _productDetailGenreId = null;
      }
      if (way == _SearchWayPicker.shopDiscovery) {
        _selectedShopCode = null;
        _selectedGenreId = null;
        _productDetailGenreId = null;
      }
      _searchHeaderCollapsed = true;
    });
    _restoreSearchSession(_modeCacheKey());
    if (mounted) {
      context.read<RakutenSearchProvider>().clearErrorIfModeMismatch(
        _providerModeTag(),
      );
    }
    if (kDebugMode) {
      final from = fromSavedShop ? 'savedShop' : fromMode;
      debugPrint(
        '[SEARCH_MODE_SWITCH] from=$from to=${way.name} previousResultKept=true',
      );
    }
    _logSearchModeStateAudit(
      event: 'switch',
      context: context,
      sourceMode: fromSavedShop ? 'savedShop' : fromMode,
    );
  }

  void _onModeChanged(_RakutenSearchMode next) {
    if (_mode == next && !_savedShopKeywordEntryEffective) return;
    _onSearchWayPicked(switch (next) {
      _RakutenSearchMode.product => _savedShopKeywordFlow
          ? _SearchWayPicker.savedShop
          : _SearchWayPicker.product,
      _RakutenSearchMode.genre => _SearchWayPicker.genre,
      _RakutenSearchMode.shopDiscovery => _SearchWayPicker.shopDiscovery,
    });
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
        _keywordController.clear();
        _productDetailGenreId = null;
      }
      if (_mode == _RakutenSearchMode.genre) {
        _genreController.clear();
        _selectedGenreId = null;
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
      _productDetailGenreId = null;
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

  Widget _buildUnifiedSearchControls(
    BuildContext context, {
    required Widget detailEntry,
    required VoidCallback onClear,
  }) {
    // 条件入力と補助操作を同列に置きつつ、条件クリアは軽いTextButtonにして入力欄と誤認させない。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: detailEntry),
        const SizedBox(width: 6),
        AppSecondaryButton(
          label: '条件クリア',
          onPressed: onClear,
          icon: Icon(
            Icons.restart_alt_rounded,
            size: 16,
            color: HomeScreenColors.groupedSectionBody,
          ),
          height: 40,
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
      child: AppPrimaryButton(
        label: label,
        icon: const Icon(Icons.search_rounded, size: 22),
        onPressed: onPressed,
      ),
    );
  }

  /// 詳細シートで「最初に触る欄」へ視線を集める枠（モーダル内のみ）。
  Widget _sheetPrimaryAttentionShell({required Widget child}) {
    final r = RakutenSearchScreenUi.searchFieldBorderRadius + 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: HomeScreenColors.sectionOutlineAccent.withValues(alpha: 0.85),
          width: 1.5,
        ),
        color: AppColors.accentLight.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: HomeScreenColors.sectionOutlineAccent.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }

  Future<void> _openProductConditionsSheet(BuildContext screenContext) async {
    if (_mode == _RakutenSearchMode.product) {
      _dismissKeywordSearchKeyboard();
    }
    _syncSelectedShopWithSaved(screenContext);
    _detailSheetFormError = null;
    _detailSearchAutovalidate = false;
    AppInputLimits.logDetailSearchSheetLimitsApplied();
    await showModalBottomSheet<void>(
      context: screenContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        searchFilterSheetLayoutLog();
        final sheetKeyboardInset = MediaQuery.of(screenContext).viewInsets.bottom;
        searchFilterSheetOverflowGuardLog(keyboardInset: sheetKeyboardInset);
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final sheetInset = MediaQuery.of(sheetContext).viewInsets.bottom;
            final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.9;
            return Material(
              color: HomeScreenColors.canvas,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(bottom: sheetInset),
                  child: SizedBox(
                    height: sheetHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  _mode == _RakutenSearchMode.product
                                      ? '条件検索'
                                      : 'ジャンル探索',
                                  textAlign: TextAlign.center,
                                  style: RakutenSearchScreenUi
                                      .sectionHeadingAccent(context),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (_mode == _RakutenSearchMode.product) {
                                    _clearKeywordDetailConditionsOnly();
                                  } else {
                                    _clearGenreDetailConditionsOnly();
                                  }
                                  setState(() => _detailSheetFormError = null);
                                  setModalState(() {});
                                },
                                child: const Text('クリア'),
                              ),
                            ],
                          ),
                        ),
                        if (_detailSheetFormError != null &&
                            _detailSheetFormError!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                _detailSheetFormError!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(
                              RakutenSearchScreenUi.sheetPadH,
                              0,
                              RakutenSearchScreenUi.sheetPadH,
                              12,
                            ),
                            child: Form(
                              key: _detailSearchFormKey,
                              autovalidateMode: _detailSearchAutovalidateMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                        Text(
                          _mode == _RakutenSearchMode.product
                              ? 'キーワードと条件を編集します。'
                              : 'ジャンル（必須）を選択してください。',
                          style: RakutenSearchScreenUi.sheetIntroBody(context),
                        ),
                        if (_mode == _RakutenSearchMode.genre) ...[
                          const SizedBox(
                            height: RakutenSearchScreenUi.sheetBlockGap,
                          ),
                          RakutenSearchGenreDrilldownRow(
                            selectedGenreId: _selectedGenreId,
                            requiredSelection: true,
                            introText: 'ジャンル（必須）を選んでから検索します。',
                            onGenreChanged: (value) {
                              _setSelectedGenreId(value);
                              setModalState(() {});
                            },
                          ),
                          SizedBox(
                            height: RakutenSearchScreenUi.gapFieldStack + 3,
                          ),
                          AppTextField(
                            // 共通AppTextFieldへ置換: ジャンル探索の補助キーワード入力。
                            controller: _genreController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) =>
                                _submitGenreSearchFromDetailSheet(
                                  screenContext,
                                  sheetContext,
                                  refreshSheet: () => setModalState(() {}),
                                ),
                            onChanged: (_) => setModalState(() {}),
                            labelText: '補助キーワード（任意）',
                            hintText: '例: 収納 ボックス',
                            prefixIcon: const Icon(Icons.search_rounded),
                            maxLength: AppInputLimits.searchKeywordMax,
                            inputFormatters:
                                AppInputLimits.singleLineKeywordFormatters(),
                            autovalidateMode: _detailSearchAutovalidateMode,
                            validator: _detailSearchGenreAuxKeywordValidator,
                          ),
                          const SizedBox(
                            height: RakutenSearchScreenUi.sheetBlockGap,
                          ),
                        ] else ...[
                          const SizedBox(
                            height: RakutenSearchScreenUi.sheetBlockGap,
                          ),
                          _PostFrameFocusRequester(
                            focusNode: _productDetailSheetKeywordFocus,
                            child: _sheetPrimaryAttentionShell(
                              child: AppTextField(
                                // 共通AppTextFieldへ置換: 商品検索の主キーワード入力。
                                controller: _keywordController,
                                focusNode: _productDetailSheetKeywordFocus,
                                autofocus: false,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) =>
                                    _submitKeywordSearchFromDetailSheet(
                                      screenContext,
                                      sheetContext,
                                      refreshSheet: () => setModalState(() {}),
                                    ),
                                onChanged: (_) => setModalState(() {}),
                                labelText: 'キーワード（必須）',
                                hintText: '例: ステンレス ボトル',
                                prefixIcon: const Icon(Icons.search_rounded),
                                maxLength: AppInputLimits.searchKeywordMax,
                                inputFormatters:
                                    AppInputLimits.singleLineKeywordFormatters(),
                                autovalidateMode: _detailSearchAutovalidateMode,
                                validator: _detailSearchKeywordValidator,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: RakutenSearchScreenUi.sheetBlockGap,
                          ),
                        ],
                        RakutenSearchPriceRangeRow(
                          minPriceController: _minPriceController,
                          maxPriceController: _maxPriceController,
                          autovalidateMode: _detailSearchAutovalidateMode,
                          onFieldChanged: () {
                            setModalState(() {});
                            _detailSearchFormKey.currentState?.validate();
                          },
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        AppTextField(
                          // 共通AppTextFieldへ置換: 除外ワード入力。
                          controller: _excludeKeywordController,
                          onChanged: (_) => setModalState(() {}),
                          labelText: '除外ワード（任意）',
                          hintText: '中古 訳あり',
                          prefixIcon: const Icon(Icons.block_outlined),
                          maxLength: AppInputLimits.searchKeywordMax,
                          inputFormatters:
                              AppInputLimits.singleLineKeywordFormatters(),
                          autovalidateMode: _detailSearchAutovalidateMode,
                          validator: _detailSearchExcludeKeywordValidator,
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
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
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        AppTextField(
                          // 共通AppTextFieldへ置換: 最低コメント数入力。
                          controller: _minCommentCountController,
                          keyboardType: TextInputType.number,
                          maxLength: AppInputLimits.countFieldMaxDigits,
                          inputFormatters:
                              AppInputLimits.countDigitsFormatters(),
                          autovalidateMode: _detailSearchAutovalidateMode,
                          validator: _detailSearchMinCommentValidator,
                          onChanged: (_) => setModalState(() {}),
                          labelText: '最低コメント数（任意）',
                          hintText: '30',
                          prefixIcon: const Icon(Icons.comment_outlined),
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
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
                          const SizedBox(
                            height: RakutenSearchScreenUi.sheetBlockGap,
                          ),
                          RakutenSearchGenreDrilldownRow(
                            selectedGenreId: _productDetailGenreId,
                            onGenreChanged: (value) {
                              _setProductDetailGenreId(value);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            RakutenSearchScreenUi.sheetPadH,
                            8,
                            RakutenSearchScreenUi.sheetPadH,
                            12,
                          ),
                          child: Consumer<RakutenSearchProvider>(
                            builder: (context, search, _) {
                              final loading =
                                  search.status == RakutenSearchStatus.loading;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (loading)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: LinearProgressIndicator(
                                        minHeight: 3,
                                      ),
                                    ),
                                  AppPrimaryButton(
                                    label: '検索する',
                                    icon: const Icon(
                                      Icons.search_rounded,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      if (_mode == _RakutenSearchMode.product) {
                                        _submitKeywordSearchFromDetailSheet(
                                          screenContext,
                                          sheetContext,
                                          refreshSheet: () =>
                                              setModalState(() {}),
                                        );
                                      } else {
                                        _submitGenreSearchFromDetailSheet(
                                          screenContext,
                                          sheetContext,
                                          refreshSheet: () =>
                                              setModalState(() {}),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    child: const Text('閉じる'),
                                  ),
                                ],
                              );
                            },
                          ),
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
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openShopDiscoveryConditionsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Material(
              color: HomeScreenColors.canvas,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.sheetPadH,
                    10,
                    RakutenSearchScreenUi.sheetPadH,
                    16,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: sheetInset + 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ショップ発掘',
                          style: RakutenSearchScreenUi.sectionHeadingAccent(
                            context,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'キーワードまたはジャンルを指定してください。',
                          style: RakutenSearchScreenUi.sheetIntroBody(context),
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        _PostFrameFocusRequester(
                          focusNode: _discoveryDetailSheetKeywordFocus,
                          child: _sheetPrimaryAttentionShell(
                            child: AppTextField(
                              // 共通AppTextFieldへ置換: ショップ発掘キーワード入力。
                              controller: _shopDiscoveryKeywordController,
                              focusNode: _discoveryDetailSheetKeywordFocus,
                              autofocus: false,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setModalState(() {}),
                              labelText: 'キーワード',
                              hintText: '例: おしゃれ 家具',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        RakutenSearchGenreDrilldownRow(
                          selectedGenreId: _selectedDiscoveryGenreId,
                          onGenreChanged: (value) {
                            genreUiAuditLog(
                              'screen=shopDiscovery oldDropdownVisible=false '
                              'drilldownVisible=true genreId=${value ?? '-'} '
                              'genreName=${_labelForGenre(value) ?? '-'}',
                            );
                            setState(() => _selectedDiscoveryGenreId = value);
                            setModalState(() {});
                          },
                          introText: 'カテゴリを絞り込む',
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        AppTextField(
                          // 共通AppTextFieldへ置換: ショップ発掘除外ワード入力。
                          controller: _shopDiscoveryExcludeController,
                          labelText: '除外ワード',
                          hintText: '例: 中古 訳あり',
                          prefixIcon: const Icon(Icons.block_outlined),
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                // 共通AppTextFieldへ置換: 最低評価数入力。
                                controller:
                                    _shopDiscoveryMinReviewCountController,
                                keyboardType: TextInputType.number,
                                labelText: '最低評価数',
                                hintText: '100',
                                prefixIcon: const Icon(Icons.reviews_outlined),
                              ),
                            ),
                            SizedBox(
                              width: RakutenSearchScreenUi.gapFieldStack,
                            ),
                            Expanded(
                              child: AppTextField(
                                // 共通AppTextFieldへ置換: 最低評価点入力。
                                controller:
                                    _shopDiscoveryMinReviewAverageController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                labelText: '最低評価点',
                                hintText: '4.2',
                                prefixIcon: const Icon(
                                  Icons.star_outline_rounded,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                // 共通AppTextFieldへ置換: 表示ショップ数入力。
                                controller: _shopDiscoveryShopLimitController,
                                keyboardType: TextInputType.number,
                                labelText: '表示ショップ数',
                                hintText: '10',
                                prefixIcon: const Icon(
                                  Icons.store_mall_directory_outlined,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: RakutenSearchScreenUi.gapFieldStack,
                            ),
                            Expanded(
                              child: AppTextField(
                                // 共通AppTextFieldへ置換: 1ショップあたり件数入力。
                                controller:
                                    _shopDiscoveryItemsPerShopController,
                                keyboardType: TextInputType.number,
                                labelText: '1ショップあたり表示商品数',
                                hintText: '5',
                                prefixIcon: const Icon(
                                  Icons.view_stream_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: RakutenSearchScreenUi.sheetBlockGap,
                        ),
                        Consumer<RakutenSearchProvider>(
                          builder: (context, search, _) {
                            final loading =
                                search.status == RakutenSearchStatus.loading;
                            final keywordOk = _shopDiscoveryKeywordController
                                .text
                                .trim()
                                .isNotEmpty;
                            final genreOk =
                                _selectedDiscoveryGenreId != null &&
                                _selectedDiscoveryGenreId!.trim().isNotEmpty;
                            final canSearch =
                                !loading && (keywordOk || genreOk);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppPrimaryButton(
                                  // 共通AppPrimaryButtonへ置換: ショップ発掘条件保存CTA。
                                  label: '条件を保存して検索',
                                  icon: const Icon(
                                    Icons.search_rounded,
                                    size: 22,
                                  ),
                                  onPressed: !canSearch
                                      ? null
                                      : () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          Navigator.of(sheetContext).pop();
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (!mounted) return;
                                                _runShopDiscovery(context);
                                              });
                                        },
                                ),
                                const SizedBox(
                                  height: RakutenSearchScreenUi.sheetBlockGap,
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: AppSecondaryButton(
                                        // 共通AppSecondaryButtonへ置換: 閉じる補助操作。
                                        label: '閉じる（検索しない）',
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          Navigator.of(sheetContext).pop();
                                        },
                                        expand: true,
                                        height: 46,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppSecondaryButton(
                                        // 共通AppSecondaryButtonへ置換: 絞り込みリセット補助操作。
                                        label: '絞り込みだけリセット',
                                        icon: const Icon(
                                          Icons.filter_alt_off_outlined,
                                        ),
                                        onPressed: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          _clearConditionsForCurrentMode();
                                          setState(() {});
                                          setModalState(() {});
                                        },
                                        expand: true,
                                        height: 46,
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
    if (!mounted) return;
    setState(() {});
  }

  void _runShopDiscovery(BuildContext context) {
    if (_blockRoomTourSearchForSnack('search')) return;
    final keyword = _shopDiscoveryKeywordController.text.trim();
    final genreId = _selectedDiscoveryGenreId;
    if (keyword.isEmpty && (genreId == null || genreId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ショップ発掘では、キーワードまたはジャンルを指定してください')),
      );
      return;
    }
    if (_shopDiscoveryResultsScrollController.hasClients) {
      _shopDiscoveryResultsScrollController.jumpTo(0);
    }
    setState(() => _searchHeaderCollapsed = true);
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
    final excludeIds = context
        .read<RakutenManagedProductProvider>()
        .productIdsExcludedFromKeywordSearch();
    shopDiscoverySearchParamsLog(
      'genreId=${genreId ?? '-'} genreName=${_labelForGenre(genreId) ?? '-'} '
      'keyword=$keyword page=1 hits=30',
    );
    genreUiAuditLog(
      'screen=shopDiscovery oldDropdownVisible=false drilldownVisible=true '
      'genreId=${genreId ?? '-'} genreName=${_labelForGenre(genreId) ?? '-'}',
    );
    searchTabUiAuditLog(
      'screen=shopDiscovery hasGenreDrilldown=true hasSelectAllCheckbox=true '
      'hasInputLimits=true hasSafetyFilter=true hasFixedFooter=false',
    );
    context.read<RakutenSearchProvider>().searchWithCondition(
      condition,
      excludeRegisteredProductIds: excludeIds,
    );
  }

  String _selectionScreenTag() {
    switch (_mode) {
      case _RakutenSearchMode.product:
        return _savedShopKeywordEntryEffective
            ? 'savedShopSearch'
            : 'productSearch';
      case _RakutenSearchMode.genre:
        return 'genreSearch';
      case _RakutenSearchMode.shopDiscovery:
        return 'shopDiscovery';
    }
  }

  String? _labelForGenre(String? id) {
    if (id == null) return null;
    return RakutenGenreMasterService.instance.genreNameIfKnown(id);
  }

  String _genreUiLabelForId(String? id) {
    if (id == null || id.trim().isEmpty) return 'ジャンルを選択してください';
    for (final o in _mockGenres) {
      if (o.id == id) return o.label;
    }
    return GenreDisplayResolve.labelForGenreId(
      id,
      screen: _genreDisplayScreenKey(),
    );
  }

  String _genreDisplayScreenKey() {
    if (_savedShopKeywordEntryEffective) return 'savedShopSearch';
    switch (_mode) {
      case _RakutenSearchMode.genre:
        return 'genreSearch';
      case _RakutenSearchMode.shopDiscovery:
        return 'shopDiscovery';
      case _RakutenSearchMode.product:
        return 'productSearch';
    }
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

  void _setProductDetailGenreId(String? value) {
    if (kDebugMode) {
      debugPrint(
        '[Rakuten] productDetailGenre selected label=${_genreUiLabelForId(value)} '
        'genreId=${value ?? '(null)'}',
      );
    }
    setState(() => _productDetailGenreId = value);
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

  Future<void> _runGenreSearch(BuildContext context) async {
    if (_blockRoomTourSearchForSnack('search')) return;
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
    _logSearchModeStateAudit(event: 'beforeSearch', context: context);
    final condition = _sanitizeConditionForActiveMode(
      context,
      RakutenProductSearchCondition(
        keyword: _genreController.text,
        minPrice: _parseInt(_minPriceController.text),
        maxPrice: _parseInt(_maxPriceController.text),
        excludeKeyword: _excludeKeywordController.text,
        minReviewCount: _parseInt(_minReviewCountController.text),
        minReviewAverage: _parseDouble(_minReviewAverageController.text),
        minCommentCount: _parseInt(_minCommentCountController.text),
        shopCode: null,
        genreId: _selectedGenreId,
        sort: _apiSortParamForMode(_genreExploreSort),
      ).normalized(),
    );
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
    setState(() => _searchHeaderCollapsed = true);
    final managedProv = context.read<RakutenManagedProductProvider>();
    final excludeIds = managedProv.productIdsExcludedFromKeywordSearch();
    final excludeCandidateIds =
        managedProv.candidateProductIdsExcludedFromKeywordSearch();
    final excludeDoneIds = managedProv.doneProductIdsExcludedFromKeywordSearch();
    final savedShopCodes = context
        .read<SavedShopProvider>()
        .shops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    searchTabUiAuditLog(
      'screen=genreSearch hasGenreDrilldown=true hasSelectAllCheckbox=true '
      'hasInputLimits=true hasSafetyFilter=true hasFixedFooter=true',
    );
    final searchProv = context.read<RakutenSearchProvider>();
    final sessionId = searchProv.beginSearchSession(modeTag: 'genre');
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_EXECUTE_TRACE] sessionId=$sessionId mode=genre '
        'keyword="${condition.keyword}" selectedShopCode=${condition.shopCode ?? '-'} '
        'genreId=${condition.genreId ?? '-'} startedAt=${DateTime.now().toIso8601String()}',
      );
    }
    await searchProv.searchWithCondition(
      condition,
      excludeRegisteredProductIds: excludeIds,
      excludeCandidateProductIds: excludeCandidateIds,
      excludeDoneProductIds: excludeDoneIds,
      excludeSavedShopCodes: savedShopCodes,
      sessionId: sessionId,
      modeTag: 'genre',
    );
  }

  /// 候補済・コレ済の商品や保存済みショップの商品を優先的に除外したリストを返す。
  /// ただし、除外しすぎて極端に件数が減る場合は元のリストをそのまま使う前提で呼び出し元でフォールバックする。
  ///
  /// [searchScopeShopCode] に API 検索で絞り込んだ shopCode があるとき、当該ショップは
  /// 「保存済み」であっても一覧から落とさない（ショップ指定検索の結果が 0 件にならないようにする）。
  String _safetyFilterSourceForMode() {
    switch (_mode) {
      case _RakutenSearchMode.genre:
        return 'genreSearch';
      case _RakutenSearchMode.shopDiscovery:
        return 'shopDiscovery';
      case _RakutenSearchMode.product:
        return _savedShopKeywordEntryEffective
            ? 'savedShopSearch'
            : 'productSearch';
    }
  }

  bool _isSafetyBlockedForSearch(RakutenSearchItem item) {
    final blocked = ProductSafetyFilter.isBlockedProduct(
      itemName: item.itemName,
      shopName: item.shopName,
      genreName: item.genreName,
      itemUrl: item.itemUrl,
      affiliateUrl: item.affiliateUrl,
    );
    if (blocked) {
      ProductSafetyFilter.logFilter(
        source: _safetyFilterSourceForMode(),
        itemCode: item.productId,
        title: item.itemName,
        shopName: item.shopName,
        genreName: item.genreName,
        blocked: true,
        reasons: ProductSafetyFilter.blockedReasons(
          itemName: item.itemName,
          shopName: item.shopName,
          genreName: item.genreName,
        ),
      );
    }
    return blocked;
  }

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
    var exclSafety = 0;
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
      if (_isSafetyBlockedForSearch(item)) {
        exclSafety++;
        continue;
      }
      out.add(item);
    }
    if (kDebugMode) {
      debugPrint(
        '[Rakuten] UI preferred excludes before=${source.length} after=${out.length} '
        'candidateExclude=$exclCandidate doneExclude=$exclDone savedShopExclude=$exclSavedShop '
        'safetyExclude=$exclSafety searchScopeShopCode=${scoped.isEmpty ? '-' : scoped}',
      );
      if (source.length >= 100 && out.length < 100) {
        final reason = exclSafety > 0
            ? 'safetyFiltered'
            : (exclSavedShop > 0
                  ? 'savedShopUiExclude'
                  : 'uiPostFilter');
        debugPrint(
          '[SEARCH_RESULT_UNDER_100_REASON] mode=${_searchResultScreenTag()} '
          'displayCount=${out.length} target=100 reason=$reason '
          'uiSafetyExcluded=$exclSafety apiDisplayBeforeUi=${source.length}',
        );
      }
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

  bool _bulkCheckboxVisible(RakutenSearchProvider search) {
    if (_mode == _RakutenSearchMode.shopDiscovery) return false;
    return search.status == RakutenSearchStatus.success &&
        search.results.isNotEmpty;
  }

  Future<void> _bulkRegisterCandidates(
    RakutenManagedProductProvider managed,
    List<RakutenSearchItem> source,
  ) async {
    if (_isBulkRegistering || _selectedProductIds.isEmpty) return;
    bulkRegisterStartLog(
      mode: 'candidate',
      selectedCount: _selectedProductIds.length,
      sourceScreen: 'rakutenSearch',
    );
    final bulkCtl = context.read<BulkOperationStateController>();
    if (bulkCtl.isRoomTourSearchBlocking) {
      roomSyncUiGuardLog(
        'blockedAction=collectFromSearch currentJob=${bulkCtl.roomTourBlockingJobLabel} '
        'message=searchPaused',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              BulkOperationStateController.roomTourSearchBlockedUserMessage,
            ),
          ),
        );
      }
      return;
    }
    final bulk = bulkCtl;
    if (bulk.isRoomImportRunning ||
        bulk.isMetadataEnriching ||
        bulk.isRoomReactionSyncRunning) {
      bulk.guardBlockingOperations(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補にまとめて追加'),
        content: const Text(
          '選択した商品を候補に追加します。\n登録中は他の商品登録を一時停止します。\nよろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('開始する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (kDebugMode) {
      debugPrint(
        '[OPERATION_CONFIRM_DIALOG] operation=bulkRegister shown=true accepted=true',
      );
    }
    bulk.setBulkCandidateRegistering(true);
    setState(() {
      _isBulkRegistering = true;
      _bulkRegisterProcessed = 0;
      _bulkRegisterTotal = _selectedProductIds.length;
    });
    var success = 0;
    var failed = 0;
    var skipped = 0;
    var alreadyExists = 0;
    var syncBusyBlocked = 0;
    final selectedItems = source
        .where((e) => _selectedProductIds.contains(e.productId))
        .toList(growable: false);
    final selectedSnapshot = List<RakutenSearchItem>.from(selectedItems);
    try {
      for (var i = 0; i < selectedSnapshot.length; i++) {
        if (mounted) {
          setState(() => _bulkRegisterProcessed = i);
        }
        final item = selectedSnapshot[i];
        final before = managed.statusForProduct(item.productId);
        if (before != RakutenManagedProductStatus.none) {
          alreadyExists++;
          skipped++;
          bulkRegisterItemResultLog(
            index: i,
            productId: item.productId,
            title: item.itemName,
            success: false,
            skipped: true,
            reason: 'alreadyExists',
          );
          continue;
        }
        final err = await managed.registerCandidate(item);
        if (err == null) {
          final after = managed.statusForProduct(item.productId);
          if (after == RakutenManagedProductStatus.candidate) {
            success++;
            bulkRegisterItemResultLog(
              index: i,
              productId: item.productId,
              title: item.itemName,
              success: true,
              skipped: false,
              reason: 'success',
            );
          } else {
            alreadyExists++;
            skipped++;
            bulkRegisterItemResultLog(
              index: i,
              productId: item.productId,
              title: item.itemName,
              success: false,
              skipped: true,
              reason: 'alreadyExists',
            );
          }
        } else {
          failed++;
          if (err.contains('ROOM同期中') || err.contains('処理中')) {
            syncBusyBlocked++;
          }
          bulkRegisterItemResultLog(
            index: i,
            productId: item.productId,
            title: item.itemName,
            success: false,
            skipped: false,
            reason: syncBusyBlocked > 0 ? 'syncBusy' : 'unknownError',
          );
        }
      }
    } finally {
      bulk.setBulkCandidateRegistering(false);
      if (mounted) {
        setState(() {
          _isBulkRegistering = false;
          _bulkRegisterProcessed = _bulkRegisterTotal;
          _selectedProductIds.clear();
        });
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[BULK_REGISTER_UI_STATE] isRunning=false mode=candidate '
        'processed=$_bulkRegisterTotal total=$_bulkRegisterTotal',
      );
    }
    bulkRegisterResultLog(
      selected: selectedSnapshot.length,
      success: success,
      skipped: skipped,
      failed: failed,
      alreadyExists: alreadyExists,
      safetyBlocked: 0,
      limitReached: syncBusyBlocked,
    );
    if (!mounted) return;
    final failureLine = failed > 0 ? '\n失敗 $failed件' : '';
    final skipLine = skipped > 0 ? '\n登録済み $alreadyExists件' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(
          '候補に追加：成功 $success件$skipLine$failureLine\n下部の「ROOMコレ」→ 候補一覧で確認できます。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textOnAccent,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        backgroundColor: AppColors.accentPrimary,
      ),
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

  Widget _buildResultSortActionChip(
    BuildContext context, {
    required RakutenKeywordSearchSortMode value,
    required void Function(RakutenKeywordSearchSortMode next) onSortSelected,
  }) {
    return PopupMenuButton<RakutenKeywordSearchSortMode>(
      initialValue: value,
      onSelected: onSortSelected,
      itemBuilder: (ctx) => [
        for (final m in RakutenKeywordSearchSortMode.values)
          PopupMenuItem(
            value: m,
            child: Text(_keywordSortModeLabel(m)),
          ),
      ],
      child: Chip(
        avatar: Icon(
          Icons.sort_rounded,
          size: 16,
          color: AppColors.accentPrimary,
        ),
        label: Text(
          '並び順 ${_keywordSortModeLabel(value)}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.accentPrimary,
              ),
        ),
        side: BorderSide(color: AppColors.accentPrimary.withValues(alpha: 0.65)),
        backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.08),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildResultSortControl(
    BuildContext context, {
    required RakutenKeywordSearchSortMode value,
    required ScrollController resultsScrollController,
    required void Function(RakutenKeywordSearchSortMode next) onSortSelected,
    bool compact = false,
  }) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: HomeScreenColors.footnoteMuted,
      fontWeight: FontWeight.w700,
      fontSize: compact ? 10.5 : null,
    );
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: HomeScreenColors.leadOnSection,
      fontWeight: FontWeight.w700,
      fontSize: compact ? 10.5 : null,
    );
    return Tooltip(
      message: '同じ検索条件でも、並び順を変えると候補の見え方が変わります。',
      waitDuration: const Duration(milliseconds: 400),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(compact ? '並び' : '並び順', style: labelStyle),
          SizedBox(width: compact ? 2 : 4),
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
                  size: compact ? 16 : 18,
                  color: HomeScreenColors.leadOnSection,
                ),
                style: valueStyle,
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
      ),
    );
  }

  void _showCandidateRegisteredSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          'コレ候補に追加しました。\n下部の「ROOMコレ」→ 候補一覧で確認・整理できます。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textOnAccent,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        backgroundColor: AppColors.accentPrimary,
      ),
    );
  }

  Widget _buildBulkSelectionHeaderRow(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
    List<RakutenSearchItem> orderedResults,
  ) {
    if (!_bulkCheckboxVisible(search)) return const SizedBox.shrink();
    final selectableCount = orderedResults
        .where((e) => _isSelectableForBulk(e, managed))
        .length;
    if (kDebugMode) {
      debugPrint(
        '[SELECTION_UI_REDESIGN] screen=${_selectionScreenTag()} '
        'selectionModeRemoved=true checkboxAlwaysVisible=true radioLikeCircleRemoved=true',
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.screenPadH,
        0,
        RakutenSearchScreenUi.screenPadH,
        4,
      ),
      child: SearchBulkSelectionHeader(
        screen: _selectionScreenTag(),
        selectedCount: _selectedProductIds.length,
        totalSelectable: selectableCount,
        enabled: !_isBulkRegistering && selectableCount > 0,
        onToggleAll: (selectAll) {
          if (selectAll) {
            _selectAllForBulk(orderedResults, managed);
          } else {
            _clearBulkSelection();
          }
        },
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

    if (search.results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _searchHeaderCollapsed = true);
      });
    }
  }

  /// 帯・選択行・メタとリストを縦分割する。キーボード表示などで下ペインが低いとき、
  /// 固定高さヘッダの合計が領域を超えて [RenderFlex] オーバーフローしないよう、
  /// 上部は割当て高さ内でスクロール可能にする。
  Widget _buildSearchResultsHeaderAndListColumn({
    required List<Widget> headerChildren,
    required Widget listPane,
    bool compactHeader = false,
  }) {
    if (compactHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...headerChildren,
          Expanded(child: listPane),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: headerChildren,
            ),
          ),
        ),
        Expanded(flex: 6, child: listPane),
      ],
    );
  }

  /// 結果リストまたは（キーワード用）空の内訳別表示＋一括登録バー。
  ///
  /// [emptyPreferredFilteredOut] / [emptyGenericFilteredOut] がともに null のとき、
  /// 件数0では [SizedBox.shrink] を返す（ジャンル成功ブロックなど）。
  Widget _buildResultsListWithBulkBar(
    BuildContext context, {
    required RakutenSearchProvider search,
    required SavedShopProvider saved,
    required RakutenManagedProductProvider managed,
    required List<RakutenSearchItem> orderedResults,
    required ScrollController scrollController,
    bool keywordPreferredFilteredAllOut = false,
    Widget? emptyPreferredFilteredOut,
    Widget? emptyGenericFilteredOut,
  }) {
    final bulkBar = _selectedProductIds.isNotEmpty;
    final bottomPad = bulkBar
        ? RakutenSearchScreenUi.listBottomPadWithSelectionBar
        : RakutenSearchScreenUi.listBottomPad + AppDimensions.spacingSm;
    final listPadding = EdgeInsets.fromLTRB(
      RakutenSearchScreenUi.screenPadH,
      RakutenSearchScreenUi.listScrollTopPad,
      RakutenSearchScreenUi.screenPadH,
      bottomPad,
    );
    Widget resultCardAt(int index) {
      final item = orderedResults[index];
      final isSelectable = _isSelectableForBulk(item, managed);
      return RakutenSearchResultCard(
        item: item,
        localStatus: managed.statusForProduct(item.productId),
        isRegistering: managed.isRegistering(item.productId),
        selectionMode: _bulkCheckboxVisible(search),
        isSelected: _selectedProductIds.contains(item.productId),
        isSelectionEnabled: isSelectable && !_isBulkRegistering,
        selectionDisabledLabel: _selectionDisabledReason(item, managed),
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
          final before = managed.statusForProduct(item.productId);
          final err = await managed.registerCandidate(item);
          if (!context.mounted) return;
          if (err != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(err)));
            return;
          }
          if (before == RakutenManagedProductStatus.none &&
              managed.statusForProduct(item.productId) ==
                  RakutenManagedProductStatus.candidate) {
            _showCandidateRegisteredSnackBar(context);
          }
        },
      );
    }

    Widget listOrEmpty() {
      if (orderedResults.isNotEmpty) {
        return ListView.separated(
          controller: scrollController,
          padding: listPadding,
          itemCount: orderedResults.length,
          separatorBuilder: (_, __) =>
              SizedBox(height: RakutenSearchScreenUi.listCardGap),
          itemBuilder: (context, index) => resultCardAt(index),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetTween = Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offsetTween.animate(animation),
                child: child,
              ),
            );
          },
          child: (_selectedProductIds.isNotEmpty)
              ? SafeArea(
                  key: const ValueKey<String>('bulk_register_bar'),
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      RakutenSearchScreenUi.screenPadH,
                      RakutenSearchScreenUi.gapFieldStack,
                      RakutenSearchScreenUi.screenPadH,
                      RakutenSearchScreenUi.gapFloatingBarPad,
                    ),
                    child: AppPrimaryButton(
                      // 共通AppPrimaryButtonへ置換: 選択商品の一括候補登録CTA。
                      label: _isBulkRegistering
                          ? '追加中…（$_bulkRegisterProcessed/$_bulkRegisterTotal）'
                          : 'まとめて候補に追加（${_selectedProductIds.length}件）',
                      icon: const Icon(
                        Icons.playlist_add_check_rounded,
                        size: 20,
                      ),
                      isLoading: _isBulkRegistering,
                      height: 48,
                      onPressed: _isBulkRegistering
                          ? null
                          : () => _bulkRegisterCandidates(
                              managed,
                              orderedResults,
                            ),
                    ),
                  ),
                )
              : const SizedBox.shrink(
                  key: ValueKey<String>('bulk_register_hidden'),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchRetryFailureBanner(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    final message = search.retryFailureBannerMessage;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }
    return Material(
      color: AppColors.error.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '再検索に失敗しました：$message',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: HomeScreenColors.metricTileTitleColor,
                    ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: search.clearRetryFailureBanner,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
    SavedShopProvider saved, {
    required SearchSurfacePhase phase,
    required bool keyboardVisible,
  }) {
    _showCompletionFeedbackIfNeeded(context, search);
    if (_mode == _RakutenSearchMode.shopDiscovery) {
      return _buildShopDiscoveryResultArea(context, search);
    }
    if (_mode == _RakutenSearchMode.genre) {
      return _buildGenreResultArea(context, search, managed, saved);
    }
    final retryBanner = _buildSearchRetryFailureBanner(context, search);
    switch (phase) {
      case SearchSurfacePhase.loading:
        return const Center(
          child: AppLoadingView(message: '商品を探しています', inline: false),
        );
      case SearchSurfacePhase.error:
        if (kDebugMode) {
          _logSearchKeyboardLayoutAudit(
            keyboardVisible: keyboardVisible,
            phase: phase,
            errorCardCompact: keyboardVisible,
            context: context,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            retryBanner,
            Expanded(
              child: RakutenSearchErrorView(
                compactLayout: keyboardVisible,
                title: '検索結果を表示できませんでした',
                stateLine: _savedShopKeywordEntryEffective
                    ? '状態: 保存ショップ検索に失敗しました'
                    : '状態: 検索に失敗しました',
                message: search.errorMessage.isNotEmpty
                    ? search.errorMessage
                    : '時間をおいて「もう一度検索する」を押すか、条件を緩めて試してください。',
                onRetry: () => _runSearch(context),
                onAdjustConditions: () => _openProductConditionsSheet(context),
                adjustLabel: _savedShopKeywordEntryEffective
                    ? '条件を開く'
                    : 'キーワードを開く',
              ),
            ),
          ],
        );
      case SearchSurfacePhase.input:
      case SearchSurfacePhase.result:
      case SearchSurfacePhase.empty:
        break;
    }
    switch (search.status) {
      case RakutenSearchStatus.idle:
        if (_savedShopKeywordEntryEffective) {
          return const RakutenSearchIdleView(
            icon: Icons.storefront_outlined,
            title: '店内検索の結果がここに表示されます',
            subtitle: 'ショップとキーワードを指定して検索してください。',
            compactLayout: true,
          );
        }
        return const RakutenSearchIdleView(
          icon: Icons.manage_search_outlined,
          title: '検索結果がここに並びます',
          subtitle: 'キーワードを入れて「検索」。気に入った商品は「候補に追加」でROOMコレへ。',
          stateFootnote: '候補・コレ済は除外（最大100件）。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const Center(
          child: AppLoadingView(message: '商品を探しています', inline: false),
        );
      case RakutenSearchStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            retryBanner,
            Expanded(
              child: RakutenSearchErrorView(
                compactLayout: keyboardVisible,
                title: '検索結果を表示できませんでした',
                stateLine: _savedShopKeywordEntryEffective
                    ? '状態: 保存ショップ検索に失敗しました'
                    : '状態: 検索に失敗しました',
                message: search.errorMessage.isNotEmpty
                    ? search.errorMessage
                    : '時間をおいて「もう一度検索する」を押すか、条件を緩めて試してください。',
                onRetry: () => _runSearch(context),
                onAdjustConditions: () => _openProductConditionsSheet(context),
                adjustLabel: _savedShopKeywordEntryEffective
                    ? '条件を開く'
                    : 'キーワードを開く',
              ),
            ),
          ],
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          if (search.keywordSearchHadApiHitsButNoVisibleResults) {
            return RakutenSearchEmptyView(
              icon: Icons.playlist_remove_rounded,
              title: '新しい候補が見つかりませんでした',
              body: '候補・コレ済を除くと、一覧に出せる商品がありませんでした。',
              hints: const ['キーワードや条件を変える', '別の探し方（ジャンル・発掘）も試す'],
              onRefine: () => _openProductConditionsSheet(context),
              refineLabel: '条件を開く',
              stateFootnote: '楽天に商品があっても、除外後は0件になることがあります。',
            );
          }
          return RakutenSearchEmptyView(
            icon: Icons.inventory_2_outlined,
            title: _savedShopKeywordEntryEffective
                ? 'このショップでは該当商品が見つかりませんでした'
                : '該当する商品がありません',
            body: _savedShopKeywordEntryEffective
                ? 'キーワードを変えるか、条件を緩めて再検索してください。'
                : 'キーワードや条件を見直してみてください。',
            hints: const ['言い回しを変える・条件を緩める', '除外ワードやショップ絞り込みを外す'],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: '条件を開く',
            stateFootnote: '取得は完了していますが、この条件では0件です。',
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
        final showingCount = filteredResults.length;
        _logSavedShopSearchExecute(
          context,
          resultCount: showingCount,
          success: true,
        );
        final shortfallNote = search.keywordManagedVisibleShortfallNote();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            retryBanner,
            Expanded(
              child: _buildSearchResultsHeaderAndListColumn(
                compactHeader: true,
                headerChildren: [
                  if (shortfallNote != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        RakutenSearchScreenUi.screenPadH,
                        0,
                        RakutenSearchScreenUi.screenPadH,
                        6,
                      ),
                      child: Text(
                        shortfallNote,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                      ),
                    ),
                  _buildBulkSelectionHeaderRow(
                    context,
                    search,
                    managed,
                    orderedResults,
                  ),
                ],
                listPane: _buildResultsListWithBulkBar(
                  context,
                  search: search,
                  saved: saved,
                  managed: managed,
                  orderedResults: orderedResults,
                  scrollController: _keywordResultsScrollController,
                  keywordPreferredFilteredAllOut: keywordPreferredFilteredAllOut,
                  emptyPreferredFilteredOut: RakutenSearchEmptyView(
                    icon: Icons.store_mall_directory_outlined,
                    title: '一覧を表示できませんでした',
                    body: '保存済みショップの商品だけがヒットし、表示対象がありませんでした。',
                    hints: const ['条件を変えて再検索', 'ジャンル探索も試す'],
                    onRefine: () => _openProductConditionsSheet(context),
                    refineLabel: '条件を開く',
                    stateFootnote: '候補・コレ済以外は結果に含めています。',
                  ),
                  emptyGenericFilteredOut: RakutenSearchEmptyView(
                    icon: Icons.filter_alt_off_outlined,
                    title: '表示できる商品がありません',
                    body: search.keywordManagedVisibleShortfallNote() ??
                        '取得はできていますが、候補済・安全性フィルタ等の適用後は0件です。',
                    hints: const [
                      '条件を緩める',
                      'キーワードを変えて再検索',
                      'ジャンル探索に切り替える',
                    ],
                    onRefine: () => _openProductConditionsSheet(context),
                    refineLabel: '条件を開く',
                    stateFootnote: '取得は完了しています。',
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
    SavedShopProvider saved,
  ) {
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return const RakutenSearchIdleView(
          icon: Icons.explore_outlined,
          title: 'ジャンル探索の結果はここに並びます',
          subtitle: 'ジャンルを選んで「検索」。気に入った商品は「候補に追加」でROOMコレに保存。',
          stateFootnote: '候補・コレ済は除外（最大100件）。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const Center(
          // 共通AppLoadingViewへ置換: ジャンル検索中のローディング表示。
          child: AppLoadingView(message: '商品を探しています', inline: false),
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
            title: '該当する商品がありません',
            body: 'ジャンルや補助キーワード、条件を見直してみてください。',
            hints: const ['補助キーワードを空にする／言い回しを変える', '価格・評価などの条件を緩める'],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: 'ジャンルを選ぶ',
            stateFootnote: '取得は完了していますが、この条件では0件です。',
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
            title: '表示できる商品がありません',
            body: n > 0
                ? '取得 $n 件のうち、候補・コレ済・保存ショップを除くと新規候補がありませんでした。'
                : '表示対象が0件です。',
            hints: const ['条件を緩めて再検索', 'キーワード検索に切り替える'],
            onRefine: () => _openProductConditionsSheet(context),
            refineLabel: 'ジャンルを選ぶ',
            stateFootnote: '取得は完了しています。',
          );
        }
        final orderedResults = filteredResults;
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] genreSearch itemBuilder count=${orderedResults.length} '
            'showingCount=${orderedResults.length}',
          );
        }
        final shortfallNote = search.keywordManagedVisibleShortfallNote();
        return _buildSearchResultsHeaderAndListColumn(
          compactHeader: true,
          headerChildren: [
            if (shortfallNote != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  RakutenSearchScreenUi.screenPadH,
                  0,
                  RakutenSearchScreenUi.screenPadH,
                  6,
                ),
                child: Text(
                  shortfallNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ),
            _buildBulkSelectionHeaderRow(
              context,
              search,
              managed,
              orderedResults,
            ),
          ],
          listPane: _buildResultsListWithBulkBar(
            context,
            search: search,
            saved: saved,
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
          title: '発掘結果はここに並びます',
          subtitle: 'キーワードやジャンルからショップを探し、気に入った店は結果から保存できます。',
          stateFootnote: '実行までこのエリアは更新されません。',
          compactLayout: true,
        );
      case RakutenSearchStatus.loading:
        return const Center(
          // 共通AppLoadingViewへ置換: ショップ発掘中のローディング表示。
          child: AppLoadingView(message: 'ショップを発掘しています', inline: false),
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
            title: 'もとになる商品がありません',
            body: 'キーワード・ジャンル・条件を見直してみてください。',
            hints: const ['キーワードやジャンルを変える', '評価条件や除外ワードを緩める'],
            onRefine: () => _openShopDiscoveryConditionsSheet(context),
            refineLabel: '条件を調整',
            stateFootnote: '取得は完了していますが、この条件では0件です。',
          );
        }
        final shopLimit =
            _parseInt(_shopDiscoveryShopLimitController.text) ?? 10;
        final itemsPerShop =
            _parseInt(_shopDiscoveryItemsPerShopController.text) ?? 5;
        final safeResults = search.results
            .where((e) => !_isSafetyBlockedForSearch(e))
            .toList(growable: false);
        final summaries = ShopDiscoveryAggregator.aggregate(
          safeResults,
          shopLimit: shopLimit,
          itemsPerShop: itemsPerShop,
        );
        if (summaries.isEmpty) {
          return RakutenSearchEmptyView(
            icon: Icons.groups_outlined,
            title: 'ショップ候補を組み立てられませんでした',
            body: '商品はありましたが、表示できるショップ候補がありませんでした。',
            hints: const ['条件を緩めて再実行', 'キーワードやジャンルで件数を増やす'],
            onRefine: () => _openShopDiscoveryConditionsSheet(context),
            refineLabel: '条件を開く',
            stateFootnote: '取得は完了しています。',
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
                title: '新規のショップ候補がありません',
                body: '今回のヒットは保存済みショップのみでした（新規のみ表示）。',
                hints: const ['キーワードやジャンルを変える', '条件を緩める'],
                onRefine: () => _openShopDiscoveryConditionsSheet(context),
                refineLabel: '条件を開く',
                stateFootnote: '検索は成功しています。',
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
                  child: AppCard(
                    // 共通AppCardへ置換: ショップ発掘の結果ヘッダー。
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    backgroundColor: HomeScreenColors.deckFill,
                    borderColor: HomeScreenColors.deckOutline,
                    radius: RakutenSearchScreenUi.radiusSectionInner,
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ショップ発掘の結果 ${visible.length}件（スコア順）',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: HomeScreenColors.metricTileTitleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                letterSpacing: -0.12,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'スコアはヒット数・評価数・評価点から算出しています。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomeScreenColors.metricTileCaptionColor,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                              ),
                        ),
                        Text(
                          '※ 保存済みショップは除外（$removedCount件）。',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: HomeScreenColors.footnoteMuted,
                                height: 1.32,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _shopDiscoveryResultsScrollController,
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

/// シート表示直後に [focusNode] へフォーカスを移す（TextField / Dropdown 用）。
class _PostFrameFocusRequester extends StatefulWidget {
  const _PostFrameFocusRequester({
    required this.focusNode,
    required this.child,
  });

  final FocusNode focusNode;
  final Widget child;

  @override
  State<_PostFrameFocusRequester> createState() =>
      _PostFrameFocusRequesterState();
}

class _PostFrameFocusRequesterState extends State<_PostFrameFocusRequester> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _SearchWayPicker { product, genre, savedShop, shopDiscovery }

enum _RakutenSearchMode {
  product(
    '商品名で探す',
    Icons.shopping_bag_outlined,
    'キーワードで探し、気に入った商品は「候補に追加」でROOMコレへ。',
  ),
  genre('ジャンルから探す', Icons.explore_outlined, 'ジャンルで広く眺め、同じボタンから候補に追加できます。'),
  shopDiscovery(
    'ショップを発掘',
    Icons.storefront_outlined,
    'ショップ候補を探します。店の商品は詳細からコレ候補にも追加できます。',
  );

  const _RakutenSearchMode(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
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
