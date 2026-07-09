import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../config/rakuten_api_config.dart';
import '../models/catalog_product.dart';
import '../utils/api_request_coordinator.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../repository/genre_master_repository.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/analytics_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../utils/app_debug_log.dart';
import '../utils/catalog_product_mapper.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/product_catalog_audit.dart';
import '../utils/product_catalog_upsert_timing.dart';
import '../utils/shop_pool_audit.dart';

enum RakutenSearchStatus { idle, loading, success, error }

/// 保存ショップ検索失敗の内部分類（ログ・UI文言の根拠）。
enum SavedShopSearchFailureReason {
  api400WrongParameter,
  api429RateLimit,
  networkTimeout,
  emptyResult,
  invalidKeyword,
  missingShopCode,
  staleResponseIgnored,
  unknown,
}

/// 楽天検索画面の状態管理。
class RakutenSearchProvider extends ChangeNotifier {
  RakutenSearchProvider({
    required RakutenSearchRepository repository,
    GenreMasterRepository? genreMasterRepository,
    ProductCatalogRepository? productCatalogRepository,
    AnalyticsService? analytics,
  }) : _repository = repository,
       _genreMasterRepository = genreMasterRepository,
       _productCatalogRepository = productCatalogRepository,
       _analytics = analytics ?? AnalyticsServiceRegistry.instance;

  final RakutenSearchRepository _repository;
  final GenreMasterRepository? _genreMasterRepository;
  final ProductCatalogRepository? _productCatalogRepository;
  final AnalyticsService _analytics;

  /// 検索結果に対応するジャンル表示名（API解決後）。キーは `genreId` 文字列。
  Map<String, String> _resolvedGenreLabels = const {};

  RakutenSearchStatus _status = RakutenSearchStatus.idle;
  List<RakutenSearchItem> _results = const [];
  String _errorMessage = '';
  String? _errorModeTag;
  String? _retryFailureBannerMessage;
  String _lastKeyword = '';

  /// キーワード検索で API から商品は取れたが、登録済み除外・アプリ側条件の結果リストが空。
  bool _keywordSearchHadApiHitsButNoVisibleResults = false;

  /// 直近の [searchWithCondition] で `excludeRegisteredProductIds` を使った場合のフェッチメタ（それ以外は null）。
  RakutenKeywordManagedFetchSummary? _keywordManagedFetchSummary;

  int _searchSessionSeq = 0;
  int _activeSearchSessionId = 0;
  String? _activeSearchModeTag;

  RakutenSearchStatus get status => _status;
  int get activeSearchSessionId => _activeSearchSessionId;
  String? get activeSearchModeTag => _activeSearchModeTag;
  List<RakutenSearchItem> get results => _results;
  String get errorMessage => _errorMessage;
  String? get errorModeTag => _errorModeTag;
  String? get retryFailureBannerMessage => _retryFailureBannerMessage;
  String get lastKeyword => _lastKeyword;

  bool get hasPreviousResult => _results.isNotEmpty;

  /// 現在の [modeTag] に紐づくエラー表示が有効か。
  bool isErrorVisibleForMode(String modeTag) =>
      _status == RakutenSearchStatus.error && _errorModeTag == modeTag;

  bool get keywordSearchHadApiHitsButNoVisibleResults =>
      _keywordSearchHadApiHitsButNoVisibleResults;

  RakutenKeywordManagedFetchSummary? get keywordManagedFetchSummary =>
      _keywordManagedFetchSummary;

  /// 一覧カード向け。[RakutenProductGenreDisplay] の優先順位で表示名を決定。
  String genreLineForItem(RakutenSearchItem item) {
    final id = item.genreId.trim();
    if (id.isEmpty) return '';
    final pf = _resolvedGenreLabels[id];
    return RakutenProductGenreDisplay.resolve(
      apiGenreName: item.genreName,
      persistedGenreName: null,
      prefetchedGenreName: pf,
      genreId: item.genreId,
      traceItemCode: item.productId,
    );
  }

  /// 管理除外パスで目標件数に届かなかったときの短文（キーワードタブ向け）。届いている・該当なしは null。
  String? keywordManagedVisibleShortfallNote() {
    final s = _keywordManagedFetchSummary;
    if (s == null) return null;
    final n = s.displayCount > 0 ? s.displayCount : _results.length;
    if (n >= s.targetVisibleCap) return null;
    final excluded = s.excludedCandidate + s.excludedDone;
    if (s.stopReason == RakutenKeywordSearchStopReason.partialFetchFailure) {
      return '一部の商品を取得できませんでした。条件を変えるか、もう一度検索してください。';
    }
    final qualityExcl =
        s.excludedNoImage + s.excludedNoPrice + s.excludedSafety;
    final qualityNote = qualityExcl > 0
        ? '画像や価格が確認できない商品、候補・コレ済は除外しています。'
        : '候補・コレ済の商品は除外しています。';
    if (n > 0 && n < s.targetVisibleCap) {
      return '条件に合う商品を$n件表示しています。$qualityNote';
    }
    if (excluded > 0 && n > 0) {
      return '条件に合う商品を$n件表示しています。$qualityNote';
    }
    if (excluded > 0) {
      return '候補・コレ済の商品は除外しています。';
    }
    switch (s.stopReason) {
      case RakutenKeywordSearchStopReason.reachedTarget:
        return null;
      case RakutenKeywordSearchStopReason.partialFetchFailure:
        return '一部の商品を取得できませんでした。条件を変えるか、もう一度検索してください。';
      case RakutenKeywordSearchStopReason.maxPagesReached:
        return '条件に合う商品を$n件表示しています。';
      case RakutenKeywordSearchStopReason.apiNoMoreResults:
        return '条件に合う商品を$n件表示しています。';
    }
  }

  /// 直近の成功結果のうち `affiliateUrl` が空でない件数（API側のアフィリエイト応答の目安）。
  int get resultsWithAffiliateUrlCount =>
      _results.where((e) => e.hasAffiliateUrlInResponse).length;

  Future<void> search(String keyword) async {
    final condition = RakutenProductSearchCondition(
      keyword: keyword,
    ).normalized();
    if (condition.keyword.isEmpty) {
      _status = RakutenSearchStatus.idle;
      _results = const [];
      _errorMessage = '';
      _lastKeyword = '';
      _keywordSearchHadApiHitsButNoVisibleResults = false;
      _keywordManagedFetchSummary = null;
      _resolvedGenreLabels = const {};
      notifyListeners();
      return;
    }
    await searchWithCondition(condition);
  }

  /// 検索開始時に呼び、[searchWithCondition] の結果反映と照合する。
  int beginSearchSession({required String modeTag}) {
    final sessionId = ++_searchSessionSeq;
    _activeSearchSessionId = sessionId;
    _activeSearchModeTag = modeTag;
    if (kDebugMode && DebugLogFlags.enableVerboseSearchStateLog) {
      debugPrint(
        '[SEARCH_EXECUTE_TRACE] sessionId=$sessionId mode=$modeTag '
        'startedAt=${DateTime.now().toIso8601String()}',
      );
    }
    return sessionId;
  }

  /// 新規検索開始時にエラー・再検索バナーをクリアする。
  void clearErrorForNewSearch({
    required String modeTag,
    required int requestId,
  }) {
    _errorModeTag = modeTag;
    _errorMessage = '';
    _retryFailureBannerMessage = null;
    if (kDebugMode && modeTag == 'savedShop') {
      debugPrint(
        '[SAVED_SHOP_SEARCH_LIFECYCLE] requestId=$requestId event=clearError '
        'shopCode=- keyword=- genreId=- resultCount=- errorType=- errorMessage=-',
      );
    }
  }

  /// 別モードへ切り替えたとき、他モードのエラー表示を残さない。
  void clearErrorIfModeMismatch(String modeTag) {
    if (_status != RakutenSearchStatus.error) return;
    if (_errorModeTag == null || _errorModeTag == modeTag) return;
    _status = RakutenSearchStatus.idle;
    _errorMessage = '';
    _errorModeTag = null;
    notifyListeners();
  }

  void clearRetryFailureBanner() {
    if (_retryFailureBannerMessage == null) return;
    _retryFailureBannerMessage = null;
    notifyListeners();
  }

  Future<void> searchWithCondition(
    RakutenProductSearchCondition condition, {
    Set<String>? excludeRegisteredProductIds,
    Set<String>? excludeCandidateProductIds,
    Set<String>? excludeDoneProductIds,
    Set<String>? excludeSavedShopCodes,
    int? sessionId,
    String modeTag = 'product',
  }) async {
    final normalized = condition.normalized();
    final sid = sessionId ?? beginSearchSession(modeTag: modeTag);
    // キーワード検索だけでなく、genreId 指定のみの検索（ジャンル検索・ショップ発掘）も許可する。
    final hasKeyword = normalized.keyword.isNotEmpty;
    final hasGenre =
        normalized.genreId != null && normalized.genreId!.isNotEmpty;
    final hasShop =
        normalized.shopCode != null && normalized.shopCode!.trim().isNotEmpty;
    final hasItem =
        normalized.itemCode != null && normalized.itemCode!.trim().isNotEmpty;
    if (!hasKeyword && !hasGenre && !hasShop && !hasItem) {
      _status = RakutenSearchStatus.idle;
      _results = const [];
      _errorMessage = '';
      _errorModeTag = null;
      _retryFailureBannerMessage = null;
      _lastKeyword = '';
      _keywordSearchHadApiHitsButNoVisibleResults = false;
      _keywordManagedFetchSummary = null;
      _resolvedGenreLabels = const {};
      notifyListeners();
      return;
    }
    clearErrorForNewSearch(modeTag: modeTag, requestId: sid);
    final analyticsSource = resolveAnalyticsSearchSource(normalized);
    final analyticsHasKeyword = normalized.keyword.isNotEmpty;
    final analyticsHasGenre =
        normalized.genreId != null && normalized.genreId!.trim().isNotEmpty;
    unawaited(
      _analytics.logSearchExecuted(
        source: analyticsSource,
        hasKeyword: analyticsHasKeyword,
        hasGenre: analyticsHasGenre,
      ),
    );
    if (kDebugMode && modeTag == 'savedShop') {
      debugPrint(
        '[SAVED_SHOP_SEARCH_LIFECYCLE] requestId=$sid event=start '
        'shopCode=${normalized.shopCode ?? '-'} keyword="${normalized.keyword}" '
        'genreId=${normalized.genreId ?? '-'} resultCount=- errorType=- errorMessage=-',
      );
    }
    _status = RakutenSearchStatus.loading;
    _lastKeyword = normalized.keyword;
    _keywordSearchHadApiHitsButNoVisibleResults = false;
    _keywordManagedFetchSummary = null;
    notifyListeners();
    ApiRequestCoordinator.onManualSearchStarted();

    var apiCalled = false;
    int? responseStatus;
    try {
      final List<RakutenSearchItem> fetched;
      apiCalled = true;
      if (excludeRegisteredProductIds != null) {
        final fetchMode = modeTag == 'genre'
            ? 'genre'
            : (modeTag == 'savedShop'
                  ? 'savedShop'
                  : (modeTag == 'shopDiscovery' ? 'shopDiscovery' : 'product'));
        final result = await _repository.searchKeywordWithManagedExclusion(
          condition: normalized,
          excludeRegisteredProductIds: excludeRegisteredProductIds,
          excludeCandidateProductIds:
              excludeCandidateProductIds ?? const {},
          excludeDoneProductIds: excludeDoneProductIds ?? const {},
          excludeSavedShopCodes: excludeSavedShopCodes ?? const {},
          fetchMode: fetchMode,
          applyDisplayQualityGate: fetchMode != 'shopDiscovery',
        );
        fetched = result.items;
        responseStatus = 200;
        _keywordSearchHadApiHitsButNoVisibleResults =
            result.receivedAnyItemFromApi && result.items.isEmpty;
        _keywordManagedFetchSummary = RakutenKeywordManagedFetchSummary.from(
          result,
        );
        if (kDebugMode) {
          final under = RakutenSearchRepository.classifyKeywordSearchUnder100Reason(
            displayCount: result.items.length,
            targetVisibleCount: result.targetVisibleCount,
            stopReason: result.stopReason,
            excludedCandidate: result.excludedCandidate,
            excludedDone: result.excludedDone,
            excludedDuplicate: result.excludedDuplicate,
            excludedSafety: result.excludedSafety,
            excludedNoImage: result.excludedNoImage,
            excludedNoPrice: result.excludedNoPrice,
          );
          if (result.items.length < result.targetVisibleCount) {
            debugPrint(
              '[SEARCH_RESULT_UNDER_100_REASON] mode=$modeTag displayCount=${result.items.length} '
              'target=${result.targetVisibleCount} reason=$under',
            );
          }
          if (modeTag == 'savedShop') {
            debugPrint(
              '[SAVED_SHOP_SEARCH_API_RESPONSE] shopCode=${normalized.shopCode ?? '-'} '
              'keyword="${normalized.keyword}" genreId=${normalized.genreId ?? '-'} '
              'displayCount=${result.items.length} stopReason=$under '
              'pagesFailed=${result.pagesFailed}',
            );
          }
        }
      } else {
        final fetchScreen = modeTag == 'genre'
            ? 'genreSearch'
            : (modeTag == 'savedShop'
                  ? 'savedShopSearch'
                  : (modeTag == 'shopDiscovery'
                        ? 'shopDiscovery'
                        : 'productSearch'));
        fetched = await _repository.search(
          condition: normalized,
          fetchScreen: fetchScreen,
        );
        responseStatus = 200;
        _keywordManagedFetchSummary = null;
      }
      if (!_applySearchResultIfCurrent(
        sessionId: sid,
        modeTag: modeTag,
        onApply: () {
          if (kDebugMode) {
            final g = normalized.genreId?.trim();
            final tag = g != null && g.isNotEmpty
                ? 'genreSearch'
                : 'searchWithCondition';
            debugPrint(
              '[Rakuten] $tag provider after repository rawItemsCount=${fetched.length} '
              'parsedItemsCount=${fetched.length} genreId=${normalized.genreId ?? '-'} '
              'keywordLen=${normalized.keyword.length}',
            );
          }
          _results = fetched;
          _status = RakutenSearchStatus.success;
          _errorMessage = '';
          _errorModeTag = null;
          _retryFailureBannerMessage = null;
          _resolvedGenreLabels = const {};
        },
        statusCode: responseStatus,
        rawCount: fetched.length,
        displayCount: fetched.length,
      )) {
        return;
      }
      unawaited(
        _analytics.logSearchResultLoaded(
          source: analyticsSource,
          resultCount: fetched.length,
        ),
      );
      if (kDebugMode && modeTag == 'savedShop') {
        debugPrint(
          '[SAVED_SHOP_SEARCH_LIFECYCLE] requestId=$sid event=success '
          'shopCode=${normalized.shopCode ?? '-'} keyword="${normalized.keyword}" '
          'genreId=${normalized.genreId ?? '-'} resultCount=${fetched.length} '
          'errorType=- errorMessage=-',
        );
      }
      final withAff = fetched.where((e) => e.hasAffiliateUrlInResponse).length;
      debugPrint(
        '[Rakuten] affiliateIdをリクエストに付与: '
        '${RakutenApiConfig.requestIncludesAffiliateId} / '
        'affiliateUrlあり: $withAff / ${fetched.length} 件',
      );
      unawaited(_prefetchGenreLabels(fetched));
      _scheduleProductCatalogUpsert(
        fetched,
        modeTag: modeTag,
        keyword: normalized.keyword,
        shopCode: normalized.shopCode,
      );
      if (modeTag == 'savedShop' || modeTag == 'shopDiscovery') {
        logShopPoolSummaryFromProductCatalog(
          productCatalogRepository: _productCatalogRepository,
          source: modeTag == 'savedShop' ? 'savedShopSearch' : 'shopDiscovery',
          excludeSavedShopCodes: excludeSavedShopCodes ?? const {},
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[SEARCH_FIRST_ATTEMPT_AUDIT] mode=$modeTag attempt=1 apiCalled=true '
          'responseStatus=$responseStatus uiApplied=true failureReason=-',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Rakuten] searchWithCondition failed: $e');
        debugPrint('$st');
        if (modeTag == 'savedShop') {
          final statusMatch = RegExp(r'\((\d{3})\)').firstMatch(e.toString());
          debugPrint(
            '[SAVED_SHOP_SEARCH_FAILURE_REASON] shopCode=${normalized.shopCode ?? '-'} '
            'keyword="${normalized.keyword}" genreId=${normalized.genreId ?? '-'} '
            'httpStatus=${statusMatch?.group(1) ?? '-'} detail=${e.runtimeType}',
          );
        }
      }
      final statusMatch = RegExp(r'\((\d{3})\)').firstMatch(e.toString());
      responseStatus = int.tryParse(statusMatch?.group(1) ?? '');
      final classified = _classifySearchFailure(
        e,
        modeTag: modeTag,
        httpStatus: responseStatus,
        shopCode: normalized.shopCode,
        keyword: normalized.keyword,
      );
      if (kDebugMode && modeTag == 'savedShop') {
        debugPrint(
          '[SAVED_SHOP_SEARCH_FAILURE_CLASSIFY] requestId=$sid '
          'shopCode=${normalized.shopCode ?? '-'} keyword="${normalized.keyword}" '
          'httpStatus=${responseStatus ?? '-'} apiError=${e.runtimeType} '
          'classifiedReason=${classified.reason.name} userMessage=${classified.userMessage}',
        );
      }
      final retainResults = _results.isNotEmpty;
      if (!_applySearchResultIfCurrent(
        sessionId: sid,
        modeTag: modeTag,
        onApply: () {
          _keywordSearchHadApiHitsButNoVisibleResults = false;
          _keywordManagedFetchSummary = null;
          _resolvedGenreLabels = const {};
          if (retainResults) {
            _status = RakutenSearchStatus.success;
            _retryFailureBannerMessage = classified.userMessage;
            _errorMessage = '';
            _errorModeTag = null;
          } else {
            _results = const [];
            _status = RakutenSearchStatus.error;
            _errorMessage = classified.userMessage;
            _errorModeTag = modeTag;
            _retryFailureBannerMessage = null;
          }
        },
        statusCode: responseStatus,
        rawCount: 0,
        displayCount: retainResults ? _results.length : 0,
        skipReason: 'error',
      )) {
        if (kDebugMode && modeTag == 'savedShop') {
          debugPrint(
            '[SAVED_SHOP_SEARCH_LIFECYCLE] requestId=$sid event=ignoredStaleResponse '
            'shopCode=${normalized.shopCode ?? '-'} keyword="${normalized.keyword}" '
            'genreId=${normalized.genreId ?? '-'} resultCount=- '
            'errorType=${classified.reason.name} errorMessage=-',
          );
        }
        return;
      }
      unawaited(
        _analytics.logSearchFailed(
          source: analyticsSource,
          errorType: classifyAnalyticsSearchError(
            error: e,
            httpStatus: responseStatus,
          ),
        ),
      );
      if (kDebugMode && modeTag == 'savedShop') {
        debugPrint(
          '[SAVED_SHOP_SEARCH_LIFECYCLE] requestId=$sid event=error '
          'shopCode=${normalized.shopCode ?? '-'} keyword="${normalized.keyword}" '
          'genreId=${normalized.genreId ?? '-'} '
          'resultCount=${retainResults ? _results.length : 0} '
          'errorType=${classified.reason.name} errorMessage=${classified.userMessage}',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[SEARCH_FIRST_ATTEMPT_AUDIT] mode=$modeTag attempt=1 '
          'apiCalled=$apiCalled responseStatus=${responseStatus ?? '-'} '
          'uiApplied=true failureReason=${e.runtimeType}',
        );
      }
    } finally {
      ApiRequestCoordinator.onManualSearchEnded();
    }
    notifyListeners();
  }

  bool _applySearchResultIfCurrent({
    required int sessionId,
    required String modeTag,
    required VoidCallback onApply,
    int? statusCode,
    required int rawCount,
    required int displayCount,
    String? skipReason,
  }) {
    final matched = sessionId == _activeSearchSessionId;
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_REQUEST_RACE_GUARD] mode=$modeTag requestId=$sessionId '
        'activeRequestId=$_activeSearchSessionId accepted=$matched '
        'reason=${matched ? 'currentSession' : (skipReason ?? 'staleSession')}',
      );
    }
    if (!matched) {
      if (kDebugMode) {
        debugPrint(
          '[SEARCH_API_RESULT_APPLY] sessionId=$sessionId '
          'activeSessionId=$_activeSearchSessionId matched=false '
          'statusCode=${statusCode ?? '-'} rawCount=$rawCount '
          'displayCount=$displayCount appliedToUi=false '
          'skipReason=${skipReason ?? 'staleSession'}',
        );
      }
      return false;
    }
    onApply();
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_API_RESULT_APPLY] sessionId=$sessionId '
        'activeSessionId=$_activeSearchSessionId matched=true '
        'statusCode=${statusCode ?? '-'} rawCount=$rawCount '
        'displayCount=$displayCount appliedToUi=true skipReason=-',
      );
    }
    return true;
  }

  void _scheduleProductCatalogUpsert(
    List<RakutenSearchItem> items, {
    required String modeTag,
    String keyword = '',
    String? shopCode,
  }) {
    final repo = _productCatalogRepository;
    if (repo == null || items.isEmpty) return;
    if (modeTag == 'shopDiscovery') {
      ProductCatalogUpsertTimingRegistry.markShopDiscoveryScheduled(
        catalogCountBefore: repo.count(),
      );
      unawaited(() async {
        try {
          await upsertCatalogFromShopDiscoveryItems(
            repo,
            items,
            keyword: keyword,
          );
        } catch (e) {
          importantDebugLog(
            '[PRODUCT_CATALOG_SHOP_DISCOVERY_UPSERT] failed: $e',
          );
        }
      }());
      return;
    }
    final catalogMode = catalogUpsertModeLabelForSearchModeTag(modeTag);
    unawaited(() async {
      try {
        final summary = await upsertCatalogFromSearchItems(
          repo,
          items,
          source: CatalogProductSource.search,
          sourceTrust: CatalogProductSourceTrust.high,
          catalogMode: catalogMode,
        );
        if (modeTag == 'savedShop') {
          logSavedShopCatalogDepthSummary(
            shopCode: shopCode ?? '',
            items: summary.attempted,
            upserted: summary.upserted,
            repository: repo,
          );
        }
      } catch (e) {
        importantDebugLog(
          '[PRODUCT_CATALOG_SEARCH_UPSERT] failed mode=$catalogMode: $e',
        );
      }
    }());
  }

  Future<void> _prefetchGenreLabels(List<RakutenSearchItem> items) async {
    final repo = _genreMasterRepository;
    if (repo == null) return;
    final ids = <int>{};
    for (final i in items) {
      final p = int.tryParse(i.genreId.trim());
      if (p != null && p > 0) ids.add(p);
    }
    if (ids.isEmpty) return;
    final svc = RakutenGenreMasterService.instance;
    final toPrefetch = svc.genreIdsNeedingApiPrefetch(ids);
    if (toPrefetch.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[GenreMaster] search prefetch skip resolvedLocally=${ids.length}',
        );
      }
      return;
    }
    if (kDebugMode) {
      debugPrint(
        '[GenreMaster] search prefetch unique=${ids.length} '
        'apiNeeded=${toPrefetch.length}',
      );
    }
    try {
      await repo.prefetchGenreMasters(toPrefetch);
      final next = <String, String>{};
      for (final id in toPrefetch) {
        final idStr = '$id';
        final raw = await repo.getGenreName(id);
        if (raw.isNotEmpty && raw != idStr) {
          next[idStr] = raw;
        }
      }
      _resolvedGenreLabels = next;
      RakutenGenreMasterService.instance.mergeRuntimeGenreNames(next);
      if (kDebugMode) {
        debugPrint(
          '[RakutenGenre] prefetch done uniqueIds=${ids.length} storedLabels=${next.length}',
        );
      }
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] search prefetch error: $e');
        debugPrint('$st');
      }
    }
  }

  ({SavedShopSearchFailureReason reason, String userMessage}) _classifySearchFailure(
    Object e, {
    required String modeTag,
    int? httpStatus,
    String? shopCode,
    String? keyword,
  }) {
    final raw = e.toString();
    final body = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length).trim()
        : raw.trim();
    final statusFromBody =
        httpStatus ?? int.tryParse(RegExp(r'\((\d{3})\)').firstMatch(body)?.group(1) ?? '');
    SavedShopSearchFailureReason reason = SavedShopSearchFailureReason.unknown;
    if (shopCode == null || shopCode.trim().isEmpty) {
      reason = SavedShopSearchFailureReason.missingShopCode;
    } else if (statusFromBody == 400) {
      reason = SavedShopSearchFailureReason.api400WrongParameter;
    } else if (statusFromBody == 429) {
      reason = SavedShopSearchFailureReason.api429RateLimit;
    } else if (_looksLikeNetworkError(body, e)) {
      reason = SavedShopSearchFailureReason.networkTimeout;
    }
    final userMessage = modeTag == 'savedShop'
        ? _savedShopUserMessage(reason)
        : _genericUserFacingError(body, statusFromBody);
    return (reason: reason, userMessage: userMessage);
  }

  bool _looksLikeNetworkError(String body, Object e) {
    final type = e.runtimeType.toString().toLowerCase();
    if (type.contains('socket') ||
        type.contains('timeout') ||
        type.contains('connection')) {
      return true;
    }
    return body.contains('SocketException') ||
        body.contains('TimeoutException') ||
        body.contains('Connection') ||
        body.contains('Network');
  }

  String _savedShopUserMessage(SavedShopSearchFailureReason reason) {
    switch (reason) {
      case SavedShopSearchFailureReason.api400WrongParameter:
      case SavedShopSearchFailureReason.invalidKeyword:
        return 'キーワードを少し変えて再検索してください';
      case SavedShopSearchFailureReason.api429RateLimit:
        return '少し時間をおいて再検索してください';
      case SavedShopSearchFailureReason.networkTimeout:
        return '通信状況を確認してください';
      case SavedShopSearchFailureReason.emptyResult:
        return 'このショップでは該当商品が見つかりませんでした';
      case SavedShopSearchFailureReason.missingShopCode:
        return 'ショップを選択してから検索してください';
      case SavedShopSearchFailureReason.staleResponseIgnored:
      case SavedShopSearchFailureReason.unknown:
        return '通信状況を確認してください';
    }
  }

  String _genericUserFacingError(String body, int? httpStatus) {
    if (body.contains('楽天APIのアプリIDが未設定')) {
      return '楽天APIの設定（アプリID）がまだありません。ビルド設定をご確認ください。';
    }
    if (body.contains('楽天のアプリIDが無効です')) {
      return body;
    }
    if (httpStatus == 400) {
      return '検索条件の組み合わせが通りませんでした。キーワードを変えるか、ジャンルなどの絞り込みを外してお試しください。';
    }
    if (httpStatus == 429) {
      return 'しばらく時間をおいてから、もう一度お試しください。';
    }
    if (body.startsWith('楽天API:')) {
      if (kDebugMode) {
        debugPrint('[Rakuten] API rejected params (not shown in UI): $body');
      }
      return '検索条件が通らない可能性があります。キーワードや条件を少し変えて、もう一度お試しください。';
    }
    return '通信状況やキーワード・条件をご確認のうえ、もう一度お試しください。';
  }

  /// 検索画面の一覧・ローディング・エラーなど一時状態だけを初期化する（永続データは変更しない）。
  void resetTransientState() {
    _status = RakutenSearchStatus.idle;
    _results = const [];
    _errorMessage = '';
    _errorModeTag = null;
    _retryFailureBannerMessage = null;
    _lastKeyword = '';
    _keywordSearchHadApiHitsButNoVisibleResults = false;
    _keywordManagedFetchSummary = null;
    _resolvedGenreLabels = const {};
    notifyListeners();
  }

  /// [RakutenSearchSessionCache] から探し方別の結果を復元する。
  void restoreFromSnapshot({
    required RakutenSearchStatus status,
    required List<RakutenSearchItem> results,
    required String errorMessage,
    required String lastKeyword,
    required bool keywordSearchHadApiHitsButNoVisibleResults,
    String? errorModeTag,
    String? retryFailureBannerMessage,
  }) {
    if (_status == RakutenSearchStatus.loading) {
      if (kDebugMode && DebugLogFlags.enableVerboseSearchStateLog) {
        debugPrint(
          '[SEARCH_API_RESULT_APPLY] sessionId=$_activeSearchSessionId '
          'activeSessionId=$_activeSearchSessionId matched=false '
          'appliedToUi=false skipReason=loadingInProgress',
        );
      }
      return;
    }
    _status = status;
    _results = List<RakutenSearchItem>.from(results);
    _errorMessage = errorMessage;
    _errorModeTag =
        status == RakutenSearchStatus.error ? errorModeTag : null;
    _retryFailureBannerMessage = retryFailureBannerMessage;
    _lastKeyword = lastKeyword;
    _keywordSearchHadApiHitsButNoVisibleResults =
        keywordSearchHadApiHitsButNoVisibleResults;
    notifyListeners();
  }
}
