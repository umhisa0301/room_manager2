import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../config/rakuten_api_config.dart';
import '../utils/api_request_coordinator.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../repository/genre_master_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/rakuten_genre_master_service.dart';
import '../utils/rakuten_product_genre_display.dart';

enum RakutenSearchStatus { idle, loading, success, error }

/// 楽天検索画面の状態管理。
class RakutenSearchProvider extends ChangeNotifier {
  RakutenSearchProvider({
    required RakutenSearchRepository repository,
    GenreMasterRepository? genreMasterRepository,
  }) : _repository = repository,
       _genreMasterRepository = genreMasterRepository;

  final RakutenSearchRepository _repository;
  final GenreMasterRepository? _genreMasterRepository;

  /// 検索結果に対応するジャンル表示名（API解決後）。キーは `genreId` 文字列。
  Map<String, String> _resolvedGenreLabels = const {};

  RakutenSearchStatus _status = RakutenSearchStatus.idle;
  List<RakutenSearchItem> _results = const [];
  String _errorMessage = '';
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
  String get lastKeyword => _lastKeyword;

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
    final n = _results.length;
    if (n >= s.targetVisibleCap) return null;
    switch (s.stopReason) {
      case RakutenKeywordSearchStopReason.reachedTarget:
        return null;
      case RakutenKeywordSearchStopReason.partialFetchFailure:
        return '途中の取得に失敗したため、表示は$n件です。しばらくして再検索してください。';
      case RakutenKeywordSearchStopReason.maxPagesReached:
        return '取得ページ上限に達しました。除外後の表示は$n件です。';
      case RakutenKeywordSearchStopReason.apiNoMoreResults:
        return '登録済・保存ショップを除くと、この条件で表示できる新しい候補は$n件でした。';
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

  Future<void> searchWithCondition(
    RakutenProductSearchCondition condition, {
    Set<String>? excludeRegisteredProductIds,
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
      _lastKeyword = '';
      _keywordSearchHadApiHitsButNoVisibleResults = false;
      _keywordManagedFetchSummary = null;
      _resolvedGenreLabels = const {};
      notifyListeners();
      return;
    }
    _status = RakutenSearchStatus.loading;
    _errorMessage = '';
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
        final result = await _repository.searchKeywordWithManagedExclusion(
          condition: normalized,
          excludeRegisteredProductIds: excludeRegisteredProductIds,
          excludeSavedShopCodes: excludeSavedShopCodes ?? const {},
        );
        fetched = result.items;
        responseStatus = 200;
        _keywordSearchHadApiHitsButNoVisibleResults =
            result.receivedAnyItemFromApi && result.items.isEmpty;
        _keywordManagedFetchSummary = RakutenKeywordManagedFetchSummary.from(
          result,
        );
      } else {
        fetched = await _repository.search(condition: normalized);
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
          _resolvedGenreLabels = const {};
        },
        statusCode: responseStatus,
        rawCount: fetched.length,
        displayCount: fetched.length,
      )) {
        return;
      }
      final withAff = fetched.where((e) => e.hasAffiliateUrlInResponse).length;
      debugPrint(
        '[Rakuten] affiliateIdをリクエストに付与: '
        '${RakutenApiConfig.requestIncludesAffiliateId} / '
        'affiliateUrlあり: $withAff / ${fetched.length} 件',
      );
      unawaited(_prefetchGenreLabels(fetched));
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
      }
      final statusMatch = RegExp(r'\((\d{3})\)').firstMatch(e.toString());
      responseStatus = int.tryParse(statusMatch?.group(1) ?? '');
      if (!_applySearchResultIfCurrent(
        sessionId: sid,
        modeTag: modeTag,
        onApply: () {
          _results = const [];
          _status = RakutenSearchStatus.error;
          _errorMessage = _userFacingError(e);
          _keywordSearchHadApiHitsButNoVisibleResults = false;
          _keywordManagedFetchSummary = null;
          _resolvedGenreLabels = const {};
        },
        statusCode: responseStatus,
        rawCount: 0,
        displayCount: 0,
        skipReason: 'error',
      )) {
        return;
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

  String _userFacingError(Object e) {
    final raw = e.toString();
    final body = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length).trim()
        : raw.trim();
    if (body.contains('楽天APIのアプリIDが未設定')) {
      return '楽天APIの設定（アプリID）がまだありません。ビルド設定をご確認ください。';
    }
    if (body.contains('楽天のアプリIDが無効です')) {
      return body;
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
    _lastKeyword = lastKeyword;
    _keywordSearchHadApiHitsButNoVisibleResults =
        keywordSearchHadApiHitsButNoVisibleResults;
    notifyListeners();
  }
}
