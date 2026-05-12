import 'package:flutter/foundation.dart';

import '../config/demo_mode.dart';
import '../config/rakuten_api_config.dart';
import '../data/demo_mode_data.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../services/genre_master_service.dart';
import '../services/rakuten_api_service.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/room_sync_log.dart';

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
  });

  final List<RakutenSearchItem> items;
  final bool receivedAnyItemFromApi;

  /// [searchKeywordWithManagedExclusion] に渡した表示目標件数。
  final int targetVisibleCount;

  /// 楽天APIからレスポンスを受け取れたページ数（パース成否は問わない）。
  final int apiPagesFetched;

  /// ページングを終えた理由。
  final RakutenKeywordSearchStopReason stopReason;
}

/// キーワード検索（管理除外パス）の直近フェッチのメタ情報（画面の件数説明用）。
class RakutenKeywordManagedFetchSummary {
  const RakutenKeywordManagedFetchSummary({
    required this.targetVisibleCap,
    required this.apiPagesFetched,
    required this.stopReason,
  });

  factory RakutenKeywordManagedFetchSummary.from(
    RakutenKeywordSearchRepositoryResult r,
  ) {
    return RakutenKeywordManagedFetchSummary(
      targetVisibleCap: r.targetVisibleCount,
      apiPagesFetched: r.apiPagesFetched,
      stopReason: r.stopReason,
    );
  }

  final int targetVisibleCap;
  final int apiPagesFetched;
  final RakutenKeywordSearchStopReason stopReason;
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
  roomImportItemApiParamsLog(
    'mode=roomImport phase=$phase '
    'keyword=${_roomImportOmitParam(n.keyword)} '
    'shopCode=${_roomImportOmitParam(n.shopCode)} '
    'itemCode=${_roomImportOmitParam(n.itemCode)} '
    'apiItemCodeDeprecated=none usesColonItemCode=false',
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

  /// キーワード検索（コレ候補・コレ済の itemCode 除外）で追いかける API ページ上限。
  /// 1ページあたり最大30件。無限ループ防止・API負荷の上限。
  static const int keywordManagedExclusionMaxApiPages = 20;

  /// 除外後に目標とする表示件数（楽天分の上限に合わせ100）。
  static const int keywordManagedExclusionTargetVisibleCount = 100;

  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 5,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
  }) async {
    if (kDemoModeEnabled) {
      return DemoModeData.querySearchItems(condition);
    }
    final normalized = condition.normalized();
    final results = <RakutenSearchItem>[];
    final boundedMaxPages = maxPages < 1 ? 1 : maxPages;
    // 既定は最大5ページ分（約100件）。呼び出し側で maxPages=1 を渡せば1ページだけ取得。
    for (var page = 1; page <= boundedMaxPages; page++) {
      try {
        if (page > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        final raw = await _apiService.searchItems(
          condition: normalized,
          page: page,
          hits: 20,
        );
        final items = raw['Items'];
        if (items is! List || items.isEmpty) {
          if (kDebugMode) {
            debugPrint('[Rakuten] page=$page empty Items — stop pagination');
          }
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
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Rakuten] page fetch failed page=$page: $e');
          debugPrint('$st');
        }
        if (page == 1) {
          rethrow;
        }
        break;
      }
    }
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
      return results;
    }
    if (kDebugMode) {
      final gsTag =
          normalized.genreId != null && normalized.genreId!.trim().isNotEmpty
          ? 'genreSearch'
          : 'search';
      debugPrint('[Rakuten] $gsTag after filter count=${afterFilter.length}');
    }
    return afterFilter;
  }

  /// ROOM取り込みコレ済のメタデータ補完用。
  ///
  /// 楽天APIには **`shopCode` と純粋な `itemCode` を別パラメータ**で渡す（`shop:item` を itemCode に載せない）。
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
      final qic = n.itemCode ?? '';
      if (qic.contains(':')) {
        roomImportItemApiBlockedLog('reason=colonItemCode itemCode=$qic');
        throw RakutenApiTransportException(
          statusCode: 400,
          message: 'itemCode is not valid',
          responseBodyPreview: 'blocked:colonInQueryItemCode',
        );
      }
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
      'keyword=${_roomImportOmitParam(n.keyword)} genreId=$gid '
      'page=$page hits=$hits sort=$sortDisp',
    );
  }

  List<RakutenSearchItem> _roomImportParseItemsList(Map<String, dynamic> raw) {
    final rawItems = raw['Items'];
    if (rawItems is! List) return const [];
    final parsed = <RakutenSearchItem>[];
    for (final entry in rawItems) {
      try {
        final map = _unwrapItem(entry);
        if (map == null) continue;
        final item = _mapToModel(map);
        if (item != null) parsed.add(item);
      } catch (_) {}
    }
    return parsed;
  }

  RoomImportEnrichmentFetchEnvelope _roomImportEnvelopeAfterSingleFetch({
    required Map<String, dynamic> raw,
    required String matchPureItem,
    required String matchShopCode,
    required bool preferShopFirstForKeyword,
  }) {
    final parsed = _roomImportParseItemsList(raw);
    if (parsed.isEmpty) {
      return const RoomImportEnrichmentFetchEnvelope(httpStatus: 200);
    }
    final RakutenSearchItem? best;
    if (preferShopFirstForKeyword) {
      final sc = matchShopCode.trim();
      RakutenSearchItem? hit;
      for (final it in parsed) {
        if (it.shopCode.trim() == sc) {
          hit = it;
          break;
        }
      }
      best = hit ?? parsed.first;
    } else {
      best = _pickRoomImportEnrichmentItemStrict(parsed, matchPureItem, matchShopCode);
    }
    return RoomImportEnrichmentFetchEnvelope(
      item: best,
      httpStatus: 200,
      rateLimited: false,
    );
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
    Set<String> excludeSavedShopCodes = const {},
    int targetVisibleCount = keywordManagedExclusionTargetVisibleCount,
    int hitsPerPage = 30,
    int startPage = 1,
    int maxFetchPages = keywordManagedExclusionMaxApiPages,
    Duration interPageDelay = const Duration(milliseconds: 220),
  }) async {
    if (kDemoModeEnabled) {
      final filtered = DemoModeData.querySearchItems(condition)
          .where((e) => !excludeRegisteredProductIds.contains(e.productId))
          .where((e) => !excludeSavedShopCodes.contains(e.shopCode))
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
    final exclude = excludeRegisteredProductIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final savedShopExclude = excludeSavedShopCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final visible = <RakutenSearchItem>[];
    final seenIds = <String>{};
    var receivedAnyFromApi = false;
    var page = startPage;
    var apiPagesFetched = 0;
    RakutenKeywordSearchStopReason? explicitStop;

    while (visible.length < targetVisibleCount && page <= maxFetchPages) {
      try {
        if (page > startPage) {
          await Future<void>.delayed(interPageDelay);
        }
        final raw = await _apiService.searchItems(
          condition: normalized,
          page: page,
          hits: hitsPerPage,
        );
        apiPagesFetched++;
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
            if (exclude.contains(id)) {
              pageDroppedRegistered++;
              continue;
            }
            if (seenIds.contains(id)) {
              pageDroppedDup++;
              continue;
            }
            final passed = _applyAppSideFilters([item], normalized);
            if (passed.isEmpty) {
              pageDroppedAppFilter++;
              continue;
            }
            final shopCode = item.shopCode.trim();
            final scopedShop = normalized.shopCode?.trim() ?? '';
            if (shopCode.isNotEmpty && savedShopExclude.contains(shopCode)) {
              // 保存済みショップは通常一覧から除外するが、API 検索でその shopCode を
              // 明示指定しているときは結果は当該ショップの商品に限られるため除外しない。
              if (scopedShop.isEmpty || shopCode != scopedShop) {
                pageDroppedSavedShop++;
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
        if (kDebugMode) {
          debugPrint('[Rakuten] keywordManagedExclusion page=$page failed: $e');
          debugPrint('$st');
        }
        if (page == startPage) {
          rethrow;
        }
        explicitStop = RakutenKeywordSearchStopReason.partialFetchFailure;
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

    return RakutenKeywordSearchRepositoryResult(
      items: visible.length > targetVisibleCount
          ? visible.sublist(0, targetVisibleCount)
          : visible,
      receivedAnyItemFromApi: receivedAnyFromApi,
      targetVisibleCount: targetVisibleCount,
      apiPagesFetched: apiPagesFetched,
      stopReason: stopReason,
    );
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
      debugPrint('[RAKUTEN_URL] itemUrl=${item.itemUrl}');
      debugPrint('[RAKUTEN_URL] affiliateUrl=${item.affiliateUrl}');
      _rakutenGenreLogApi(json, productId);
      _rakutenGenreLogMap(item);
    }
    return item;
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
    debugPrint(
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
    debugPrint(
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

  List<RakutenSearchItem> _applyAppSideFilters(
    List<RakutenSearchItem> source,
    RakutenProductSearchCondition condition,
  ) {
    final thresholdComment = condition.minCommentCount;
    final thresholdReview = condition.minReviewCount;
    final requiredReviewCount = switch ((thresholdComment, thresholdReview)) {
      (null, null) => null,
      (final c?, null) => c,
      (null, final r?) => r,
      (final c?, final r?) => c > r ? c : r,
    };

    return source.where((item) {
      if (requiredReviewCount != null &&
          item.reviewCount < requiredReviewCount) {
        return false;
      }
      if (condition.minReviewAverage != null &&
          item.reviewAverage < condition.minReviewAverage!) {
        return false;
      }
      // shopCode はクエリで API が既に絞り込む。Item 側の shopCode が空・表記差で
      // 一致しない場合があり、クライアント再判定で全件落ちうるためここでは判定しない。
      // genreId はクエリパラメータで API が既に絞り込む。レスポンス各 Item の genreId は
      // 子ジャンルIDのみで親 genreId を部分文字列に含まないことが多く、クライアント側の
      // 文字列一致・contains では誤って全件落ちるためここでは判定しない。
      return true;
    }).toList();
  }
}
