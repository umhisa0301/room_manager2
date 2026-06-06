import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../config/demo_mode.dart';
import '../config/rakuten_api_config.dart';
import '../services/room_import_limit_policy.dart';
import '../data/demo_mode_data.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../services/genre_master_service.dart';
import '../services/rakuten_api_service.dart';
import '../utils/app_debug_log.dart';
import '../utils/product_safety_filter.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/room_import_product_url_match.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';
import '../utils/search_result_quality_filter.dart';
import '../utils/shop_search_fetch_log.dart';

/// キーワード検索（管理除外パス）のページング終了理由。
enum RakutenKeywordSearchStopReason {
  /// 表示目標件数に達して打ち切り
  reachedTarget,

  /// 楽天API側に次のページがない（空レスポンス or 最終ページ）
  apiNoMoreResults,

  /// アプリ側の最大取得ページに達した
  maxPagesReached,

  /// 先頭以外のページで取得エラー
  partialFetchFailure,
}

/// キーワード検索で登録済み商品を除外して集めた結果（API に1件でも取れたかのフラグ付き）。
class RakutenKeywordSearchRepositoryResult {
  const RakutenKeywordSearchRepositoryResult({
    required this.items,
    required this.receivedAnyItemFromApi,
    required this.targetVisibleCount,
    required this.apiPagesFetched,
    required this.stopReason,
    this.rawTotal = 0,
    this.excludedCandidate = 0,
    this.excludedDone = 0,
    this.excludedSafety = 0,
    this.excludedNoImage = 0,
    this.excludedNoPrice = 0,
    this.excludedNoName = 0,
    this.excludedNoUrl = 0,
    this.excludedDuplicate = 0,
    this.excludedSavedShop = 0,
    this.pagesFailed = 0,
    this.pagesRequested = 0,
  });

  final List<RakutenSearchItem> items;
  final bool receivedAnyItemFromApi;

  /// [searchKeywordWithManagedExclusion] に渡した表示目標件数。
  final int targetVisibleCount;

  /// 楽天APIからレスポンスを受け取れたページ数（パース成否は問わない）。
  final int apiPagesFetched;

  /// ページングを終えた理由。
  final RakutenKeywordSearchStopReason stopReason;

  final int rawTotal;
  final int excludedCandidate;
  final int excludedDone;
  final int excludedSafety;
  final int excludedNoImage;
  final int excludedNoPrice;
  final int excludedNoName;
  final int excludedNoUrl;
  final int excludedDuplicate;
  final int excludedSavedShop;
  final int pagesFailed;
  final int pagesRequested;
}

/// キーワード検索（管理除外パス）の直近フェッチのメタ情報（画面の件数説明用）。
class RakutenKeywordManagedFetchSummary {
  const RakutenKeywordManagedFetchSummary({
    required this.targetVisibleCap,
    required this.apiPagesFetched,
    required this.stopReason,
    this.displayCount = 0,
    this.rawTotal = 0,
    this.excludedCandidate = 0,
    this.excludedDone = 0,
    this.excludedSafety = 0,
    this.excludedNoImage = 0,
    this.excludedNoPrice = 0,
    this.excludedNoName = 0,
    this.excludedNoUrl = 0,
    this.excludedDuplicate = 0,
    this.excludedSavedShop = 0,
    this.pagesFailed = 0,
  });

  factory RakutenKeywordManagedFetchSummary.from(
    RakutenKeywordSearchRepositoryResult r,
  ) {
    return RakutenKeywordManagedFetchSummary(
      targetVisibleCap: r.targetVisibleCount,
      apiPagesFetched: r.apiPagesFetched,
      stopReason: r.stopReason,
      displayCount: r.items.length,
      rawTotal: r.rawTotal,
      excludedCandidate: r.excludedCandidate,
      excludedDone: r.excludedDone,
      excludedSafety: r.excludedSafety,
      excludedNoImage: r.excludedNoImage,
      excludedNoPrice: r.excludedNoPrice,
      excludedNoName: r.excludedNoName,
      excludedNoUrl: r.excludedNoUrl,
      excludedDuplicate: r.excludedDuplicate,
      excludedSavedShop: r.excludedSavedShop,
      pagesFailed: r.pagesFailed,
    );
  }

  final int targetVisibleCap;
  final int apiPagesFetched;
  final RakutenKeywordSearchStopReason stopReason;
  final int displayCount;
  final int rawTotal;
  final int excludedCandidate;
  final int excludedDone;
  final int excludedSafety;
  final int excludedNoImage;
  final int excludedNoPrice;
  final int excludedNoName;
  final int excludedNoUrl;
  final int excludedDuplicate;
  final int excludedSavedShop;
  final int pagesFailed;
}

/// APIレスポンスをアプリ用モデルへ変換する責務。
enum RakutenSearchPurpose { normal, recommendation }

/// ROOM 取り込みメタ補完用の1件検索結果（HTTP 429/400 の分類用）。
class RoomImportEnrichmentFetchEnvelope {
  const RoomImportEnrichmentFetchEnvelope({
    this.item,
    this.httpStatus,
    this.rateLimited = false,
    this.exceptionMessage,
    this.responseBodyPreview,
  });

  final RakutenSearchItem? item;
  final int? httpStatus;
  final bool rateLimited;
  final String? exceptionMessage;

  /// 通信エラー時のレスポンス本文先頭（診断用）。
  final String? responseBodyPreview;
}

/// 「URLから追加」の API 解決結果。
class RakutenUrlSearchResolveResult {
  const RakutenUrlSearchResolveResult({
    this.item,
    this.rateLimited = false,
    this.httpStatus,
    this.userMessage,
    this.strategy = '',
  });

  final RakutenSearchItem? item;
  final bool rateLimited;
  final int? httpStatus;
  final String? userMessage;
  final String strategy;
}

/// [RakutenSearchRepository.runRoomImportVerifySequence] の結果。
class RoomImportVerifySequenceOutcome {
  RoomImportVerifySequenceOutcome({
    required this.apiCallCount,
    this.envelope,
    this.winningPattern,
    this.pausedByRateLimit = false,
    this.patternsTried = const [],
    this.blockedPatterns = const [],
    this.lastError = '',
  });

  final RoomImportEnrichmentFetchEnvelope? envelope;

  /// 成功時 `'A'` / `'B'` / `'C'`（複合 itemCode・分割・キーワード+店）。
  final String? winningPattern;
  final int apiCallCount;
  final bool pausedByRateLimit;

  /// 今回の実行で試したパターン（順序付き）。
  final List<String> patternsTried;

  /// 試行終了時点でブロック済みのパターン。
  final List<String> blockedPatterns;

  /// 診断用短文（例: `http_429`, `all_patterns_failed`）。
  final String lastError;
}

/// [fetchRoomImportShopItemWithKeywordUrlFallback] の結果。
class RoomImportShopItemKeywordFallbackOutcome {
  const RoomImportShopItemKeywordFallbackOutcome({
    required this.envelope,
    this.additionalApiCalls = 0,
    this.keywordFallbackAttempted = false,
    this.keywordCandidateSummaries = const [],
  });

  final RoomImportEnrichmentFetchEnvelope envelope;

  /// 追加で叩いた楽天API回数（フォールバック1回なら 1）。
  final int additionalApiCalls;
  final bool keywordFallbackAttempted;
  final List<String> keywordCandidateSummaries;
}

void _logRoomImportItemCodeApiDiag({
  required String shopCodeForLog,
  required String itemCodeForLog,
  required RakutenProductSearchCondition condition,
  required RoomImportEnrichmentFetchEnvelope env,
  String? previewOverride,
}) {
  if (!kDebugMode) return;
  final proxy = RakutenApiConfig.useProxyForItemSearch;
  final kw = condition.keyword.trim();
  final sc = condition.shopCode?.trim() ?? '';
  final ic = condition.itemCode?.trim() ?? '';
  final raw = previewOverride ?? env.responseBodyPreview ?? '';
  final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final prev = oneLine.length > 360 ? '${oneLine.substring(0, 360)}…' : oneLine;
  roomImportItemCodeApiDiagLog(
    'shopCode=$shopCodeForLog itemCode=$itemCodeForLog '
    'proxyMode=${proxy ? 'proxy' : 'direct'} '
    'keywordOmitted=${kw.isEmpty} '
    'shopCodeOmitted=${sc.isEmpty} '
    'itemCodeOmitted=${ic.isEmpty} '
    'httpStatus=${env.httpStatus ?? '-'} '
    'responsePreview=${prev.isEmpty ? '-' : prev}',
  );
}

String _roomImportOmitParam(String? s) {
  final t = s?.trim() ?? '';
  return t.isEmpty ? '(omit)' : t;
}

void _roomImportItemApiParamsLine(
  RakutenProductSearchCondition c, {
  required String phase,
}) {
  final n = c.normalized();
  final st = n.shopItemQueryStyle;
  final styleNote = st == RakutenShopItemQueryStyle.separateShopAndItemParams
      ? 'shopItemStyle=separateParams'
      : st == RakutenShopItemQueryStyle.compositeItemCodeParam
      ? 'shopItemStyle=compositeExplicit'
      : 'shopItemStyle=defaultComposite';
  roomImportItemApiParamsLog(
    'mode=roomImport phase=$phase '
    'keyword=${_roomImportOmitParam(n.keyword)} '
    'shopCode=${_roomImportOmitParam(n.shopCode)} '
    'itemCode=${_roomImportOmitParam(n.itemCode)} '
    '$styleNote',
  );
}

/// ROOM 補完用に `shopCode` とコロンを含まない純粋 `itemCode` に正規化する。
/// `item:path` 形式は最後の `:` で分割し、店舗は左辺（呼び出し側の [shopCode] が空のときのみ左辺を採用）。
/// 正規化不能（ネストした `:` 等）のときは null。
({String shop, String pureItem})? _roomImportNormalizeShopAndPureItem({
  required String shopCode,
  required String itemCode,
}) {
  var sc = shopCode.trim();
  var ic = itemCode.trim();
  if (ic.isEmpty) return null;
  if (ic.contains(':')) {
    final i = ic.lastIndexOf(':');
    final left = ic.substring(0, i).trim();
    final right = ic.substring(i + 1).trim();
    if (right.isEmpty || right.contains(':')) return null;
    ic = right;
    if (sc.isEmpty) {
      sc = left;
    }
  }
  if (ic.contains(':')) return null;
  if (sc.isEmpty || ic.isEmpty) return null;
  return (shop: sc, pureItem: ic);
}

class RakutenSearchRepository {
  RakutenSearchRepository({required RakutenApiService apiService})
    : _apiService = apiService;

  final RakutenApiService _apiService;

  int _rakutenGenreSummaryTotal = 0;
  int _rakutenGenreSummaryUnresolved = 0;
  int _rakutenGenreSummaryUsedMaster = 0;
  int _rakutenGenreSummaryRawGenreNameEmpty = 0;

  /// 検証モード: 失敗した A/B/C は同一セッションでは再試行しない。
  static final Set<String> _verifyBlockedPatterns = <String>{};

  /// 検証モード: 一度成功したパターンのみ次回以降ワンショットで叩く。
  static String? _verifyWinningPattern;

  static List<String> _verifyBlockedSnapshot() =>
      (_verifyBlockedPatterns.toList()..sort());

  /// キーワード検索（コレ候補・コレ済の itemCode 除外）で追いかける API ページ上限。
  /// 1ページあたり最大30件。無限ループ防止・API負荷の上限。
  static const int keywordManagedExclusionMaxApiPages = 20;

  /// 除外後に目標とする表示件数（楽天分の上限に合わせ100）。
  static const int keywordManagedExclusionTargetVisibleCount = 100;

  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    if (kDemoModeEnabled) {
      return DemoModeData.querySearchItems(condition);
    }
    final normalized = condition.normalized();
    const hitsPerRequest = 30;
    final boundedMaxPages = maxPages < 1 ? 1 : maxPages;
    final boundedStartPage = startPage < 1 ? 1 : startPage;
    shopSearchFetchPlanLog(
      'screen=$fetchScreen keyword=${normalized.keyword} '
      'genreId=${normalized.genreId ?? '-'} '
      'shopCode=${normalized.shopCode ?? '-'} '
      'targetDisplayCount=100 hitsPerRequest=$hitsPerRequest '
      'startPage=$boundedStartPage maxPages=$boundedMaxPages '
      'expectedApiCalls=$boundedMaxPages',
    );
    _resetRakutenGenreLogBatch();
    final results = <RakutenSearchItem>[];
    var apiCalls = 0;
    var failedPages = 0;
    String stopReason = 'completed';
    // 1ページ最大30件 × 最大4ページで約120件（楽天API上限内）。
    final endPage = boundedStartPage + boundedMaxPages - 1;
    for (var page = boundedStartPage; page <= endPage; page++) {
      try {
        if (page > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        final sw = Stopwatch()..start();
        final raw = await _apiService.searchItems(
          condition: normalized,
          page: page,
          hits: hitsPerRequest,
        );
        sw.stop();
        apiCalls++;
        shopSearchApiCallLog(
          'page=$page hits=$hitsPerRequest success=true '
          'durationMs=${sw.elapsedMilliseconds} statusCode=200',
        );
        final items = raw['Items'];
        if (items is! List || items.isEmpty) {
          if (kDebugMode) {
            debugPrint('[Rakuten] page=$page empty Items — stop pagination');
          }
          stopReason = 'apiNoMoreResults';
          break;
        }
        var parsedOnPage = 0;
        for (final entry in items) {
          try {
            final map = _unwrapItem(entry);
            final item = _mapToModel(map);
            if (item != null) {
              results.add(item);
              parsedOnPage++;
            }
          } catch (e, st) {
            if (kDebugMode) {
              debugPrint('[Rakuten] item map/parse skipped page=$page: $e');
              debugPrint('$st');
            }
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] page=$page parsedItems=$parsedOnPage / raw=${items.length}',
          );
        }
        if (items.length < hitsPerRequest) {
          stopReason = 'apiNoMoreResults';
          break;
        }
      } catch (e, st) {
        apiCalls++;
        failedPages++;
        shopSearchApiCallLog(
          'page=$page hits=$hitsPerRequest success=false error=$e',
        );
        if (kDebugMode) {
          debugPrint('[Rakuten] page fetch failed page=$page: $e');
          debugPrint('$st');
        }
        if (page == 1) {
          rethrow;
        }
        stopReason = 'partialFailure';
        shopSearchPartialFailureLog(
          'page=$page keptItems=${results.length} messageForUser=一部のページ取得に失敗しました',
        );
        break;
      }
    }
    final beforeFilter = results.length;
    if (kDebugMode) {
      debugPrint('[Rakuten] repository search total mapped=${results.length}');
      final gsTag =
          normalized.genreId != null && normalized.genreId!.trim().isNotEmpty
          ? 'genreSearch'
          : 'search';
      debugPrint('[Rakuten] $gsTag mapped item count=${results.length}');
      debugPrint('[Rakuten] $gsTag before filter count=${results.length}');
    }
    if (searchPurpose == RakutenSearchPurpose.recommendation) {
      if (kDebugMode) {
        debugPrint(
          '[Rakuten] recommendation purpose skip app-side filter count=${results.length}',
        );
      }
      _flushRakutenGenreLogSummary();
      return results;
    }

    List<RakutenSearchItem> afterFilter;
    try {
      afterFilter = _applyAppSideFilters(results, normalized);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Rakuten] app-side filter failed: $e');
        debugPrint('$st');
      }
      _flushRakutenGenreLogSummary();
      return results;
    }
    if (kDebugMode) {
      final gsTag =
          normalized.genreId != null && normalized.genreId!.trim().isNotEmpty
          ? 'genreSearch'
          : 'search';
      debugPrint('[Rakuten] $gsTag after filter count=${afterFilter.length}');
    }
    final safetyExcluded = beforeFilter - afterFilter.length;
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_FETCH_100_AUDIT] mode=$fetchScreen keyword=${normalized.keyword} '
        'genreId=${normalized.genreId ?? '-'} shopCode=${normalized.shopCode ?? '-'} '
        'targetDisplayCount=100 hitsPerRequest=$hitsPerRequest '
        'maxPages=$boundedMaxPages pagesRequested=$apiCalls '
        'pagesSucceeded=${apiCalls - failedPages} pagesFailed=$failedPages '
        'rawTotal=$beforeFilter excludedCandidate=0 excludedDone=0 '
        'excludedSafety=$safetyExcluded excludedDuplicate=0 excludedNoImage=0 '
        'excludedOther=0 excludedSavedShop=0 displayCount=${afterFilter.length} '
        'stopReason=$stopReason',
      );
    }
    shopSearchFetchResultLog(
      'screen=$fetchScreen apiCalls=$apiCalls rawItems=$beforeFilter '
      'dedupedItems=$beforeFilter safetyExcluded=$safetyExcluded '
      'duplicateExcluded=0 displayItems=${afterFilter.length} '
      'failedPages=$failedPages reason=$stopReason',
    );
    _flushRakutenGenreLogSummary();
    return afterFilter;
  }

  /// ROOM取り込みコレ済のメタデータ補完用。
  ///
  /// 楽天 IchibaItem/Search の入力 `itemCode` は **「shopCode:純粋itemCode」** 形式（公式）。
  /// [RakutenApiService] が HTTP クエリへ合成する（`shopCode` 同時指定は 400 の原因になり得る）。
  /// 400 または空ヒット時は `keyword` + `shopCode`（itemCode 省略）へ1段フォールバックする。
  /// 取り込み直後の補完および [RoomImportMetadataEnrichmentService.enrichRoomImportedProducts] で利用。
  Future<RoomImportEnrichmentFetchEnvelope>
  fetchFirstItemForRoomImportEnrichmentEnvelope({
    required String shopCode,
    required String itemCode,
  }) async {
    final apiSw = Stopwatch()..start();
    final icRawIn = itemCode.trim();
    if (icRawIn.isEmpty) {
      apiSw.stop();
      return const RoomImportEnrichmentFetchEnvelope();
    }

    final resolved = _roomImportNormalizeShopAndPureItem(
      shopCode: shopCode,
      itemCode: itemCode,
    );
    if (resolved == null) {
      apiSw.stop();
      roomImportItemApiBlockedLog('reason=colonItemCode itemCode=$icRawIn');
      return RoomImportEnrichmentFetchEnvelope(
        httpStatus: 400,
        exceptionMessage: 'itemCode is not valid',
      );
    }
    final sc = resolved.shop;
    final icPure = resolved.pureItem;

    RakutenProductSearchCondition planShopItem() =>
        RakutenProductSearchCondition(keyword: '', shopCode: sc, itemCode: icPure);

    RakutenProductSearchCondition planKeyword() =>
        RakutenProductSearchCondition(keyword: icPure, shopCode: sc, itemCode: null);

    Future<Map<String, dynamic>> callSearch(
      RakutenProductSearchCondition c,
      String phase,
    ) async {
      final n = c.normalized();
      _roomImportItemApiParamsLine(c, phase: phase);
      return _apiService.searchItems(condition: n, page: 1, hits: 30);
    }

    RoomImportEnrichmentFetchEnvelope envelopeFromRaw({
      required Map<String, dynamic> raw,
      required RakutenProductSearchCondition conditionUsed,
    }) {
      final rawItems = raw['Items'];
      debugPrint(
        '[ROOM_IMPORT_ENRICH] response status='
        '${rawItems is List ? 'Items len=${rawItems.length}' : 'no Items'}',
      );
      if (rawItems is! List || rawItems.isEmpty) {
        debugPrint('[ROOM_IMPORT_ENRICH] empty Items');
        roomImportApiLog(
          'type=rakutenItem status=noItems partialData=true '
          'durationMs=${apiSw.elapsedMilliseconds}',
        );
        roomImportApiLog('rateLimitDetected=false');
        roomImportApiLog('partialData=true reason=emptyItems');
        const envEmpty = RoomImportEnrichmentFetchEnvelope(httpStatus: 200);
        _logRoomImportItemCodeApiDiag(
          shopCodeForLog: sc,
          itemCodeForLog: icPure,
          condition: conditionUsed,
          env: envEmpty,
          previewOverride: '(empty Items)',
        );
        return envEmpty;
      }
      final parsed = <RakutenSearchItem>[];
      for (final entry in rawItems) {
        try {
          final map = _unwrapItem(entry);
          if (map == null) continue;
          final item = _mapToModel(map);
          if (item == null) continue;
          parsed.add(item);
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[ROOM_IMPORT_ENRICH] parse skip: $e');
            debugPrint('$st');
          }
        }
      }
      final best = _pickRoomImportEnrichmentItem(parsed, icPure, sc);
      if (best != null) {
        roomImportItemApiSuccessLog(
          'price=${best.itemPrice} image=${best.imageUrl.trim().isNotEmpty} '
          'shopName=${best.shopName} genreName=${best.genreName}',
        );
        debugPrint('[ROOM_IMPORT_ENRICH] response title=${best.itemName}');
        debugPrint('[ROOM_IMPORT_ENRICH] response shopName=${best.shopName}');
        debugPrint(
          '[ROOM_IMPORT_ENRICH] response genreId='
          '${best.genreId.trim().isEmpty ? '(none)' : best.genreId}',
        );
        final gn = best.genreName.trim();
        debugPrint(
          '[ROOM_IMPORT_ENRICH] response genreName=${gn.isEmpty ? 'null' : gn}',
        );
        debugPrint(
          '[ROOM_IMPORT_ENRICH] response affiliateUrl exists='
          '${best.affiliateUrl.trim().isNotEmpty}',
        );
      } else {
        debugPrint('[ROOM_IMPORT_ENRICH] no matching item after parse');
      }
      final partial = best == null;
      roomImportApiLog(
        'type=rakutenItem status=${partial ? 'partial' : 'ok'} '
        'partialData=$partial durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=false');
      if (partial) {
        roomImportApiLog('partialData=true reason=noMatchingItem');
      }
      final envOk = RoomImportEnrichmentFetchEnvelope(
        item: best,
        httpStatus: 200,
        rateLimited: false,
      );
      _logRoomImportItemCodeApiDiag(
        shopCodeForLog: sc,
        itemCodeForLog: icPure,
        condition: conditionUsed,
        env: envOk,
        previewOverride: partial ? '(noMatchingItem)' : null,
      );
      return envOk;
    }

    debugPrint('[ROOM_IMPORT_ENRICH] shopCode=$sc');
    debugPrint('[ROOM_IMPORT_ENRICH] itemCode=$icPure');

    try {
      if (kDemoModeEnabled) {
        final demoCond = planShopItem().normalized();
        _roomImportItemApiParamsLine(planShopItem(), phase: 'demo');
        final items = await search(condition: demoCond);
        final bestDemo = _pickRoomImportEnrichmentItem(items, icPure, sc);
        debugPrint('[ROOM_IMPORT_ENRICH] response status=demo searchItems');
        if (bestDemo != null) {
          roomImportItemApiSuccessLog(
            'price=${bestDemo.itemPrice} image=${bestDemo.imageUrl.trim().isNotEmpty} '
            'shopName=${bestDemo.shopName} genreName=${bestDemo.genreName}',
          );
        }
        roomImportApiLog(
          'type=rakutenItem status=ok durationMs=${apiSw.elapsedMilliseconds}',
        );
        roomImportApiLog('rateLimitDetected=false');
        final envDemo = RoomImportEnrichmentFetchEnvelope(
          item: bestDemo,
          httpStatus: 200,
          rateLimited: false,
        );
        _logRoomImportItemCodeApiDiag(
          shopCodeForLog: sc,
          itemCodeForLog: icPure,
          condition: demoCond,
          env: envDemo,
        );
        apiSw.stop();
        return envDemo;
      }

      Map<String, dynamic> raw;
      RakutenProductSearchCondition usedCond = planShopItem().normalized();
      var usedKeywordFallback = false;

      try {
        raw = await callSearch(planShopItem(), 'shopItem');
      } on RakutenApiTransportException catch (e) {
        if (e.statusCode == 400) {
          usedKeywordFallback = true;
          raw = await callSearch(planKeyword(), 'keywordFallback400');
          usedCond = planKeyword().normalized();
        } else {
          rethrow;
        }
      }

      var rawItems = raw['Items'];
      if (rawItems is! List || rawItems.isEmpty) {
        if (!usedKeywordFallback) {
          usedKeywordFallback = true;
          raw = await callSearch(planKeyword(), 'keywordFallbackEmpty');
          usedCond = planKeyword().normalized();
          rawItems = raw['Items'];
        }
      }

      if (rawItems is! List || rawItems.isEmpty) {
        apiSw.stop();
        return envelopeFromRaw(raw: raw, conditionUsed: usedCond);
      }

      if (_pickFirstRoomImportItemFromApiRaw(raw, icPure, sc) == null &&
          !usedKeywordFallback) {
        raw = await callSearch(planKeyword(), 'keywordFallbackNoMatch');
        usedCond = planKeyword().normalized();
      }

      apiSw.stop();
      return envelopeFromRaw(raw: raw, conditionUsed: usedCond);
    } catch (e, st) {
      if (e is RakutenApiTransportException) {
        final c = e.statusCode;
        final rl = c == 429;
        roomImportApiLog(
          'type=rakutenItem status=${rl ? 'rateLimited' : 'httpError'} '
          'http=$c durationMs=${apiSw.elapsedMilliseconds}',
        );
        roomImportApiLog('rateLimitDetected=$rl');
        roomImportApiLog('partialData=true reason=transportHttp');
        debugPrint('[ROOM_IMPORT_ENRICH] response status=transport http=$c');
        if (kDebugMode) {
          debugPrint('$st');
        }
        final envTransport = RoomImportEnrichmentFetchEnvelope(
          item: null,
          httpStatus: c,
          rateLimited: rl,
          exceptionMessage: e.message,
          responseBodyPreview: e.responseBodyPreview,
        );
        _logRoomImportItemCodeApiDiag(
          shopCodeForLog: sc,
          itemCodeForLog: icPure,
          condition: planShopItem().normalized(),
          env: envTransport,
        );
        apiSw.stop();
        return envTransport;
      }
      final msg = e.toString();
      final low = msg.toLowerCase();
      final rl = low.contains('429') || low.contains('ratelimit');
      roomImportApiLog(
        'type=rakutenItem status=exception durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=$rl');
      roomImportApiLog('partialData=true reason=genericException');
      debugPrint('[ROOM_IMPORT_ENRICH] response status=exception $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      final envEx = RoomImportEnrichmentFetchEnvelope(
        item: null,
        httpStatus: null,
        rateLimited: rl,
        exceptionMessage: msg,
      );
      _logRoomImportItemCodeApiDiag(
        shopCodeForLog: sc,
        itemCodeForLog: icPure,
        condition: planShopItem().normalized(),
        env: envEx,
        previewOverride: msg.length > 360 ? '${msg.substring(0, 360)}…' : msg,
      );
      apiSw.stop();
      return envEx;
    }
  }

  /// [fetchFirstItemForRoomImportEnrichmentEnvelope] の互換ラッパー。
  Future<RakutenSearchItem?> fetchFirstItemForRoomImportEnrichment({
    required String shopCode,
    required String itemCode,
  }) async {
    final env = await fetchFirstItemForRoomImportEnrichmentEnvelope(
      shopCode: shopCode,
      itemCode: itemCode,
    );
    return env.item;
  }

  /// 「URLから追加」向け: 解析済み shop/item から1件取得（ROOM 補完と同系統の fallback）。
  Future<RakutenUrlSearchResolveResult> resolveProductForUrlSearch({
    required String inputUrl,
    required String shopCode,
    required String pureItemCode,
    required bool isApiStyleItemCode,
    String normalizedUrl = '',
  }) async {
    final sc = shopCode.trim();
    final ic = pureItemCode.trim();
    final norm = normalizedUrl.trim().isNotEmpty
        ? normalizedUrl.trim()
        : (RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl(inputUrl) ??
              inputUrl.trim());
    final strategy = isApiStyleItemCode ? 'shopItemDirect' : 'shopItemKeywordFallback';
    urlSearchTraceLog(
      'inputUrl=${_urlSearchLogTrim(inputUrl)} '
      'normalizedUrl=${_urlSearchLogTrim(norm)} '
      'extractedShopCode=$sc extractedItemCode=$ic strategy=$strategy',
    );

    if (sc.isEmpty || ic.isEmpty) {
      urlSearchResultLog(
        'success=false itemCode= shopCode= reason=missingCodes',
      );
      return const RakutenUrlSearchResolveResult(
        userMessage: '商品URLを確認できませんでした',
        strategy: 'invalidCodes',
      );
    }

    final env = await fetchFirstItemForRoomImportEnrichmentEnvelope(
      shopCode: sc,
      itemCode: ic,
    );

    if (env.rateLimited || env.httpStatus == 429) {
      urlSearchResultLog(
        'success=false itemCode=$ic shopCode=$sc reason=429 strategy=$strategy',
      );
      return RakutenUrlSearchResolveResult(
        rateLimited: true,
        httpStatus: env.httpStatus ?? 429,
        strategy: strategy,
        userMessage: '楽天APIの利用制限に達しました。しばらく待ってからお試しください。',
      );
    }

    if (env.item != null) {
      final api = env.item!;
      urlSearchResultLog(
        'success=true itemCode=${api.productId.trim()} shopCode=${api.shopCode.trim()} '
        'strategy=$strategy',
      );
      return RakutenUrlSearchResolveResult(
        item: api,
        httpStatus: env.httpStatus,
        strategy: strategy,
      );
    }

    final reason = env.httpStatus == 400
        ? 'api400'
        : (env.exceptionMessage?.trim().isNotEmpty == true
              ? 'exception'
              : 'noItems');
    urlSearchResultLog(
      'success=false itemCode=$ic shopCode=$sc reason=$reason strategy=$strategy',
    );
    return RakutenUrlSearchResolveResult(
      httpStatus: env.httpStatus,
      strategy: strategy,
      userMessage: '商品情報を取得できませんでした。URLを確認するか、しばらくしてからお試しください。',
    );
  }

  static String _urlSearchLogTrim(String s, {int max = 180}) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  RakutenSearchItem? _pickRoomImportEnrichmentItem(
    List<RakutenSearchItem> items,
    String numericItemCode,
    String shopCodeRaw,
  ) {
    final nic = numericItemCode.trim();
    final sc = shopCodeRaw.trim();
    for (final it in items) {
      if (_roomImportEnrichmentItemMatches(it, nic, sc)) return it;
    }
    return items.isNotEmpty ? items.first : null;
  }

  /// メタ補完の shopCode+itemCode 検索用: **一致が無ければ null**（先頭件の誤採用を防ぐ）。
  RakutenSearchItem? _pickRoomImportEnrichmentItemStrict(
    List<RakutenSearchItem> items,
    String itemCodeGuess,
    String shopCodeRaw,
  ) {
    final nic = itemCodeGuess.trim();
    final sc = shopCodeRaw.trim();
    for (final it in items) {
      if (_roomImportEnrichmentItemMatches(it, nic, sc)) return it;
    }
    return null;
  }

  RakutenSearchItem? _pickFirstRoomImportItemFromApiRaw(
    Map<String, dynamic> raw,
    String pureItemForPick,
    String shopForPick,
  ) {
    final rawItems = raw['Items'];
    if (rawItems is! List || rawItems.isEmpty) return null;
    final parsed = <RakutenSearchItem>[];
    for (final entry in rawItems) {
      try {
        final map = _unwrapItem(entry);
        if (map == null) continue;
        final item = _mapToModel(map);
        if (item == null) continue;
        parsed.add(item);
      } catch (_) {}
    }
    return _pickRoomImportEnrichmentItem(parsed, pureItemForPick, shopForPick);
  }

  bool _roomImportEnrichmentItemMatches(
    RakutenSearchItem it,
    String numericItemCode,
    String shopCodeRaw,
  ) {
    final pid = it.productId.trim();
    final nic = numericItemCode.trim();
    if (nic.isNotEmpty && pid == nic) return true;
    final prefixed = '$shopCodeRaw:$nic';
    if (pid == prefixed) return true;
    if (nic.isNotEmpty && pid.endsWith(nic) && pid.contains(':')) {
      return true;
    }
    return false;
  }

  void _roomImportEnrichmentFullRequestLog({
    required String phase,
    required RakutenProductSearchCondition condition,
    required int page,
    required int hits,
  }) {
    if (!kDebugMode) return;
    final n = condition.normalized();
    final proxy = RakutenApiConfig.useProxyForItemSearch;
    final proxyUrl = proxy
        ? '${RakutenApiConfig.proxyBaseUrl.trim()}/rakuten'
        : 'direct-non-proxy';
    final sortDisp = (n.sort ?? '').trim().isEmpty ? '(omit)' : n.sort!.trim();
    final gid = (n.genreId ?? '').trim().isEmpty ? '(omit)' : n.genreId!.trim();
    roomImportEnrichRequestLog(
      'phase=$phase proxyUrl=$proxyUrl forceLegacy=${RakutenApiConfig.forceLegacy} '
      'shopCode=${_roomImportOmitParam(n.shopCode)} '
      'itemCode=${_roomImportOmitParam(n.itemCode)} '
      'keyword=${_roomImportOmitParam(n.keyword)} '
      'minPrice=${n.minPrice ?? '-'} maxPrice=${n.maxPrice ?? '-'} '
      'genreId=$gid page=$page hits=$hits sort=$sortDisp',
    );
  }

  RoomImportEnrichmentFetchEnvelope _roomImportEnvelopeAfterSingleFetch({
    required Map<String, dynamic> raw,
    required String matchPureItem,
    required String matchShopCode,
    required bool preferShopFirstForKeyword,
    String urlPathMatchSegment = '',
    int? roomPriceForMatch,
    void Function(RakutenSearchItem item, RoomImportApiCandidateMatch match)?
        onCandidateEvaluated,
  }) {
    final paired = _roomImportParseItemsWithRawMaps(raw);
    if (paired.isEmpty) {
      return const RoomImportEnrichmentFetchEnvelope(httpStatus: 200);
    }
    final RakutenSearchItem? best;
    if (preferShopFirstForKeyword) {
      final sc = matchShopCode.trim();
      final slug = urlPathMatchSegment.trim();
      RakutenSearchItem? hit;
      if (sc.isNotEmpty && slug.isNotEmpty) {
        for (final p in paired) {
          final eval = roomImportEvaluateApiCandidateMatch(
            item: p.item,
            rawItemMap: p.map,
            roomShopCode: sc,
            roomUrlProductCode: slug,
            roomPrice: roomPriceForMatch,
          );
          onCandidateEvaluated?.call(p.item, eval);
          if (eval.matched) {
            hit = p.item;
            break;
          }
        }
      } else if (sc.isNotEmpty) {
        for (final p in paired) {
          if (p.item.shopCode.trim() == sc) {
            hit = p.item;
            break;
          }
        }
      }
      best = hit;
    } else {
      best = _pickRoomImportEnrichmentItemStrict(
        paired.map((p) => p.item).toList(),
        matchPureItem,
        matchShopCode,
      );
    }
    return RoomImportEnrichmentFetchEnvelope(
      item: best,
      httpStatus: 200,
      rateLimited: false,
    );
  }

  List<({RakutenSearchItem item, Map<String, dynamic> map})>
  _roomImportParseItemsWithRawMaps(Map<String, dynamic> raw) {
    final rawItems = raw['Items'];
    if (rawItems is! List) return const [];
    final paired = <({RakutenSearchItem item, Map<String, dynamic> map})>[];
    for (final entry in rawItems) {
      try {
        final map = _unwrapItem(entry);
        if (map == null) continue;
        final item = _mapToModel(map);
        if (item == null) continue;
        paired.add((item: item, map: map));
      } catch (_) {}
    }
    return paired;
  }

  /// ROOM 取り込み補完: `shopCode` + 価格帯 + keyword で検索し、URL スラッグ一致候補のみ採用する。
  Future<RoomImportEnrichmentFetchEnvelope> fetchRoomImportShopPriceKeywordEnrichment({
    required String productId,
    required String shopCode,
    required String keyword,
    required String urlPathMatchSegment,
    int? roomPrice,
    String phase = 'shopPriceKeyword',
  }) async {
    final sc = shopCode.trim();
    final slug = urlPathMatchSegment.trim();
    final kw = keyword.trim();
    final rp = roomPrice;
    final priceConditionUsed = rp != null && rp > 0;
    final condition = RakutenProductSearchCondition(
      keyword: kw,
      shopCode: sc.isEmpty ? null : sc,
      itemCode: null,
      minPrice: priceConditionUsed ? rp : null,
      maxPrice: priceConditionUsed ? rp : null,
    ).normalized();

    roomImportApiSearchByPriceLog(
      'productId=$productId shopCode=$sc roomPrice=${rp ?? '-'} '
      'minPrice=${condition.minPrice ?? '-'} maxPrice=${condition.maxPrice ?? '-'} '
      'keyword=$kw priceConditionUsed=$priceConditionUsed',
    );

    void logCandidate(RakutenSearchItem item, RoomImportApiCandidateMatch m) {
      roomImportApiCandidateMatchLog(
        'productId=$productId roomShopCode=$sc roomUrlProductCode=$slug '
        'roomPrice=${rp ?? '-'} candidateItemCode=${item.productId.trim()} '
        'candidateShopCode=${item.shopCode.trim()} candidatePrice=${item.itemPrice} '
        'decodedPcUrl=${m.decodedPcUrl.isEmpty ? '-' : m.decodedPcUrl} '
        'decodedMobileUrl=${m.decodedMobileUrl.isEmpty ? '-' : m.decodedMobileUrl} '
        'shopMatched=${m.shopMatched} priceMatched=${m.priceMatched} '
        'urlSlugMatched=${m.urlSlugMatched} matched=${m.matched} reason=${m.reason}',
      );
    }

    if (kDemoModeEnabled) {
      final items = await search(condition: condition, maxPages: 1);
      for (final it in items) {
        final eval = roomImportEvaluateApiCandidateMatch(
          item: it,
          rawItemMap: null,
          roomShopCode: sc,
          roomUrlProductCode: slug,
          roomPrice: rp,
        );
        logCandidate(it, eval);
        if (eval.matched) {
          return RoomImportEnrichmentFetchEnvelope(
            item: it,
            httpStatus: 200,
            rateLimited: false,
          );
        }
      }
      return const RoomImportEnrichmentFetchEnvelope(httpStatus: 200);
    }

    final apiSw = Stopwatch()..start();
    _roomImportEnrichmentFullRequestLog(
      phase: phase,
      condition: condition,
      page: 1,
      hits: 30,
    );
    try {
      final raw = await _apiService.searchItems(
        condition: condition,
        page: 1,
        hits: 30,
      );
      apiSw.stop();
      roomImportApiLog(
        'type=rakutenItem status=ok durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=false');
      return _roomImportEnvelopeAfterSingleFetch(
        raw: raw,
        matchPureItem: '',
        matchShopCode: sc,
        preferShopFirstForKeyword: true,
        urlPathMatchSegment: slug,
        roomPriceForMatch: rp,
        onCandidateEvaluated: logCandidate,
      );
    } on RakutenApiTransportException catch (e, st) {
      apiSw.stop();
      final rl = e.statusCode == 429;
      roomImportApiLog(
        'type=rakutenItem status=${rl ? 'rateLimited' : 'httpError'} '
        'http=${e.statusCode} durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=$rl');
      if (kDebugMode) {
        debugPrint('[ROOM_IMPORT_ENRICH] shopPriceKeyword transport http=${e.statusCode}');
        debugPrint('$st');
      }
      return RoomImportEnrichmentFetchEnvelope(
        item: null,
        httpStatus: e.statusCode,
        rateLimited: rl,
        exceptionMessage: e.message,
        responseBodyPreview: e.responseBodyPreview,
      );
    } catch (e, st) {
      apiSw.stop();
      final msg = e.toString();
      final low = msg.toLowerCase();
      final rl = low.contains('429') || low.contains('ratelimit');
      roomImportApiLog(
        'type=rakutenItem status=exception durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=$rl');
      if (kDebugMode) {
        debugPrint('[ROOM_IMPORT_ENRICH] shopPriceKeyword exception $e');
        debugPrint('$st');
      }
      return RoomImportEnrichmentFetchEnvelope(
        item: null,
        httpStatus: null,
        rateLimited: rl,
        exceptionMessage: msg,
      );
    }
  }

  /// ROOM メタ補完専用: **1回の** [RakutenApiService.searchItems] のみ（400 後に同一処理内でフォールバックしない）。
  Future<RoomImportEnrichmentFetchEnvelope> fetchRoomImportEnrichmentSingleSearch({
    required RakutenProductSearchCondition condition,
    required String phase,
    int page = 1,
    int hits = 30,
    String matchPureItemForPick = '',
    required String matchShopCodeForPick,
    bool preferShopFirstForKeyword = false,
  }) async {
    final apiSw = Stopwatch()..start();
    final normalized = condition.normalized();
    _roomImportEnrichmentFullRequestLog(
      phase: phase,
      condition: condition,
      page: page,
      hits: hits,
    );

    if (kDemoModeEnabled) {
      final items = await search(condition: normalized, maxPages: 1);
      RakutenSearchItem? best;
      if (preferShopFirstForKeyword) {
        final sc = matchShopCodeForPick.trim();
        best = null;
        for (final it in items) {
          if (it.shopCode.trim() == sc) {
            best = it;
            break;
          }
        }
        best ??= items.isNotEmpty ? items.first : null;
      } else {
        best = _pickRoomImportEnrichmentItemStrict(
          items,
          matchPureItemForPick,
          matchShopCodeForPick,
        );
      }
      apiSw.stop();
      final env = RoomImportEnrichmentFetchEnvelope(
        item: best,
        httpStatus: 200,
        rateLimited: false,
      );
      _logRoomImportItemCodeApiDiag(
        shopCodeForLog: matchShopCodeForPick,
        itemCodeForLog: matchPureItemForPick,
        condition: normalized,
        env: env,
      );
      return env;
    }

    try {
      final raw = await _apiService.searchItems(
        condition: normalized,
        page: page,
        hits: hits,
      );
      apiSw.stop();
      roomImportApiLog(
        'type=rakutenItem status=ok durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=false');
      final env = _roomImportEnvelopeAfterSingleFetch(
        raw: raw,
        matchPureItem: matchPureItemForPick,
        matchShopCode: matchShopCodeForPick,
        preferShopFirstForKeyword: preferShopFirstForKeyword,
      );
      _logRoomImportItemCodeApiDiag(
        shopCodeForLog: matchShopCodeForPick,
        itemCodeForLog: matchPureItemForPick,
        condition: normalized,
        env: env,
        previewOverride: env.item == null ? '(noItemAfterPick)' : null,
      );
      return env;
    } on RakutenApiTransportException catch (e, st) {
      apiSw.stop();
      final rl = e.statusCode == 429;
      roomImportApiLog(
        'type=rakutenItem status=${rl ? 'rateLimited' : 'httpError'} '
        'http=${e.statusCode} durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=$rl');
      if (kDebugMode) {
        debugPrint('[ROOM_IMPORT_ENRICH] singleSearch transport http=${e.statusCode}');
        debugPrint('$st');
      }
      return RoomImportEnrichmentFetchEnvelope(
        item: null,
        httpStatus: e.statusCode,
        rateLimited: rl,
        exceptionMessage: e.message,
        responseBodyPreview: e.responseBodyPreview,
      );
    } catch (e, st) {
      apiSw.stop();
      final msg = e.toString();
      final low = msg.toLowerCase();
      final rl = low.contains('429') || low.contains('ratelimit');
      roomImportApiLog(
        'type=rakutenItem status=exception durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=$rl');
      if (kDebugMode) {
        debugPrint('[ROOM_IMPORT_ENRICH] singleSearch exception $e');
        debugPrint('$st');
      }
      return RoomImportEnrichmentFetchEnvelope(
        item: null,
        httpStatus: null,
        rateLimited: rl,
        exceptionMessage: msg,
      );
    }
  }

  static bool _shouldKeywordFallbackAfterShopItem400(
    RoomImportEnrichmentFetchEnvelope env,
  ) {
    if (env.httpStatus != 400) return false;
    final blob = [
      env.exceptionMessage ?? '',
      env.responseBodyPreview ?? '',
    ].join(' ').toLowerCase();
    return blob.contains('wrong_parameter') ||
        blob.contains('wrong parameter') ||
        blob.contains('not valid') ||
        blob.contains('invalid') ||
        blob.contains('itemcode') ||
        blob.contains('item_code');
  }

  String _candidateLineForLog(RakutenSearchItem it) {
    final u = it.itemUrl.trim();
    final short = u.length > 72 ? '${u.substring(0, 72)}…' : u;
    return 'itemCode=${it.productId} itemUrl=$short';
  }

  /// 通常補完: まず shop+item（複合 itemCode）検索し、**itemCode 系 400** のときだけ
  /// `keyword + shopCode` で再検索し、**ROOM の productId が商品URLに含まれる件**だけ採用する。
  Future<RoomImportShopItemKeywordFallbackOutcome>
  fetchRoomImportShopItemWithKeywordUrlFallback({
    required RakutenProductSearchCondition shopItemCondition,
    required String matchPureItemForPick,
    required String matchShopCodeForPick,
    required String storedProductIdForUrlMatch,
    String urlPathMatchSegment = '',
    required String fallbackKeyword,
    required bool verifyMode,
    String phaseShopItem = 'shopItem',
  }) async {
    final pid = storedProductIdForUrlMatch.trim();
    final urlSeg = urlPathMatchSegment.trim();
    final fkPrepared = fallbackKeyword.trim();
    final condNorm = shopItemCondition.normalized();

    roomImportEnrichFallbackStartLog({
      'productId': pid,
      'shopCode': (condNorm.shopCode ?? '').trim(),
      'itemCode': (condNorm.itemCode ?? '').trim(),
      'keyword': fkPrepared,
      'verifyMode': '$verifyMode',
    });

    void logNotTriggered(String reason, [Map<String, String>? extra]) {
      final m = <String, String>{
        'status': 'notTriggered',
        'reason': reason,
        'productId': pid,
      };
      if (extra != null) {
        for (final e in extra.entries) {
          m[e.key] = e.value;
        }
      }
      roomImportEnrichFallbackResultLog(m);
    }

    void logNotNeeded(String matchedItemCode) {
      roomImportEnrichFallbackResultLog({
        'status': 'notNeeded',
        'reason': 'directShopItemSearchSucceeded',
        'productId': pid,
        'matchedItemCode': matchedItemCode,
      });
    }

    final envShop = await fetchRoomImportEnrichmentSingleSearch(
      condition: shopItemCondition,
      phase: phaseShopItem,
      page: 1,
      hits: 30,
      matchPureItemForPick: matchPureItemForPick,
      matchShopCodeForPick: matchShopCodeForPick,
    );

    if (envShop.rateLimited || envShop.httpStatus == 429) {
      logNotTriggered('rateLimitedOr429', {
        if (envShop.httpStatus != null) 'httpStatus': '${envShop.httpStatus}',
      });
      return RoomImportShopItemKeywordFallbackOutcome(envelope: envShop);
    }

    if (envShop.item != null) {
      logNotNeeded(envShop.item!.productId.trim());
      return RoomImportShopItemKeywordFallbackOutcome(envelope: envShop);
    }

    if (!_shouldKeywordFallbackAfterShopItem400(envShop)) {
      final status = envShop.httpStatus;
      if (status == null) {
        logNotTriggered('shopItemNon400_NoHttpStatus');
      } else if (status == 400) {
        logNotTriggered('shopItem400BodyNotEligibleForKeywordFallback');
      } else if (status == 200) {
        logNotTriggered('shopItemNoItemAfterPick');
      } else {
        logNotTriggered('shopItemHttpError', {'httpStatus': '$status'});
      }
      return RoomImportShopItemKeywordFallbackOutcome(envelope: envShop);
    }

    if (fkPrepared.isEmpty) {
      logNotTriggered('emptyFallbackKeyword');
      return RoomImportShopItemKeywordFallbackOutcome(envelope: envShop);
    }

    roomImportEnrichFallbackTriggeredLog({
      'reason': 'itemCodeInvalid',
      'productId': pid,
      'shopCode': matchShopCodeForPick.trim(),
      'itemCode': matchPureItemForPick.trim(),
      'keyword': fkPrepared,
    });

    if (kDemoModeEnabled) {
      final kwCond = RakutenProductSearchCondition(
        keyword: fkPrepared,
        shopCode: matchShopCodeForPick,
        itemCode: null,
      ).normalized();
      final demoItems = await search(condition: kwCond, maxPages: 1);
      final summaries = demoItems.map(_candidateLineForLog).take(12).toList();
      for (final it in demoItems) {
        if (roomImportSearchItemUrlsMatchStoredProduct(
          item: it,
          rawItemMap: null,
          storedProductId: storedProductIdForUrlMatch,
          urlPathMatchSegment: urlSeg.isNotEmpty ? urlSeg : null,
          roomShopCode: matchShopCodeForPick.trim(),
        )) {
          return RoomImportShopItemKeywordFallbackOutcome(
            envelope: RoomImportEnrichmentFetchEnvelope(
              item: it,
              httpStatus: 200,
            ),
            additionalApiCalls: 1,
            keywordFallbackAttempted: true,
            keywordCandidateSummaries: summaries,
          );
        }
      }
      roomImportEnrichFallbackResultLog({
        'status': 'noExactUrlMatch',
        'productId': pid,
        'shopCode': matchShopCodeForPick.trim(),
        'keyword': fkPrepared,
        'candidates': summaries.join(' | '),
      });
      return RoomImportShopItemKeywordFallbackOutcome(
        envelope: const RoomImportEnrichmentFetchEnvelope(httpStatus: 200),
        additionalApiCalls: 1,
        keywordFallbackAttempted: true,
        keywordCandidateSummaries: summaries,
      );
    }

    try {
      RoomImportDebugLogBuffer.incEnrichment();
      final normalizedKw = RakutenProductSearchCondition(
        keyword: fkPrepared,
        shopCode: matchShopCodeForPick,
        itemCode: null,
      ).normalized();
      _roomImportEnrichmentFullRequestLog(
        phase: '${phaseShopItem}_keywordShopFallback',
        condition: RakutenProductSearchCondition(
          keyword: fkPrepared,
          shopCode: matchShopCodeForPick,
          itemCode: null,
        ),
        page: 1,
        hits: 30,
      );
      final raw = await _apiService.searchItems(
        condition: normalizedKw,
        page: 1,
        hits: 30,
      );
      final rawItems = raw['Items'];
      if (rawItems is! List) {
        logNotTriggered('keywordSearchResponseMissingItemsList');
        return RoomImportShopItemKeywordFallbackOutcome(
          envelope: const RoomImportEnrichmentFetchEnvelope(httpStatus: 200),
          additionalApiCalls: 1,
          keywordFallbackAttempted: true,
          keywordCandidateSummaries: const [],
        );
      }
      final paired = <({RakutenSearchItem item, Map<String, dynamic> map})>[];
      for (final entry in rawItems) {
        try {
          final map = _unwrapItem(entry);
          if (map == null) continue;
          final item = _mapToModel(map);
          if (item == null) continue;
          paired.add((item: item, map: map));
        } catch (_) {}
      }
      final summaries = paired.map((p) => _candidateLineForLog(p.item)).take(12).toList();
      if (paired.isEmpty) {
        logNotTriggered('keywordSearchNoParsedItems');
        return RoomImportShopItemKeywordFallbackOutcome(
          envelope: const RoomImportEnrichmentFetchEnvelope(httpStatus: 200),
          additionalApiCalls: 1,
          keywordFallbackAttempted: true,
          keywordCandidateSummaries: summaries,
        );
      }
      for (final p in paired) {
        if (roomImportSearchItemUrlsMatchStoredProduct(
          item: p.item,
          rawItemMap: p.map,
          storedProductId: storedProductIdForUrlMatch,
          urlPathMatchSegment: urlSeg.isNotEmpty ? urlSeg : null,
          roomShopCode: matchShopCodeForPick.trim(),
        )) {
          return RoomImportShopItemKeywordFallbackOutcome(
            envelope: RoomImportEnrichmentFetchEnvelope(
              item: p.item,
              httpStatus: 200,
            ),
            additionalApiCalls: 1,
            keywordFallbackAttempted: true,
            keywordCandidateSummaries: summaries,
          );
        }
      }
      roomImportEnrichFallbackResultLog({
        'status': 'noExactUrlMatch',
        'productId': pid,
        'shopCode': matchShopCodeForPick.trim(),
        'keyword': fkPrepared,
        'candidates': summaries.join(' | '),
      });
      return RoomImportShopItemKeywordFallbackOutcome(
        envelope: const RoomImportEnrichmentFetchEnvelope(httpStatus: 200),
        additionalApiCalls: 1,
        keywordFallbackAttempted: true,
        keywordCandidateSummaries: summaries,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ROOM_IMPORT_ENRICH] keywordShop fallback failed: $e\n$st');
      }
      final detail = e.toString();
      final short = detail.length > 160 ? '${detail.substring(0, 160)}…' : detail;
      logNotTriggered('keywordFallbackException', {'detail': short});
      return RoomImportShopItemKeywordFallbackOutcome(envelope: envShop);
    }
  }

  /// キーワード検索タブ専用: [excludeRegisteredProductIds]（楽天 itemCode / [RakutenSearchItem.productId]）と
  /// [excludeSavedShopCodes]（保存ショップの shopCode）を除いたうえで、
  /// 表示候補が [targetVisibleCount] 件に達するか API が尽きるまで、ページを **1ページずつ** 順取得する。
  ///
  /// - 1ページあたり [hitsPerPage] 件（最大30）、最大 [maxFetchPages] ページ（同一ページは取得しない）
  /// - ローカルで除外・ユニーク化してから件数判定（まとめて結合してから次ページへ）
  /// - 1ページ目の取得失敗は再スロー、2ページ目以降の失敗は確保済み件で打ち切り
  Future<RakutenKeywordSearchRepositoryResult>
  searchKeywordWithManagedExclusion({
    required RakutenProductSearchCondition condition,
    required Set<String> excludeRegisteredProductIds,
    Set<String> excludeCandidateProductIds = const {},
    Set<String> excludeDoneProductIds = const {},
    Set<String> excludeSavedShopCodes = const {},
    String fetchMode = 'product',
    int targetVisibleCount = keywordManagedExclusionTargetVisibleCount,
    int hitsPerPage = 30,
    int startPage = 1,
    int maxFetchPages = keywordManagedExclusionMaxApiPages,
    Duration interPageDelay = const Duration(milliseconds: 220),
    bool applyDisplayQualityGate = true,
  }) async {
    if (kDemoModeEnabled) {
      final normalizedDemo = condition.normalized();
      final filtered = DemoModeData.querySearchItems(condition)
          .where((e) => !excludeRegisteredProductIds.contains(e.productId))
          .where((e) => !excludeSavedShopCodes.contains(e.shopCode))
          .where(
            (e) =>
                SearchResultQualityFilter.passesDisplayQuality(
                  e,
                  condition: normalizedDemo,
                ),
          )
          .toList(growable: false);
      final out = filtered.take(targetVisibleCount).toList(growable: false);
      return RakutenKeywordSearchRepositoryResult(
        items: out,
        receivedAnyItemFromApi: DemoModeData.querySearchItems(
          condition,
        ).isNotEmpty,
        targetVisibleCount: targetVisibleCount,
        apiPagesFetched: 1,
        stopReason: out.length >= targetVisibleCount
            ? RakutenKeywordSearchStopReason.reachedTarget
            : RakutenKeywordSearchStopReason.apiNoMoreResults,
      );
    }
    assert(() {
      return targetVisibleCount > 0 &&
          hitsPerPage >= 1 &&
          hitsPerPage <= 30 &&
          maxFetchPages >= 1 &&
          startPage >= 1;
    }());
    final normalized = condition.normalized();
    final excludeCandidate = excludeCandidateProductIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final excludeDone = excludeDoneProductIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final savedShopExclude = excludeSavedShopCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    _resetRakutenGenreLogBatch();
    final visible = <RakutenSearchItem>[];
    final seenIds = <String>{};
    var receivedAnyFromApi = false;
    var page = startPage;
    var apiPagesFetched = 0;
    var pagesRequested = 0;
    var failedPages = 0;
    var rawTotal = 0;
    var safetyExcluded = 0;
    var noImageExcluded = 0;
    var noPriceExcluded = 0;
    var noNameExcluded = 0;
    var noUrlExcluded = 0;
    var reviewThresholdExcluded = 0;
    var duplicateExcluded = 0;
    var candidateExcluded = 0;
    var doneExcluded = 0;
    var savedShopExcluded = 0;
    final qualityGate = applyDisplayQualityGate &&
        (fetchMode == 'product' ||
            fetchMode == 'genre' ||
            fetchMode == 'savedShop');
    final fetchSw = Stopwatch()..start();
    RakutenKeywordSearchStopReason? explicitStop;
    shopSearchFetchPlanLog(
      'screen=$fetchMode keyword=${normalized.keyword} '
      'genreId=${normalized.genreId ?? '-'} shopCode=${normalized.shopCode ?? '-'} '
      'targetDisplayCount=$targetVisibleCount hitsPerRequest=$hitsPerPage '
      'maxPages=$maxFetchPages expectedApiCalls=$maxFetchPages',
    );

    while (visible.length < targetVisibleCount && page <= maxFetchPages) {
      pagesRequested++;
      try {
        if (page > startPage) {
          await Future<void>.delayed(interPageDelay);
        }
        final sw = Stopwatch()..start();
        final raw = await _apiService.searchItems(
          condition: normalized,
          page: page,
          hits: hitsPerPage,
        );
        sw.stop();
        apiPagesFetched++;
        if (kDebugMode) {
          debugPrint(
            '[SEARCH_PAGE_FETCH_AUDIT] sessionId=- mode=$fetchMode page=$page '
            'statusCode=200 rawCount=${raw['Items'] is List ? (raw['Items'] as List).length : 0} '
            'durationMs=${sw.elapsedMilliseconds} success=true',
          );
        }
        shopSearchApiCallLog(
          'page=$page hits=$hitsPerPage success=true '
          'durationMs=${sw.elapsedMilliseconds} statusCode=200',
        );
        final items = raw['Items'];
        if (items is! List || items.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[Rakuten] keywordManagedExclusion page=$page empty Items — stop',
            );
          }
          explicitStop = RakutenKeywordSearchStopReason.apiNoMoreResults;
          break;
        }

        final pageLen = items.length;
        rawTotal += pageLen;
        var pageDroppedRegistered = 0;
        var pageDroppedDup = 0;
        var pageDroppedAppFilter = 0;
        var pageDroppedSavedShop = 0;
        var pageParsedOk = 0;
        for (final entry in items) {
          if (visible.length >= targetVisibleCount) break;
          try {
            final map = _unwrapItem(entry);
            final item = _mapToModel(map);
            if (item == null) continue;
            pageParsedOk++;
            receivedAnyFromApi = true;
            final id = item.productId.trim();
            if (id.isEmpty) continue;
            if (excludeCandidate.contains(id)) {
              pageDroppedRegistered++;
              candidateExcluded++;
              continue;
            }
            if (excludeDone.contains(id)) {
              pageDroppedRegistered++;
              doneExcluded++;
              continue;
            }
            if (seenIds.contains(id)) {
              pageDroppedDup++;
              duplicateExcluded++;
              continue;
            }
            if (qualityGate) {
              final reason = SearchResultQualityFilter.exclusionReason(
                item,
                condition: normalized,
                checkSafety: true,
              );
              if (reason != null) {
                pageDroppedAppFilter++;
                switch (reason) {
                  case SearchQualityExcludeReason.noImage:
                    noImageExcluded++;
                  case SearchQualityExcludeReason.noPrice:
                    noPriceExcluded++;
                  case SearchQualityExcludeReason.noName:
                    noNameExcluded++;
                  case SearchQualityExcludeReason.noUrl:
                    noUrlExcluded++;
                  case SearchQualityExcludeReason.safety:
                    safetyExcluded++;
                    ProductSafetyFilter.logFilter(
                      source: fetchMode,
                      itemCode: id,
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
                  case SearchQualityExcludeReason.reviewCount:
                  case SearchQualityExcludeReason.reviewAverage:
                    reviewThresholdExcluded++;
                }
                continue;
              }
            } else {
              final passed = _applyAppSideFilters([item], normalized);
              if (passed.isEmpty) {
                pageDroppedAppFilter++;
                reviewThresholdExcluded++;
                continue;
              }
            }
            final shopCode = item.shopCode.trim();
            final scopedShop = normalized.shopCode?.trim() ?? '';
            if (shopCode.isNotEmpty && savedShopExclude.contains(shopCode)) {
              // 保存済みショップは通常一覧から除外するが、API 検索でその shopCode を
              // 明示指定しているときは結果は当該ショップの商品に限られるため除外しない。
              if (scopedShop.isEmpty || shopCode != scopedShop) {
                pageDroppedSavedShop++;
                savedShopExcluded++;
                continue;
              }
            }
            seenIds.add(id);
            visible.add(item);
          } catch (e, st) {
            if (kDebugMode) {
              debugPrint(
                '[Rakuten] keywordManagedExclusion map/parse skip page=$page: $e',
              );
              debugPrint('$st');
            }
          }
        }

        if (kDebugMode) {
          debugPrint(
            '[Rakuten] keywordManagedExclusion page=$page raw=$pageLen '
            'parsed=$pageParsedOk visible=${visible.length}/$targetVisibleCount '
            'dropReg=$pageDroppedRegistered dropDup=$pageDroppedDup '
            'dropAppFilter=$pageDroppedAppFilter dropSavedShop=$pageDroppedSavedShop',
          );
        }

        if (visible.length >= targetVisibleCount) {
          explicitStop = RakutenKeywordSearchStopReason.reachedTarget;
          break;
        }
        final isLastPage = pageLen < hitsPerPage;
        if (isLastPage) {
          explicitStop = RakutenKeywordSearchStopReason.apiNoMoreResults;
          break;
        }
        page++;
      } catch (e, st) {
        failedPages++;
        if (kDebugMode) {
          debugPrint(
            '[SEARCH_PAGE_FETCH_AUDIT] sessionId=- mode=$fetchMode page=$page '
            'statusCode=- rawCount=0 durationMs=0 success=false',
          );
        }
        shopSearchApiCallLog(
          'page=$page hits=$hitsPerPage success=false error=$e',
        );
        if (kDebugMode) {
          debugPrint('[Rakuten] keywordManagedExclusion page=$page failed: $e');
          debugPrint('$st');
        }
        if (page == startPage) {
          rethrow;
        }
        explicitStop = RakutenKeywordSearchStopReason.partialFetchFailure;
        shopSearchPartialFailureLog(
          'page=$page keptItems=${visible.length} messageForUser=一部のページ取得に失敗しました',
        );
        page++;
        if (page <= maxFetchPages && visible.length < targetVisibleCount) {
          continue;
        }
        break;
      }
    }

    final stopReason =
        explicitStop ??
        (visible.length >= targetVisibleCount
            ? RakutenKeywordSearchStopReason.reachedTarget
            : (page > maxFetchPages
                  ? RakutenKeywordSearchStopReason.maxPagesReached
                  : RakutenKeywordSearchStopReason.apiNoMoreResults));

    if (kDebugMode) {
      debugPrint(
        '[Rakuten] keywordManagedExclusion done visible=${visible.length} '
        'hadRaw=$receivedAnyFromApi pages=$apiPagesFetched stop=$stopReason',
      );
    }
    final displayItems = visible.length > targetVisibleCount
        ? visible.sublist(0, targetVisibleCount)
        : visible;
    final under100Reason = classifyKeywordSearchUnder100Reason(
      displayCount: displayItems.length,
      targetVisibleCount: targetVisibleCount,
      stopReason: stopReason,
      excludedCandidate: candidateExcluded,
      excludedDone: doneExcluded,
      excludedDuplicate: duplicateExcluded,
      excludedSafety: safetyExcluded,
      excludedNoImage: noImageExcluded,
      excludedNoPrice: noPriceExcluded,
    );
    fetchSw.stop();
    if (qualityGate) {
      searchAuditLog(
        '[SEARCH_QUALITY_FILTER_SUMMARY] mode=$fetchMode '
        'keyword=${normalized.keyword} genreId=${normalized.genreId ?? '-'} '
        'shopCode=${normalized.shopCode ?? '-'} sort=${normalized.sort ?? '-'} '
        'raw=$rawTotal afterManagedExclude=${displayItems.length} '
        'excludedNoImage=$noImageExcluded excludedNoPrice=$noPriceExcluded '
        'excludedNoName=$noNameExcluded excludedNoUrl=$noUrlExcluded '
        'excludedSafety=$safetyExcluded excludedReviewThreshold=$reviewThresholdExcluded '
        'visible=${displayItems.length} stopReason=${stopReason.name} '
        'durationMs=${fetchSw.elapsedMilliseconds}',
      );
    }
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_FETCH_100_AUDIT] mode=$fetchMode keyword=${normalized.keyword} '
        'genreId=${normalized.genreId ?? '-'} shopCode=${normalized.shopCode ?? '-'} '
        'targetDisplayCount=$targetVisibleCount hitsPerRequest=$hitsPerPage '
        'maxPages=$maxFetchPages pagesRequested=$pagesRequested '
        'pagesSucceeded=$apiPagesFetched pagesFailed=$failedPages rawTotal=$rawTotal '
        'excludedCandidate=$candidateExcluded excludedDone=$doneExcluded '
        'excludedSafety=$safetyExcluded excludedDuplicate=$duplicateExcluded '
        'excludedNoImage=$noImageExcluded excludedNoPrice=$noPriceExcluded '
        'excludedNoName=$noNameExcluded excludedNoUrl=$noUrlExcluded '
        'excludedReviewThreshold=$reviewThresholdExcluded excludedOther=0 '
        'excludedSavedShop=$savedShopExcluded displayCount=${displayItems.length} '
        'stopReason=$under100Reason',
      );
      if (displayItems.length < targetVisibleCount) {
        debugPrint(
          '[SEARCH_RESULT_UNDER_100_REASON] mode=$fetchMode displayCount=${displayItems.length} '
          'target=$targetVisibleCount reason=$under100Reason '
          'excludedNoImage=$noImageExcluded excludedNoPrice=$noPriceExcluded '
          'excludedSafety=$safetyExcluded '
          'pagesSucceeded=$apiPagesFetched pagesFailed=$failedPages',
        );
      }
    }
    shopSearchFetchResultLog(
      'screen=$fetchMode apiCalls=$apiPagesFetched rawItems=$receivedAnyFromApi '
      'dedupedItems=${displayItems.length} safetyExcluded=$safetyExcluded '
      'duplicateExcluded=$duplicateExcluded '
      'registeredExcluded=${candidateExcluded + doneExcluded} '
      'savedShopExcluded=$savedShopExcluded displayItems=${displayItems.length} '
      'failedPages=$failedPages reason=${stopReason.name}',
    );

    _flushRakutenGenreLogSummary();
    return RakutenKeywordSearchRepositoryResult(
      items: displayItems,
      receivedAnyItemFromApi: receivedAnyFromApi,
      targetVisibleCount: targetVisibleCount,
      apiPagesFetched: apiPagesFetched,
      stopReason: stopReason,
      rawTotal: rawTotal,
      excludedCandidate: candidateExcluded,
      excludedDone: doneExcluded,
      excludedSafety: safetyExcluded,
      excludedNoImage: noImageExcluded,
      excludedNoPrice: noPriceExcluded,
      excludedNoName: noNameExcluded,
      excludedNoUrl: noUrlExcluded,
      excludedDuplicate: duplicateExcluded,
      excludedSavedShop: savedShopExcluded,
      pagesFailed: failedPages,
      pagesRequested: pagesRequested,
    );
  }

  /// 表示100件未満の終了理由（ログ・UI説明用の分類）。
  static String classifyKeywordSearchUnder100Reason({
    required int displayCount,
    required int targetVisibleCount,
    required RakutenKeywordSearchStopReason stopReason,
    required int excludedCandidate,
    required int excludedDone,
    required int excludedDuplicate,
    required int excludedSafety,
    int excludedNoImage = 0,
    int excludedNoPrice = 0,
  }) {
    if (displayCount >= targetVisibleCount) return 'reachedTarget';
    final excluded = excludedCandidate + excludedDone;
    if (excludedCandidate > excludedDone && excluded > displayCount) {
      return 'tooManyExcludedCandidate';
    }
    if (excludedDone > excludedCandidate && excluded > displayCount) {
      return 'tooManyExcludedDone';
    }
    if (excluded > displayCount && excludedCandidate + excludedDone >= excludedDuplicate) {
      return 'tooManyExcludedCandidate';
    }
    if (excludedDuplicate > displayCount) return 'tooManyDuplicates';
    final qualityExcluded = excludedNoImage + excludedNoPrice;
    if (qualityExcluded > displayCount) {
      if (excludedNoImage >= excludedNoPrice && excludedNoImage > 0) {
        return 'noImage';
      }
      if (excludedNoPrice > 0) return 'noPrice';
    }
    if (excludedSafety > displayCount) return 'safetyFiltered';
    if (excludedSafety > 0 && qualityExcluded > 0) return 'qualityFiltered';
    if (excludedNoImage > 0) return 'noImage';
    if (excludedNoPrice > 0) return 'noPrice';
    if (excludedSafety > 0) return 'safetyFiltered';
    return switch (stopReason) {
      RakutenKeywordSearchStopReason.reachedTarget => 'reachedTarget',
      RakutenKeywordSearchStopReason.apiNoMoreResults => 'reachedEnd',
      RakutenKeywordSearchStopReason.maxPagesReached => 'maxPagesReached',
      RakutenKeywordSearchStopReason.partialFetchFailure => 'apiPartialFailure',
    };
  }

  Map<String, dynamic>? _unwrapItem(dynamic entry) {
    if (entry is! Map) return null;
    final flat = Map<String, dynamic>.from(entry);
    final nested = flat['Item'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return flat;
  }

  RakutenSearchItem? _mapToModel(Map<String, dynamic>? json) {
    if (json == null) return null;

    var productId = _stringField(json['itemCode']).trim();
    var itemName = _stringField(json['itemName']).trim();
    var affiliateUrl = _stringField(json['affiliateUrl']).trim();
    if (affiliateUrl.isEmpty) {
      affiliateUrl = _stringField(json['affiliateUrlMobile']).trim();
    }
    if (affiliateUrl.isEmpty) {
      affiliateUrl = _stringField(json['affiliateURL']).trim();
    }
    var itemUrl = _stringField(json['itemUrl']).trim();
    if (itemUrl.isEmpty && affiliateUrl.isNotEmpty) {
      itemUrl = affiliateUrl;
    }
    if (itemName.isEmpty) {
      itemName = '（商品名なし）';
    }
    if (productId.isEmpty) {
      if (itemUrl.isNotEmpty) {
        productId = itemUrl;
      } else if (itemName.isNotEmpty) {
        productId = 'noid:${itemName.hashCode}';
      } else {
        return null;
      }
    }
    if (itemUrl.isEmpty) {
      return null;
    }

    final itemPrice = _parseIntLoose(json['itemPrice']);
    var shopName = _stringField(json['shopName']).trim();
    if (shopName.isEmpty) {
      shopName = 'ショップ名不明';
    }
    final reviewCount = _parseIntLoose(json['reviewCount']);
    final reviewAverage = _parseDoubleLoose(json['reviewAverage']);
    final shopCode = _stringField(json['shopCode']).trim();
    final shopUrl = _stringField(json['shopUrl']).trim();
    final genreId = _stringField(json['genreId']).trim();
    var genreName = _stringField(json['genreName']).trim();
    if (genreName.isEmpty) {
      genreName = _stringField(json['itemGenreName']).trim();
    }
    final imageUrl = _extractImageUrl(json);

    final item = RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
      genreName: genreName,
    );
    if (kDebugMode) {
      if (DebugLogFlags.enableVerboseRakutenUrlLog) {
        debugPrint('[RAKUTEN_URL] itemUrl=${item.itemUrl}');
        debugPrint('[RAKUTEN_URL] affiliateUrl=${item.affiliateUrl}');
      }
      _rakutenGenreRecordAndLog(json, productId, item);
    }
    return item;
  }

  void _resetRakutenGenreLogBatch() {
    _rakutenGenreSummaryTotal = 0;
    _rakutenGenreSummaryUnresolved = 0;
    _rakutenGenreSummaryUsedMaster = 0;
    _rakutenGenreSummaryRawGenreNameEmpty = 0;
  }

  void _flushRakutenGenreLogSummary() {
    if (!kDebugMode || _rakutenGenreSummaryTotal == 0) return;
    final resolved = _rakutenGenreSummaryTotal - _rakutenGenreSummaryUnresolved;
    debugSummaryLog(
      '[RakutenGenre][SUMMARY] total=$_rakutenGenreSummaryTotal '
      'resolved=$resolved unresolved=$_rakutenGenreSummaryUnresolved '
      'usedMaster=$_rakutenGenreSummaryUsedMaster '
      'rawGenreNameEmpty=$_rakutenGenreSummaryRawGenreNameEmpty',
    );
    _resetRakutenGenreLogBatch();
  }

  bool _rakutenGenrePerItemLogsEnabled() =>
      DebugLogFlags.kVerboseItemLogsEnabled ||
      DebugLogFlags.kSearchAuditLogsEnabled;

  void _emitRakutenGenrePerItemLog(String message) {
    if (!kDebugMode || !_rakutenGenrePerItemLogsEnabled()) return;
    if (DebugLogFlags.kVerboseItemLogsEnabled) {
      verboseItemLog(message);
    } else {
      searchAuditLog(message);
    }
  }

  void _rakutenGenreRecordAndLog(
    Map<String, dynamic> json,
    String itemCode,
    RakutenSearchItem item,
  ) {
    _rakutenGenreRecordMapStats(item);
    _rakutenGenreLogApi(json, itemCode);
    _rakutenGenreLogMap(item);
  }

  void _rakutenGenreRecordMapStats(RakutenSearchItem m) {
    _rakutenGenreSummaryTotal++;
    final rawNameEmpty = m.genreName.trim().isEmpty;
    if (rawNameEmpty) {
      _rakutenGenreSummaryRawGenreNameEmpty++;
    }
    final display = RakutenProductGenreDisplay.resolve(
      apiGenreName: m.genreName,
      persistedGenreName: null,
      prefetchedGenreName: null,
      genreId: m.genreId,
      traceItemCode: null,
    );
    if (display == RakutenProductGenreDisplay.unknownLabel) {
      _rakutenGenreSummaryUnresolved++;
    }
    if (rawNameEmpty &&
        display != RakutenProductGenreDisplay.unknownLabel &&
        m.genreId.trim().isNotEmpty) {
      _rakutenGenreSummaryUsedMaster++;
    }
  }

  void _rakutenGenreLogApi(Map<String, dynamic> json, String itemCode) {
    final keys = json.keys.map((k) => k.toString()).toList()..sort();
    final gk = keys.where((k) => k.toLowerCase().contains('genre')).toList();
    final rawGenreId = _stringField(json['genreId']).trim();
    final g1 = _stringField(json['genreName']).trim();
    final g2 = _stringField(json['itemGenreName']).trim();
    final rawGenreName = g1.isNotEmpty ? g1 : g2;
    final rawKeysStr = gk.isNotEmpty
        ? gk.join(',')
        : '(no *genre* in keys) sample=${keys.take(12).join(',')}';
    _emitRakutenGenrePerItemLog(
      '[RakutenGenre][API] itemCode=$itemCode rawGenreId=$rawGenreId '
      'rawGenreName=$rawGenreName rawKeys=$rawKeysStr',
    );
  }

  void _rakutenGenreLogMap(RakutenSearchItem m) {
    final gid = m.genreId.trim();
    final jsonRaw = gid.isEmpty
        ? '-'
        : (GenreMasterService.instance.getGenreNameById(gid) ?? '-');
    final jsonRolled = gid.isEmpty
        ? '-'
        : (GenreMasterService.instance.getDisplayGenreNameAvoidingOther(gid) ??
              '-');
    final display = RakutenProductGenreDisplay.resolve(
      apiGenreName: m.genreName,
      persistedGenreName: null,
      prefetchedGenreName: null,
      genreId: m.genreId,
      traceItemCode: null,
    );
    _emitRakutenGenrePerItemLog(
      '[RakutenGenre][MAP] itemCode=${m.productId} model.genreId=${m.genreId} '
      'model.genreName=${m.genreName} jsonRaw=$jsonRaw jsonRolled=$jsonRolled '
      'displayGenre=$display',
    );
  }

  String _stringField(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  int _parseIntLoose(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
  }

  double _parseDoubleLoose(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  String _extractImageUrl(Map<String, dynamic> json) {
    String fromList(dynamic list) {
      if (list is! List || list.isEmpty) return '';
      final first = list.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        return _stringField(m['imageUrl']).trim();
      }
      return _stringField(first).trim();
    }

    final medium = fromList(json['mediumImageUrls']);
    if (medium.isNotEmpty) return medium;

    final small = fromList(json['smallImageUrls']);
    if (small.isNotEmpty) return small;

    final single = _stringField(json['imageUrl']).trim();
    if (single.isNotEmpty) return single;

    return '';
  }

  static bool _verifyHadSelectableItem(RoomImportEnrichmentFetchEnvelope e) {
    if (e.rateLimited) return false;
    if (e.httpStatus == 429 || e.httpStatus == 400) return false;
    return e.item != null;
  }

  static void _verifyMarkBlocked(String label, String reason) {
    _verifyBlockedPatterns.add(label);
    roomImportVerifyLog('pattern=$label blocked reason=$reason');
  }

  /// 検証モード専用: パターン A→B→C を順に試す（成功パターン確定後はそれのみ）。
  ///
  /// - A: `itemCode=shop:pureItem` のみ（複合）
  /// - B: `shopCode` + 純粋 `itemCode`
  /// - C: `keyword` + `shopCode`
  Future<RoomImportVerifySequenceOutcome> runRoomImportVerifySequence({
    required String shopCode,
    required String pureItemCode,
    required String patternCKeyword,
  }) async {
    final sc = shopCode.trim();
    final pic = pureItemCode.trim();
    final kw = patternCKeyword.trim();
    final patternsTried = <String>[];

    Future<RoomImportVerifySequenceOutcome> repeatWinning() async {
      final w = _verifyWinningPattern;
      if (w == null) {
        return RoomImportVerifySequenceOutcome(
          apiCallCount: 0,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: '',
        );
      }
      patternsTried.add(w);
      RoomImportDebugLogBuffer.incEnrichment();
      RoomImportEnrichmentFetchEnvelope env;
      switch (w) {
        case 'A':
          env = await fetchRoomImportEnrichmentSingleSearch(
            condition: RakutenProductSearchCondition(
              keyword: '',
              shopCode: sc,
              itemCode: pic,
              shopItemQueryStyle:
                  RakutenShopItemQueryStyle.compositeItemCodeParam,
            ),
            phase: 'verifyA_winning',
            page: 1,
            hits: 30,
            matchPureItemForPick: pic,
            matchShopCodeForPick: sc,
          );
          break;
        case 'B':
          env = await fetchRoomImportEnrichmentSingleSearch(
            condition: RakutenProductSearchCondition(
              keyword: '',
              shopCode: sc,
              itemCode: pic,
              shopItemQueryStyle:
                  RakutenShopItemQueryStyle.separateShopAndItemParams,
            ),
            phase: 'verifyB_winning',
            page: 1,
            hits: 30,
            matchPureItemForPick: pic,
            matchShopCodeForPick: sc,
          );
          break;
        case 'C':
          env = await fetchRoomImportEnrichmentSingleSearch(
            condition: RakutenProductSearchCondition(
              keyword: kw,
              shopCode: sc,
              itemCode: null,
            ),
            phase: 'verifyC_winning',
            page: 1,
            hits: 30,
            matchPureItemForPick: '',
            matchShopCodeForPick: sc,
            preferShopFirstForKeyword: true,
          );
          break;
        default:
          env = const RoomImportEnrichmentFetchEnvelope();
      }
      final paused = env.rateLimited || env.httpStatus == 429;
      return RoomImportVerifySequenceOutcome(
        envelope: env,
        winningPattern: w,
        apiCallCount: 1,
        pausedByRateLimit: paused,
        patternsTried: List<String>.from(patternsTried),
        blockedPatterns: _verifyBlockedSnapshot(),
        lastError: paused ? 'http_429' : '',
      );
    }

    final early = await repeatWinning();
    if (early.apiCallCount > 0) {
      return early;
    }

    var calls = 0;
    Future<void> gap() async {
      if (calls <= 0) return;
      await Future<void>.delayed(
        Duration(
          milliseconds: RoomImportLimitPolicy.enrichMinDelayMsBetweenCalls,
        ),
      );
    }

    if (!_verifyBlockedPatterns.contains('A')) {
      patternsTried.add('A');
      await gap();
      RoomImportDebugLogBuffer.incEnrichment();
      calls++;
      roomImportVerifyLog('try pattern=A composite itemCodeOnly');
      final envA = await fetchRoomImportEnrichmentSingleSearch(
        condition: RakutenProductSearchCondition(
          keyword: '',
          shopCode: sc,
          itemCode: pic,
          shopItemQueryStyle: RakutenShopItemQueryStyle.compositeItemCodeParam,
        ),
        phase: 'verifyA_compositeItemCode',
        page: 1,
        hits: 30,
        matchPureItemForPick: pic,
        matchShopCodeForPick: sc,
      );
      if (envA.rateLimited || envA.httpStatus == 429) {
        return RoomImportVerifySequenceOutcome(
          envelope: envA,
          apiCallCount: calls,
          pausedByRateLimit: true,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: 'http_429',
        );
      }
      if (_verifyHadSelectableItem(envA)) {
        _verifyWinningPattern = 'A';
        roomImportVerifyLog('success pattern=A apiCalls=$calls');
        return RoomImportVerifySequenceOutcome(
          envelope: envA,
          winningPattern: 'A',
          apiCallCount: calls,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: '',
        );
      }
      _verifyMarkBlocked(
        'A',
        'http=${envA.httpStatus ?? '-'} noItem=${envA.item == null}',
      );
    }

    if (!_verifyBlockedPatterns.contains('B')) {
      patternsTried.add('B');
      await gap();
      RoomImportDebugLogBuffer.incEnrichment();
      calls++;
      roomImportVerifyLog('try pattern=B separate shopCode+itemCode');
      final envB = await fetchRoomImportEnrichmentSingleSearch(
        condition: RakutenProductSearchCondition(
          keyword: '',
          shopCode: sc,
          itemCode: pic,
          shopItemQueryStyle:
              RakutenShopItemQueryStyle.separateShopAndItemParams,
        ),
        phase: 'verifyB_separateShopItem',
        page: 1,
        hits: 30,
        matchPureItemForPick: pic,
        matchShopCodeForPick: sc,
      );
      if (envB.rateLimited || envB.httpStatus == 429) {
        return RoomImportVerifySequenceOutcome(
          envelope: envB,
          apiCallCount: calls,
          pausedByRateLimit: true,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: 'http_429',
        );
      }
      if (_verifyHadSelectableItem(envB)) {
        _verifyWinningPattern = 'B';
        roomImportVerifyLog('success pattern=B apiCalls=$calls');
        return RoomImportVerifySequenceOutcome(
          envelope: envB,
          winningPattern: 'B',
          apiCallCount: calls,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: '',
        );
      }
      _verifyMarkBlocked(
        'B',
        'http=${envB.httpStatus ?? '-'} noItem=${envB.item == null}',
      );
    }

    if (!_verifyBlockedPatterns.contains('C')) {
      patternsTried.add('C');
      await gap();
      RoomImportDebugLogBuffer.incEnrichment();
      calls++;
      roomImportVerifyLog('try pattern=C keyword+shopCode kw=${kw.isEmpty ? '(empty)' : kw}');
      final envC = await fetchRoomImportEnrichmentSingleSearch(
        condition: RakutenProductSearchCondition(
          keyword: kw,
          shopCode: sc,
          itemCode: null,
        ),
        phase: 'verifyC_keywordShop',
        page: 1,
        hits: 30,
        matchPureItemForPick: '',
        matchShopCodeForPick: sc,
        preferShopFirstForKeyword: true,
      );
      if (envC.rateLimited || envC.httpStatus == 429) {
        return RoomImportVerifySequenceOutcome(
          envelope: envC,
          apiCallCount: calls,
          pausedByRateLimit: true,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: 'http_429',
        );
      }
      if (_verifyHadSelectableItem(envC)) {
        _verifyWinningPattern = 'C';
        roomImportVerifyLog('success pattern=C apiCalls=$calls');
        return RoomImportVerifySequenceOutcome(
          envelope: envC,
          winningPattern: 'C',
          apiCallCount: calls,
          patternsTried: List<String>.from(patternsTried),
          blockedPatterns: _verifyBlockedSnapshot(),
          lastError: '',
        );
      }
      _verifyMarkBlocked(
        'C',
        'http=${envC.httpStatus ?? '-'} noItem=${envC.item == null}',
      );
    }

    roomImportVerifyLog('allPatternsFailed apiCalls=$calls');
    return RoomImportVerifySequenceOutcome(
      apiCallCount: calls,
      patternsTried: List<String>.from(patternsTried),
      blockedPatterns: _verifyBlockedSnapshot(),
      lastError: patternsTried.isEmpty
          ? 'no_pattern_attempted'
          : 'all_patterns_failed',
    );
  }

  List<RakutenSearchItem> _applyAppSideFilters(
    List<RakutenSearchItem> source,
    RakutenProductSearchCondition condition,
  ) {
    return source
        .where(
          (item) =>
              SearchResultQualityFilter.exclusionReason(
                item,
                condition: condition,
                checkSafety: false,
              ) ==
              null,
        )
        .toList(growable: false);
  }
}
