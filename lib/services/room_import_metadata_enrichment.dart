import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../config/room_import_enrichment_verify_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/rakuten_item_url_parser.dart';
import '../services/room_url_resolver.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/rakuten_ichiba_url_parse.dart';
import '../utils/room_import_enrich_keyword_normalize.dart';
import '../utils/room_import_learned_api_code.dart';
import '../utils/room_import_product_url_match.dart';
import '../utils/room_rat_redirect_parse.dart';
import '../utils/room_sync_log.dart';
import 'room_import_enrichment_cooldown_store.dart';
import 'room_import_limit_policy.dart';

/// 1件の補完対象フラグ（ログ・UI 向け）。
class RoomImportEnrichmentNeedFlags {
  const RoomImportEnrichmentNeedFlags({
    required this.needsPrice,
    required this.needsImage,
    required this.needsShopName,
    required this.needsGenre,
  });

  final bool needsPrice;
  final bool needsImage;
  final bool needsShopName;
  final bool needsGenre;

  bool get willEnrich =>
      needsPrice || needsImage || needsShopName || needsGenre;
}

/// [enrichRoomImportedProducts] の実行結果。
class RoomImportEnrichmentBatchResult {
  const RoomImportEnrichmentBatchResult({
    required this.updated,
    required this.failedInBatch,
    required this.attempted,
    required this.skippedAlreadyComplete,
    required this.pausedByRateLimit,
    required this.remainingPending,
    this.skippedCooldown = false,
    this.duplicateSessionSkipped = false,
    /// 検証モード（`ROOM_IMPORT_ENRICH_VERIFY`）時のみ。マイページ SnackBar 用短文。
    this.verifyUiMessage,
    this.successProductIds = const <String>[],
    this.productEnrichmentSlots = 0,
    this.skippedRestrictedAlreadyComplete = 0,
    this.initialEnrichStopReason = 'completed',
  });

  final int updated;
  /// 今回の実行でメタ更新に至らなかった商品数（429 で止まる直前の失敗も含む）。
  final int failedInBatch;
  /// 楽天API のHTTP試行回数（フォールバックで複数回あるときは 1 商品で増える）。
  final int attempted;
  final int skippedAlreadyComplete;
  final bool pausedByRateLimit;
  final int remainingPending;
  final bool skippedCooldown;
  final bool duplicateSessionSkipped;

  /// 非検証モードでは常に null。
  final String? verifyUiMessage;

  /// 今回の実行でメタマージに成功した productId（ログ・UI ハイライト用）。
  final List<String> successProductIds;

  /// 今回のループで「補完対象としてスロット消費した」商品数（429 直前の失敗を含む）。
  final int productEnrichmentSlots;

  /// [restrictToProductIdsInOrder] 指定時、開始時点で API 不要だった制限内商品数。
  final int skippedRestrictedAlreadyComplete;

  /// `completed` / `maxDurationReached` / `rateLimited`。
  final String initialEnrichStopReason;
}

/// 取り込み後メタ補完で試す検索経路（ログ名と一致）。
enum _RoomImportEnrichMethod { shopItem, shopTitleKeyword, productIdKeyword }

class _ResolvedImportCodes {
  const _ResolvedImportCodes({
    required this.shopItemSearchItemCodeParam,
    required this.matchPureItemForPick,
    required this.matchShopCodeForPick,
    required this.keywordShopCode,
    required this.logProductId,
    required this.urlPathMatchSegment,
    required this.source,
  });

  /// `shop:pure` 形式のときのみ Item Search direct に使う。空なら shopItem 経路は使わない。
  final String shopItemSearchItemCodeParam;

  final String matchPureItemForPick;
  final String matchShopCodeForPick;
  final String keywordShopCode;

  /// ログ用（永続化 productId）。
  final String logProductId;

  /// keyword 系で URL 照合するときの `item.rakuten` パスセグメント。
  final String urlPathMatchSegment;
  final String source;
}

/// Phase 3 向けに ROOM 取り込みコレのメタデータをバッチで API 補完するサービス。
///
/// 取り込み本体は楽天APIを呼ばず、本サービスが **低速キュー**（1件ずつ・間隔・429 後クールダウン）で補完する。
class RoomImportMetadataEnrichmentService {
  RoomImportMetadataEnrichmentService({
    required RakutenSearchRepository searchRepository,
    required RakutenManagedProductRepository productRepository,
  }) : _searchRepository = searchRepository,
       _productRepository = productRepository;

  final RakutenSearchRepository _searchRepository;
  final RakutenManagedProductRepository _productRepository;

  static bool _singleFlight = false;

  /// いずれかの [enrichRoomImportedProducts] が実行中か（single-flight）。
  static bool get isEnrichmentSingleFlightHeld => _singleFlight;

  /// [items] のうち ROOM 取り込みコレ済でメタ未補完の件数。
  static int countPendingEnrichment(Iterable<RakutenManagedProduct> items) {
    return items.where(_baseEligibleForEnrichmentQueue).where((e) {
      return needFlagsForProduct(e).willEnrich;
    }).length;
  }

  /// ログ・UI 用の不足フラグ。
  static RoomImportEnrichmentNeedFlags needFlagsForProduct(
    RakutenManagedProduct e,
  ) {
    return RoomImportEnrichmentNeedFlags(
      needsPrice: _needsPriceEnrichment(e.itemPrice),
      needsImage: _needsImageEnrichment(e.imageUrl),
      needsShopName: _needsShopNameEnrichment(e.shopName, e.shopCode),
      needsGenre: _needsGenreNameEnrichment(e.genreName),
    );
  }

  static bool _needsPriceEnrichment(int price) => price <= 0;

  static bool _needsImageEnrichment(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return true;
    final u = Uri.tryParse(t);
    if (u == null) return true;
    final s = u.scheme.toLowerCase();
    return s != 'http' && s != 'https';
  }

  static bool _needsShopNameEnrichment(String? shopName, String shopCode) {
    final t = (shopName ?? '').trim();
    final sc = shopCode.trim();
    if (t.isEmpty) return true;
    if (t == 'ショップ未設定' || t == 'ショップ名不明') return true;
    if (sc.isNotEmpty && t == sc) return true;
    return false;
  }

  static bool _needsGenreNameEnrichment(String? genreName) {
    final t = (genreName ?? '').trim();
    return t.isEmpty || t == 'ジャンル未設定';
  }

  /// 補完不要（API を呼ばない）か。
  static bool isMetadataCompleteForApiSkip(RakutenManagedProduct e) {
    return !needFlagsForProduct(e).willEnrich;
  }

  static bool _baseEligibleForEnrichmentQueue(RakutenManagedProduct e) {
    if (e.coredActivitySource != RakutenCoredActivitySource.roomImport) {
      return false;
    }
    if (!RakutenManagedProduct.isMemberForStatusTab(
      e,
      RakutenManagedProductStatus.done,
    )) {
      return false;
    }
    if (e.shopCode.trim().isEmpty &&
        e.roomRedirectShopCode.trim().isEmpty &&
        _keywordShopCode(e).trim().isEmpty) {
      return false;
    }
    if (e.productId.trim().isEmpty) {
      return false;
    }
    return true;
  }

  /// ROOM 取り込みコレ済のメタを最大 [limit] **商品**まで API で補完する。
  ///
  /// [applyPostImportAutoCap] が true のとき
  /// [RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls]（＝無料バッチ件数）を上限にする。
  /// 手動でも [RoomImportLimitPolicy.manualEnrichMaxProductsPerRun] を超えないよう内部でキャップする。
  ///
  /// [manualSessionPacing] が true のときは商品間ディレイを [RoomImportLimitPolicy.manualEnrichInterItemDelayMs] にする。
  ///
  /// [maxRunDuration] 経過後は未補完のまま打ち切る（初回取り込み直後の体感向け）。
  Future<RoomImportEnrichmentBatchResult> enrichRoomImportedProducts({
    required int limit,
    bool applyPostImportAutoCap = false,
    bool manualSessionPacing = false,
    List<String>? restrictToProductIdsInOrder,
    Duration? maxRunDuration,
    void Function(int completedSlots, int maxSlots)? onEnrichSlotProgress,
  }) async {
    var maxProductsPerRun = limit <= 0
        ? 0
        : (applyPostImportAutoCap
              ? (limit > RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls
                    ? RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls
                    : limit)
              : (limit > RoomImportLimitPolicy.manualEnrichMaxProductsPerRun
                    ? RoomImportLimitPolicy.manualEnrichMaxProductsPerRun
                    : limit));
    final restrict = restrictToProductIdsInOrder
        ?.map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (restrict != null && restrict.isNotEmpty) {
      maxProductsPerRun = maxProductsPerRun > restrict.length
          ? restrict.length
          : maxProductsPerRun;
    }
    if (RoomImportEnrichmentVerifyConfig.enabled && maxProductsPerRun < 1) {
      maxProductsPerRun = 1;
    }

    if (maxProductsPerRun <= 0) {
      if (applyPostImportAutoCap) {
        roomImportPerfLog('enrichmentSkipped reason=autoDisabled');
      }
      final pending0 = _pendingQueueRows().length;
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: 0,
        pausedByRateLimit: false,
        remainingPending: pending0,
        successProductIds: const [],
      );
    }

    if (_singleFlight) {
      roomImportPerfLog('enrichmentSkipped reason=singleFlightBusy');
      roomImportEnrichSkipLog('reason=singleFlightBusy');
      final pending = _pendingQueueRows().length;
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: 0,
        pausedByRateLimit: false,
        remainingPending: pending,
        duplicateSessionSkipped: true,
        successProductIds: const [],
      );
    }

    if (!RoomImportEnrichmentVerifyConfig.enabled &&
        await RoomImportEnrichmentCooldownStore.isInCooldown()) {
      final pending = _pendingQueueRows().length;
      final until = await RoomImportEnrichmentCooldownStore.cooldownUntil();
      final mins = until != null
          ? until.difference(DateTime.now()).inMinutes.clamp(1, 9999)
          : RoomImportLimitPolicy.enrichCooldownAfter429Minutes;
      roomImportEnrichPausedLog(
        'reason=cooldown cooldownMinutes=$mins remainingPending=$pending',
      );
      roomImportEnrichSkipLog('reason=cooldownActive');
      roomImportEnrichSummaryLog(
        'attempted=0 updated=0 skipped=0 pausedByRateLimit=false '
        'remainingPending=$pending cooldown=true',
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: 0,
        pausedByRateLimit: false,
        remainingPending: pending,
        skippedCooldown: true,
        successProductIds: const [],
      );
    }

    _singleFlight = true;
    try {
      return await _runEnrichmentLoop(
        maxProductsPerRun: maxProductsPerRun,
        manualSessionPacing: manualSessionPacing,
        restrictToProductIdsInOrder: restrict,
        maxRunDuration: maxRunDuration,
        onEnrichSlotProgress: onEnrichSlotProgress,
        allowRoomDetailRedirectRecovery: restrict != null &&
            restrict.isNotEmpty &&
            applyPostImportAutoCap,
      );
    } finally {
      _singleFlight = false;
    }
  }

  List<RakutenManagedProduct> _pendingQueueRows() {
    final rows = _productRepository.loadAll();
    final pending = rows.where(_baseEligibleForEnrichmentQueue).where((e) {
      return needFlagsForProduct(e).willEnrich;
    }).toList();
    try {
      pending.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    } catch (_) {}
    return pending;
  }

  static String _methodLogName(_RoomImportEnrichMethod m) {
    switch (m) {
      case _RoomImportEnrichMethod.shopItem:
        return 'shopItem';
      case _RoomImportEnrichMethod.shopTitleKeyword:
        return 'shopTitleKeyword';
      case _RoomImportEnrichMethod.productIdKeyword:
        return 'productIdKeyword';
    }
  }

  static String _storedSlugForUrlMatch(RakutenManagedProduct row) {
    final s = row.roomProductSlug.trim();
    if (s.isNotEmpty) return s;
    return roomImportUrlPathMatchSegment(row.productId);
  }

  static String _keywordShopCode(RakutenManagedProduct row) {
    for (final s in [row.shopCode.trim(), row.roomRedirectShopCode.trim()]) {
      if (s.isNotEmpty) return s;
    }
    for (final u in [row.itemUrl, row.rakutenUrl ?? '', row.affiliateUrl ?? '']) {
      final t = u.trim();
      if (t.isEmpty) continue;
      final p = RakutenItemUrlParser.tryParse(t);
      if (p != null && p.shopCode.trim().isNotEmpty) return p.shopCode.trim();
    }
    return '';
  }

  _ResolvedImportCodes _resolveImportCodes(RakutenManagedProduct row) {
    final logPid = row.productId.trim();
    final slug = _storedSlugForUrlMatch(row);

    final compStored = row.roomApiCompositeItemCode.trim();
    if (compStored.isNotEmpty && rakutenIchibaUrlLooksLikeApiItemCode(compStored)) {
      final idx = compStored.indexOf(':');
      final shop = compStored.substring(0, idx).trim();
      final pure = compStored.substring(idx + 1).trim();
      return _ResolvedImportCodes(
        shopItemSearchItemCodeParam: compStored,
        matchPureItemForPick: pure,
        matchShopCodeForPick: shop,
        keywordShopCode: shop.isNotEmpty ? shop : _keywordShopCode(row),
        logProductId: logPid,
        urlPathMatchSegment: slug,
        source: 'savedApiCompositeAvailable',
      );
    }

    final legacyPid = row.productId.trim();
    if (rakutenIchibaUrlLooksLikeApiItemCode(legacyPid)) {
      final idx = legacyPid.indexOf(':');
      final shop = legacyPid.substring(0, idx).trim();
      final pure = legacyPid.substring(idx + 1).trim();
      return _ResolvedImportCodes(
        shopItemSearchItemCodeParam: legacyPid,
        matchPureItemForPick: pure,
        matchShopCodeForPick: shop,
        keywordShopCode: shop.isNotEmpty ? shop : _keywordShopCode(row),
        logProductId: logPid,
        urlPathMatchSegment: slug,
        source: 'storedProductIdComposite',
      );
    }

    final kwShop = _keywordShopCode(row);
    return _ResolvedImportCodes(
      shopItemSearchItemCodeParam: '',
      matchPureItemForPick: '',
      matchShopCodeForPick: '',
      keywordShopCode: kwShop,
      logProductId: logPid,
      urlPathMatchSegment: slug,
      source: 'urlSlugOnly',
    );
  }

  bool _inProductBackoff(RakutenManagedProduct e, DateTime now) {
    final u = e.roomImportEnrichBackoffUntil;
    return u != null && now.isBefore(u);
  }

  bool _shopItemAllowed(RakutenManagedProduct e, DateTime now) {
    final u = e.roomImportEnrichShopItemBlockedUntil;
    return u == null || !now.isBefore(u);
  }

  bool _titleKeywordAllowed(RakutenManagedProduct e, DateTime now) {
    final u = e.roomImportEnrichTitleKeywordBlockedUntil;
    return u == null || !now.isBefore(u);
  }

  bool _productIdKeywordAllowed(RakutenManagedProduct e, DateTime now) {
    final u = e.roomImportEnrichProductIdKeywordBlockedUntil;
    return u == null || !now.isBefore(u);
  }

  String? _titleKeywordRaw(String itemName) {
    final t = itemName.trim();
    if (t.isEmpty) return null;
    if (t == '（ROOM投稿）') return null;
    if (t.length < RoomImportLimitPolicy.enrichTitleKeywordMinChars) return null;
    if (t.length > 120) return t.substring(0, 120);
    return t;
  }

  /// shopItem → keyword+shopCode フォールバック時の検索語（商品タイトル優先、なければ検証モードと同じ既定）。
  String _roomImportFallbackKeyword(RakutenManagedProduct row, String productId) {
    final t = _titleKeywordRaw(row.itemName);
    final rawCandidate = (t != null && t.trim().isNotEmpty)
        ? t.trim()
        : RoomImportEnrichmentVerifyConfig.patternCKeyword.trim();
    final fallbackDefault =
        rawCandidate.isNotEmpty ? rawCandidate : 'タリーズコーヒー';
    final nk = RoomImportEnrichKeywordNormalize.normalize(fallbackDefault);
    final use = nk.isNotEmpty ? nk : fallbackDefault;
    roomImportEnrichFallbackKeywordLog({
      'productId': productId,
      'rawKeyword': fallbackDefault,
      'normalizedKeyword': use,
      'rawLength': '${fallbackDefault.length}',
      'normalizedLength': '${use.length}',
      'phase': 'shopItemFallback',
    });
    return use;
  }

  /// shopTitleKeyword 経路のキーワード（タイトル由来を正規化）。
  String _keywordForShopTitleSearch(RakutenManagedProduct chosen, String pid) {
    final rawKw = _titleKeywordRaw(chosen.itemName)!;
    final nk = RoomImportEnrichKeywordNormalize.normalize(rawKw);
    final kw = nk.length >= RoomImportLimitPolicy.enrichTitleKeywordMinChars
        ? nk
        : rawKw;
    roomImportEnrichFallbackKeywordLog({
      'productId': pid,
      'rawKeyword': rawKw,
      'normalizedKeyword': nk,
      'rawLength': '${rawKw.length}',
      'normalizedLength': '${nk.length}',
      'phase': 'shopTitleKeyword',
    });
    return kw;
  }

  void _roomImportEnrichFallbackMergeSuccessLog({
    required String productId,
    required RakutenSearchItem api,
    required RakutenManagedProduct saved,
  }) {
    final dg = _verifyGenreDiagnostics(api);
    roomImportEnrichFallbackResultLog(
      LinkedHashMap<String, String>.from({
        'status': 'success',
        'method': 'keywordShopCodeUrlMatch',
        'productId': productId,
        'matchedItemCode': api.productId.trim(),
        'matchedItemUrl': api.itemUrl.trim(),
        'matchedAffiliateUrl': api.affiliateUrl.trim().isEmpty
            ? '(empty)'
            : api.affiliateUrl.trim(),
        'price': '${api.itemPrice}',
        'shopName': api.shopName.trim(),
        'apiGenreName': dg.apiGenreName.isEmpty ? '(empty)' : dg.apiGenreName,
        'mappedGenreName':
            dg.mappedGenreName.isEmpty ? '(empty)' : dg.mappedGenreName,
        'savedGenreName': saved.genreName.trim(),
      }),
    );
  }

  _RoomImportEnrichMethod? _peekNextMethod(RakutenManagedProduct row, DateTime now) {
    final codes = _resolveImportCodes(row);
    if (_shopItemAllowed(row, now) &&
        codes.shopItemSearchItemCodeParam.trim().isNotEmpty) {
      return _RoomImportEnrichMethod.shopItem;
    }
    final title = _titleKeywordRaw(row.itemName);
    if (_titleKeywordAllowed(row, now) &&
        title != null &&
        codes.keywordShopCode.isNotEmpty) {
      return _RoomImportEnrichMethod.shopTitleKeyword;
    }
    if (!_productIdKeywordAllowed(row, now)) return null;
    if (codes.keywordShopCode.isEmpty || row.productId.trim().length < 5) {
      return null;
    }
    final cannotUseShopItemNow =
        codes.shopItemSearchItemCodeParam.trim().isEmpty ||
        !_shopItemAllowed(row, now);
    if (!cannotUseShopItemNow) return null;
    final cannotUseTitleNow = title == null || !_titleKeywordAllowed(row, now);
    if (!cannotUseTitleNow) return null;
    return _RoomImportEnrichMethod.productIdKeyword;
  }

  List<RakutenManagedProduct> _sortedEnrichmentCandidates(
    List<RakutenManagedProduct> pending,
    DateTime now,
  ) {
    final out = List<RakutenManagedProduct>.from(pending);
    int score(RakutenManagedProduct e) {
      var s = e.roomImportEnrichFailureCount * 500;
      if (_inProductBackoff(e, now)) s += 100000;
      return s;
    }

    out.sort((a, b) {
      final c = score(a).compareTo(score(b));
      if (c != 0) return c;
      return a.updatedAt.compareTo(b.updatedAt);
    });
    return out;
  }

  Future<void> _applyNonShopItemHttp400(
    RakutenManagedProduct row,
    DateTime now,
    _RoomImportEnrichMethod method,
  ) async {
    final pid = row.productId.trim();
    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(
        roomImportMetadataEnriching: false,
        roomImportEnrichLastAttemptAt: now,
        roomImportEnrichFailureReason: '400',
        roomImportEnrichFailureCount: e.roomImportEnrichFailureCount + 1,
        roomImportEnrichLastMethod: _methodLogName(method),
        roomImportEnrichBackoffUntil: now.add(
          Duration(
            minutes: RoomImportLimitPolicy.enrichBackoffMinutesAfterAttemptFailure,
          ),
        ),
      );
    });
  }

  Future<void> _applyShopItemHttp400(RakutenManagedProduct row, DateTime now) async {
    final pid = row.productId.trim();
    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(
        roomImportMetadataEnriching: false,
        roomImportEnrichLastAttemptAt: now,
        roomImportEnrichFailureReason: '400',
        roomImportEnrichFailureCount: e.roomImportEnrichFailureCount + 1,
        roomImportEnrichLastMethod: 'shopItem',
        roomImportEnrichShopItemBlockedUntil: now.add(
          Duration(
            hours: RoomImportLimitPolicy.enrichShopItemBlockHoursAfterHttp400,
          ),
        ),
        roomImportEnrichBackoffUntil: now.add(
          Duration(
            minutes: RoomImportLimitPolicy.enrichBackoffMinutesAfterAttemptFailure,
          ),
        ),
      );
    });
  }

  Future<void> _applyNoItems(
    RakutenManagedProduct row,
    DateTime now,
    _RoomImportEnrichMethod method,
  ) async {
    final pid = row.productId.trim();
    await _productRepository.updateManagedProduct(pid, (e) {
      var next = e.copyWith(
        roomImportMetadataEnriching: false,
        roomImportEnrichLastAttemptAt: now,
        roomImportEnrichFailureReason: 'noItems',
        roomImportEnrichFailureCount: e.roomImportEnrichFailureCount + 1,
        roomImportEnrichLastMethod: _methodLogName(method),
        roomImportEnrichBackoffUntil: now.add(
          Duration(
            minutes: RoomImportLimitPolicy.enrichBackoffMinutesAfterAttemptFailure,
          ),
        ),
      );
      switch (method) {
        case _RoomImportEnrichMethod.shopTitleKeyword:
          next = next.copyWith(
            roomImportEnrichTitleKeywordBlockedUntil: now.add(
              Duration(
                minutes: RoomImportLimitPolicy
                    .enrichTitleKeywordBlockMinutesAfterNoItems,
              ),
            ),
          );
          break;
        case _RoomImportEnrichMethod.productIdKeyword:
          next = next.copyWith(
            roomImportEnrichProductIdKeywordBlockedUntil: now.add(
              Duration(
                minutes: RoomImportLimitPolicy
                    .enrichProductIdKeywordBlockMinutesAfterNoItems,
              ),
            ),
          );
          break;
        case _RoomImportEnrichMethod.shopItem:
          break;
      }
      return next;
    });
  }

  Future<void> _applyEnrichException(
    RakutenManagedProduct row,
    DateTime now,
    _RoomImportEnrichMethod method,
  ) async {
    final pid = row.productId.trim();
    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(
        roomImportMetadataEnriching: false,
        roomImportEnrichLastAttemptAt: now,
        roomImportEnrichFailureReason: 'exception',
        roomImportEnrichFailureCount: e.roomImportEnrichFailureCount + 1,
        roomImportEnrichLastMethod: _methodLogName(method),
        roomImportEnrichBackoffUntil: now.add(
          Duration(
            minutes: RoomImportLimitPolicy.enrichBackoffMinutesAfterAttemptFailure,
          ),
        ),
      );
    });
  }

  Future<void> _apply429Row(
    RakutenManagedProduct row,
    DateTime now,
    _RoomImportEnrichMethod method,
  ) async {
    final pid = row.productId.trim();
    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(
        roomImportMetadataEnriching: false,
        roomImportEnrichLastAttemptAt: now,
        roomImportEnrichFailureReason: '429',
        roomImportEnrichFailureCount: e.roomImportEnrichFailureCount + 1,
        roomImportEnrichLastMethod: _methodLogName(method),
      );
    });
  }

  static String _marketShopCodeForLog(RakutenManagedProduct row) {
    for (final u in [row.itemUrl, row.rakutenUrl ?? '', row.affiliateUrl ?? '']) {
      final p = RakutenItemUrlParser.tryParse(u.trim());
      if (p != null && p.shopCode.trim().isNotEmpty) return p.shopCode.trim();
    }
    return row.shopCode.trim();
  }

  static String _urlProductCodeForLog(RakutenManagedProduct row) {
    final s = row.roomProductSlug.trim();
    if (s.isNotEmpty) return s;
    for (final u in [row.itemUrl, row.rakutenUrl ?? '']) {
      final p = RakutenItemUrlParser.tryParse(u.trim());
      if (p != null && p.itemPathSegment.trim().isNotEmpty) {
        return p.itemPathSegment.trim();
      }
    }
    return '';
  }

  Future<RoomImportEnrichmentFetchEnvelope?> _tryRecoverViaRoomDetailThenShopItem({
    required RakutenManagedProduct row,
    required String pid,
    required String urlPathMatchSegment,
  }) async {
    final roomUrl = row.roomUrl.trim();
    roomImportEnrichDetailFetchForRedirectLog(
      'productId=$pid roomPostUrl=$roomUrl reason=keywordFailedAndNoApiComposite',
    );
    if (roomUrl.isEmpty) {
      roomImportEnrichDetailFetchResultLog(
        'productId=$pid status=noRedirect apiCompositeItemCode= rakutenItemUrl=',
      );
      return null;
    }
    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(roomEnrichDetailRedirectAttempted: true);
    });
    final resolver = RoomUrlResolver();
    final outcome = await resolver.resolveRakutenItemUrlFromRoomPage(roomUrl);
    if (outcome is! RoomUrlResolveSuccess) {
      roomImportEnrichDetailFetchResultLog(
        'productId=$pid status=httpError apiCompositeItemCode= rakutenItemUrl=',
      );
      return null;
    }
    final ok = outcome;
    final composite = ok.roomApiCompositeItemCode.trim();
    if (composite.isEmpty) {
      roomImportEnrichDetailFetchResultLog(
        'productId=$pid status=noRedirect apiCompositeItemCode= '
        'rakutenItemUrl=${ok.rakutenItem.rakutenUrl.trim()}',
      );
      return null;
    }
    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(
        roomRatRedirectUrl: ok.roomRatRedirectUrl.trim().isNotEmpty
            ? ok.roomRatRedirectUrl.trim()
            : e.roomRatRedirectUrl,
        roomRedirectShopCode: ok.roomRedirectShopCode.trim().isNotEmpty
            ? ok.roomRedirectShopCode.trim()
            : e.roomRedirectShopCode,
        roomRedirectItemCode: ok.roomRedirectItemCode.trim().isNotEmpty
            ? ok.roomRedirectItemCode.trim()
            : e.roomRedirectItemCode,
        roomApiCompositeItemCode: composite,
        roomProductSlug: ok.roomProductSlug.trim().isNotEmpty
            ? ok.roomProductSlug.trim()
            : e.roomProductSlug,
        genreId: e.genreId.trim().isEmpty && ok.roomEventGenreId.trim().isNotEmpty
            ? ok.roomEventGenreId.trim()
            : e.genreId,
        itemUrl: ok.rakutenItem.rakutenUrl.trim().isNotEmpty
            ? ok.rakutenItem.rakutenUrl.trim()
            : e.itemUrl,
        rakutenUrl: ok.rakutenItem.rakutenUrl.trim().isNotEmpty
            ? ok.rakutenItem.rakutenUrl.trim()
            : e.rakutenUrl,
      );
    });
    roomImportEnrichDetailFetchResultLog(
      'productId=$pid status=foundRedirect apiCompositeItemCode=$composite '
      'rakutenItemUrl=${ok.rakutenItem.rakutenUrl.trim()}',
    );
    final fresh = _productRepository.getByProductId(pid);
    if (fresh == null) return null;
    final now = DateTime.now();
    final codes = _resolveImportCodes(fresh);
    if (!_shopItemAllowed(fresh, now) || codes.shopItemSearchItemCodeParam.trim().isEmpty) {
      return null;
    }
    final sic = codes.shopItemSearchItemCodeParam.trim();
    final shopItemCondition = sic.contains(':')
        ? RakutenProductSearchCondition(
            keyword: '',
            shopCode: null,
            itemCode: sic,
          )
        : RakutenProductSearchCondition(
            keyword: '',
            shopCode: codes.matchShopCodeForPick,
            itemCode: codes.matchPureItemForPick,
          );
    final fbKw = _roomImportFallbackKeyword(fresh, pid);
    final fbOut =
        await _searchRepository.fetchRoomImportShopItemWithKeywordUrlFallback(
      shopItemCondition: shopItemCondition,
      matchPureItemForPick: codes.matchPureItemForPick,
      matchShopCodeForPick: codes.matchShopCodeForPick,
      storedProductIdForUrlMatch: pid,
      urlPathMatchSegment: urlPathMatchSegment,
      fallbackKeyword: fbKw,
      verifyMode: RoomImportEnrichmentVerifyConfig.enabled,
      phaseShopItem: 'shopItemAfterRedirect',
    );
    return fbOut.envelope;
  }

  Future<RoomImportEnrichmentBatchResult> _runEnrichmentLoop({
    required int maxProductsPerRun,
    required bool manualSessionPacing,
    List<String>? restrictToProductIdsInOrder,
    Duration? maxRunDuration,
    void Function(int completedSlots, int maxSlots)? onEnrichSlotProgress,
    bool allowRoomDetailRedirectRecovery = false,
  }) async {
    final rows = _productRepository.loadAll();
    var skippedRestrictedAlreadyComplete = 0;
    final restrictEarly = restrictToProductIdsInOrder;
    if (restrictEarly != null && restrictEarly.isNotEmpty) {
      final byId = <String, RakutenManagedProduct>{};
      for (final r in rows) {
        byId[r.productId.trim()] = r;
      }
      for (final rawId in restrictEarly) {
        final idt = rawId.trim();
        if (idt.isEmpty) continue;
        final row = byId[idt];
        if (row == null) continue;
        if (!_baseEligibleForEnrichmentQueue(row)) continue;
        if (!needFlagsForProduct(row).willEnrich) {
          skippedRestrictedAlreadyComplete++;
        }
      }
    }

    var skippedComplete = 0;
    for (final row in rows) {
      if (!_baseEligibleForEnrichmentQueue(row)) continue;
      final flags = needFlagsForProduct(row);
      if (!flags.willEnrich) {
        skippedComplete++;
      }
    }

    final pendingSnapshot = _pendingQueueRows();
    final queueDiagNow = DateTime.now();
    var inBackoff = 0;
    var noMethod = 0;
    var eligible = 0;
    for (final e in pendingSnapshot) {
      if (_inProductBackoff(e, queueDiagNow)) {
        inBackoff++;
        continue;
      }
      if (_peekNextMethod(e, queueDiagNow) == null) {
        noMethod++;
        continue;
      }
      eligible++;
    }
    roomImportEnrichQueueLog(
      'pending=${pendingSnapshot.length} eligible=$eligible '
      'skippedCooldown=$inBackoff skippedFailed=$noMethod',
    );

    if (RoomImportEnrichmentVerifyConfig.enabled) {
      return _runVerifyOnlyEnrichment(skippedComplete: skippedComplete);
    }

    final interItemDelayMs = manualSessionPacing
        ? RoomImportLimitPolicy.manualEnrichInterItemDelayMs
        : RoomImportLimitPolicy.enrichMinDelayMsBetweenCalls;

    DateTime? runDeadline;
    final md = maxRunDuration;
    if (md != null) {
      runDeadline = DateTime.now().add(md);
    }
    var stopReasonTag = 'completed';

    var okCount = 0;
    var failCount = 0;
    var apiAttempts = 0;
    var pausedByRateLimit = false;
    final successIds = <String>[];
    var processedProducts = 0;

    try {
      while (processedProducts < maxProductsPerRun && !pausedByRateLimit) {
        if (runDeadline != null && !DateTime.now().isBefore(runDeadline)) {
          stopReasonTag = 'maxDurationReached';
          break;
        }
        final pendingAll = _pendingQueueRows();
        final now = DateTime.now();
        final sorted = _sortedEnrichmentCandidates(pendingAll, now);
        _RoomImportEnrichMethod? chosenMethod;
        RakutenManagedProduct? chosen;
        var pickLogged = 0;
        final restrict = restrictToProductIdsInOrder;
        if (restrict != null && restrict.isNotEmpty) {
          for (final wantId in restrict) {
            for (final row in sorted) {
              if (row.productId.trim() != wantId) continue;
              final m = _peekNextMethod(row, now);
              if (pickLogged < 24) {
                roomImportEnrichPickLog(
                  'productId=${row.productId} '
                  'failureReason=${row.roomImportEnrichFailureReason} '
                  'failureCount=${row.roomImportEnrichFailureCount} '
                  'selected=${m != null}',
                );
                pickLogged++;
              }
              if (m != null) {
                chosen = row;
                chosenMethod = m;
                break;
              }
            }
            if (chosen != null) break;
          }
        } else {
          for (final row in sorted) {
            final m = _peekNextMethod(row, now);
            if (pickLogged < 24) {
              roomImportEnrichPickLog(
                'productId=${row.productId} '
                'failureReason=${row.roomImportEnrichFailureReason} '
                'failureCount=${row.roomImportEnrichFailureCount} '
                'selected=${m != null}',
              );
              pickLogged++;
            }
            if (m != null) {
              chosen = row;
              chosenMethod = m;
              break;
            }
          }
        }
        if (chosen == null || chosenMethod == null) {
          roomImportEnrichMethodLog('method=skip');
          break;
        }

        if (processedProducts > 0) {
          await Future<void>.delayed(
            Duration(milliseconds: interItemDelayMs),
          );
        }
        processedProducts++;
        onEnrichSlotProgress?.call(processedProducts, maxProductsPerRun);

        final pid = chosen.productId.trim();
        final codes = _resolveImportCodes(chosen);
        final shop = codes.keywordShopCode.trim().isNotEmpty
            ? codes.keywordShopCode.trim()
            : chosen.shopCode.trim();
        if (shop.isEmpty || pid.isEmpty) break;

        final slugDisp = chosen.roomProductSlug.trim();
        final compositeDisp = chosen.roomApiCompositeItemCode.trim();
        final shopCodeLog = _marketShopCodeForLog(chosen);
        final urlProductCodeLog = _urlProductCodeForLog(chosen);
        final hasRatRedirect = chosen.roomRatRedirectUrl.trim().isNotEmpty ||
            chosen.roomRedirectShopCode.trim().isNotEmpty ||
            chosen.roomRedirectItemCode.trim().isNotEmpty;
        late final String redirectParseSource;
        late final String redirectParseReason;
        if (hasRatRedirect) {
          redirectParseSource = 'ratRedirect';
          redirectParseReason = 'parsedFromRedirect';
        } else if (compositeDisp.isNotEmpty) {
          redirectParseSource = 'roomPage';
          redirectParseReason = 'parsedFromRoomPage';
        } else {
          redirectParseSource = 'collects';
          redirectParseReason = 'collectsDoesNotContainRatRedirect';
        }
        roomRedirectParseSourceLog(
          'productId=$pid source=$redirectParseSource hasRatRedirect=$hasRatRedirect '
          'apiCompositeItemCode=${compositeDisp.isEmpty ? '(empty)' : compositeDisp} '
          'reason=$redirectParseReason',
        );
        if (chosenMethod == _RoomImportEnrichMethod.shopItem) {
          roomImportEnrichSourceDecisionLog({
            'productId': pid,
            'shopCode': shopCodeLog.isEmpty ? '(empty)' : shopCodeLog,
            'urlProductCode': urlProductCodeLog.isEmpty ? '(empty)' : urlProductCodeLog,
            'apiCompositeItemCode':
                compositeDisp.isEmpty ? '(empty)' : compositeDisp,
            'decision': 'directApiItemCode',
            'reason': codes.source,
          });
        } else {
          if (compositeDisp.isEmpty &&
              slugDisp.isNotEmpty &&
              roomImportEnrichSlugShouldSkipDirectItemCode(slugDisp)) {
            roomImportEnrichDirectSkipLog({
              'productId': pid,
              'urlProductCode': urlProductCodeLog.isEmpty ? slugDisp : urlProductCodeLog,
              'reason': 'urlProductCodeIsNotApiItemCode',
            });
          }
          roomImportEnrichSourceDecisionLog({
            'productId': pid,
            'shopCode': shopCodeLog.isEmpty ? '(empty)' : shopCodeLog,
            'urlProductCode': urlProductCodeLog.isEmpty ? '(empty)' : urlProductCodeLog,
            'apiCompositeItemCode':
                compositeDisp.isEmpty ? '(empty)' : compositeDisp,
            'decision': 'keywordShopCode',
            'reason': compositeDisp.isEmpty
                ? 'urlProductCodeOnly'
                : 'savedApiCompositeAvailable',
          });
        }

        final attemptNow = DateTime.now();

        final flags = needFlagsForProduct(chosen);
        roomImportEnrichTargetLog(
          'productId=$pid needsPrice=${flags.needsPrice} needsImage=${flags.needsImage} '
          'needsShopName=${flags.needsShopName} needsGenre=${flags.needsGenre} '
          'willEnrich=${flags.willEnrich}',
        );

        try {
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: true);
          });
        } catch (_) {
          break;
        }

        final delayMs =
            processedProducts <= 1 ? 0 : interItemDelayMs;
        roomImportEnrichApiLog(
          'productId=$pid index=$processedProducts maxPerRun=$maxProductsPerRun '
          'manualPacing=$manualSessionPacing delayMs=$delayMs shopCode=$shop itemCode=$pid',
        );

        roomImportEnrichRequestLog(
          'codesDiag productId=$pid source=${codes.source} '
          'shopItemParam=${codes.shopItemSearchItemCodeParam} kwShop=${codes.keywordShopCode} '
          'urlSlug=${codes.urlPathMatchSegment}',
        );
        roomImportEnrichMethodLog('method=${_methodLogName(chosenMethod)}');

        var usedKeywordShopUrlFallback = false;
        RoomImportEnrichmentFetchEnvelope env;
        try {
          RoomImportDebugLogBuffer.incEnrichment();
          apiAttempts++;
          switch (chosenMethod) {
            case _RoomImportEnrichMethod.shopItem:
              final sic = codes.shopItemSearchItemCodeParam.trim();
              final RakutenProductSearchCondition shopItemCondition;
              if (sic.contains(':')) {
                shopItemCondition = RakutenProductSearchCondition(
                  keyword: '',
                  shopCode: null,
                  itemCode: sic,
                );
              } else {
                shopItemCondition = RakutenProductSearchCondition(
                  keyword: '',
                  shopCode: codes.matchShopCodeForPick,
                  itemCode: codes.matchPureItemForPick,
                );
              }
              final fbKw = _roomImportFallbackKeyword(chosen, pid);
              final fbOut =
                  await _searchRepository.fetchRoomImportShopItemWithKeywordUrlFallback(
                    shopItemCondition: shopItemCondition,
                    matchPureItemForPick: codes.matchPureItemForPick,
                    matchShopCodeForPick: codes.matchShopCodeForPick,
                    storedProductIdForUrlMatch: pid,
                    urlPathMatchSegment: codes.urlPathMatchSegment,
                    fallbackKeyword: fbKw,
                    verifyMode: RoomImportEnrichmentVerifyConfig.enabled,
                    phaseShopItem: 'shopItem',
                  );
              env = fbOut.envelope;
              apiAttempts += fbOut.additionalApiCalls;
              usedKeywordShopUrlFallback =
                  fbOut.keywordFallbackAttempted && env.item != null;
              break;
            case _RoomImportEnrichMethod.shopTitleKeyword:
              final kw = _keywordForShopTitleSearch(chosen, pid);
              env = await _searchRepository.fetchRoomImportEnrichmentSingleSearch(
                condition: RakutenProductSearchCondition(
                  keyword: kw,
                  shopCode: codes.keywordShopCode,
                  itemCode: null,
                ),
                phase: 'shopTitleKeyword',
                page: 1,
                hits: 30,
                matchPureItemForPick: '',
                matchShopCodeForPick: codes.keywordShopCode,
                preferShopFirstForKeyword: true,
              );
              break;
            case _RoomImportEnrichMethod.productIdKeyword:
              env = await _searchRepository.fetchRoomImportEnrichmentSingleSearch(
                condition: RakutenProductSearchCondition(
                  keyword: chosen.productId.trim(),
                  shopCode: codes.keywordShopCode,
                  itemCode: null,
                ),
                phase: 'productIdKeyword',
                page: 1,
                hits: 30,
                matchPureItemForPick: '',
                matchShopCodeForPick: codes.keywordShopCode,
                preferShopFirstForKeyword: true,
              );
              break;
          }
        } catch (e, st) {
          debugPrint('[ROOM_IMPORT_ENRICH] envelope exception $e\n$st');
          await _applyEnrichException(chosen, attemptNow, chosenMethod);
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=exception',
          );
          failCount++;
          continue;
        }

        if (env.rateLimited || env.httpStatus == 429) {
          roomImportApiLog('status=rateLimited http=429');
          await RoomImportEnrichmentCooldownStore.armAfterRateLimit429();
          roomImportEnrichCooldownLog(
            'reason=rateLimit '
            'minutes=${RoomImportLimitPolicy.enrichCooldownAfter429Minutes}',
          );
          final remaining = _pendingQueueRows().length;
          roomImportEnrichPausedLog(
            'reason=rateLimit '
            'cooldownMinutes=${RoomImportLimitPolicy.enrichCooldownAfter429Minutes} '
            'remainingPending=$remaining',
          );
          await _apply429Row(chosen, attemptNow, chosenMethod);
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=429',
          );
          failCount++;
          pausedByRateLimit = true;
          stopReasonTag = 'rateLimited';
          break;
        }

        if (env.httpStatus == 400) {
          roomImportApiLog('rateLimitDetected=false');
          if (chosenMethod == _RoomImportEnrichMethod.shopItem) {
            await _applyShopItemHttp400(chosen, attemptNow);
          } else {
            await _applyNonShopItemHttp400(chosen, attemptNow, chosenMethod);
          }
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=400',
          );
          failCount++;
          continue;
        }

        if (env.item == null) {
          var envWork = env;
          final rowForDetail = _productRepository.getByProductId(pid) ?? chosen;
          final canDetail = allowRoomDetailRedirectRecovery &&
              (chosenMethod == _RoomImportEnrichMethod.shopTitleKeyword ||
                  chosenMethod == _RoomImportEnrichMethod.productIdKeyword) &&
              rowForDetail.roomApiCompositeItemCode.trim().isEmpty &&
              !rowForDetail.roomEnrichDetailRedirectAttempted &&
              rowForDetail.roomUrl.trim().isNotEmpty;
          if (canDetail) {
            roomImportEnrichSourceDecisionLog({
              'productId': pid,
              'shopCode': shopCodeLog.isEmpty ? '(empty)' : shopCodeLog,
              'urlProductCode': urlProductCodeLog.isEmpty ? '(empty)' : urlProductCodeLog,
              'apiCompositeItemCode': '(empty)',
              'decision': 'fetchRoomDetailForRedirect',
              'reason': 'keywordFailed',
            });
            final recovered = await _tryRecoverViaRoomDetailThenShopItem(
              row: rowForDetail,
              pid: pid,
              urlPathMatchSegment: codes.urlPathMatchSegment.trim(),
            );
            if (recovered?.item != null) {
              envWork = recovered!;
              apiAttempts++;
            }
          }
          if (envWork.item == null) {
            await _applyNoItems(chosen, attemptNow, chosenMethod);
            roomImportEnrichFailLog(
              'productId=$pid method=${_methodLogName(chosenMethod)} reason=noItems',
            );
            failCount++;
            continue;
          }
          env = envWork;
        }

        final slugCheck = codes.urlPathMatchSegment.trim();
        if (slugCheck.isNotEmpty &&
            (chosenMethod == _RoomImportEnrichMethod.shopTitleKeyword ||
                chosenMethod == _RoomImportEnrichMethod.productIdKeyword)) {
          if (!roomImportSearchItemUrlsMatchStoredProduct(
            item: env.item!,
            rawItemMap: null,
            storedProductId: pid,
            urlPathMatchSegment: slugCheck,
          )) {
            var envWork = env;
            final rowForDetail = _productRepository.getByProductId(pid) ?? chosen;
            final canDetail = allowRoomDetailRedirectRecovery &&
                (chosenMethod == _RoomImportEnrichMethod.shopTitleKeyword ||
                    chosenMethod == _RoomImportEnrichMethod.productIdKeyword) &&
                rowForDetail.roomApiCompositeItemCode.trim().isEmpty &&
                !rowForDetail.roomEnrichDetailRedirectAttempted &&
                rowForDetail.roomUrl.trim().isNotEmpty;
            if (canDetail) {
              roomImportEnrichSourceDecisionLog({
                'productId': pid,
                'shopCode': shopCodeLog.isEmpty ? '(empty)' : shopCodeLog,
                'urlProductCode':
                    urlProductCodeLog.isEmpty ? '(empty)' : urlProductCodeLog,
                'apiCompositeItemCode': '(empty)',
                'decision': 'fetchRoomDetailForRedirect',
                'reason': 'keywordFailed',
              });
              final recovered = await _tryRecoverViaRoomDetailThenShopItem(
                row: rowForDetail,
                pid: pid,
                urlPathMatchSegment: codes.urlPathMatchSegment.trim(),
              );
              if (recovered?.item != null) {
                envWork = recovered!;
                apiAttempts++;
              }
            }
            final okMatch = envWork.item != null &&
                roomImportSearchItemUrlsMatchStoredProduct(
                  item: envWork.item!,
                  rawItemMap: null,
                  storedProductId: pid,
                  urlPathMatchSegment: slugCheck,
                );
            if (!okMatch) {
              await _applyNoItems(chosen, attemptNow, chosenMethod);
              roomImportEnrichFailLog(
                'productId=$pid method=${_methodLogName(chosenMethod)} reason=noUrlSlugMatch',
              );
              failCount++;
              continue;
            }
            env = envWork;
          }
        }

        try {
          final learned = RoomImportLearnedApiCode.tryParseFromSearchItem(
            env.item!,
          );
          final persistComposite = learned != null ? learned.$1 : '';
          final learnedSource = learned != null ? learned.$2 : '';
          if (persistComposite.isNotEmpty &&
              chosen.roomApiCompositeItemCode.trim().isEmpty) {
            roomImportEnrichApiCodeLearnedLog(
              'productId=$pid roomProductSlug=$slugDisp '
              'apiCompositeItemCode=$persistComposite source=$learnedSource',
            );
          }
          await _productRepository.mergeRoomImportMetadataFromSearchItem(
            productId: pid,
            api: env.item!,
            persistRoomApiCompositeItemCode: persistComposite,
          );
          okCount++;
          successIds.add(pid);
          if (usedKeywordShopUrlFallback) {
            final savedRow = _productRepository.getByProductId(pid);
            if (savedRow != null) {
              _roomImportEnrichFallbackMergeSuccessLog(
                productId: pid,
                api: env.item!,
                saved: savedRow,
              );
            }
          }
        } catch (_) {
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          failCount++;
          continue;
        }

        final api = env.item!;
        final img = api.imageUrl.trim();
        final imgLog = img.isEmpty
            ? '-'
            : (img.length > 80 ? '${img.substring(0, 80)}…' : img);
        roomImportEnrichSuccessLog(
          'productId=$pid price=${api.itemPrice} image=$imgLog '
          'shopName=${api.shopName.trim()} genreName=${api.genreName.trim()}',
        );

        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
      }
    } finally {
      final remainingPending = _pendingQueueRows().length;
      roomImportEnrichSummaryLog(
        'apiAttempts=$apiAttempts updated=$okCount failedProducts=$failCount '
        'skipped=$skippedComplete pausedByRateLimit=$pausedByRateLimit '
        'remainingPending=$remainingPending successIds=${successIds.join(',')}',
      );

      if (kDebugMode && apiAttempts > 0) {
        roomImportPerfLog(
          'enrichmentBatchSummary apiAttempts=$apiAttempts updated=$okCount '
          'failedProducts=$failCount',
        );
      }
      if (kDebugMode && successIds.isNotEmpty) {
        debugPrint('[ROOM_IMPORT_ENRICH_SUCCESS_IDS] ${successIds.join(',')}');
      }
    }

    return RoomImportEnrichmentBatchResult(
      updated: okCount,
      failedInBatch: failCount,
      attempted: apiAttempts,
      skippedAlreadyComplete: skippedComplete,
      pausedByRateLimit: pausedByRateLimit,
      remainingPending: _pendingQueueRows().length,
      successProductIds: List<String>.unmodifiable(successIds),
      productEnrichmentSlots: processedProducts,
      skippedRestrictedAlreadyComplete: skippedRestrictedAlreadyComplete,
      initialEnrichStopReason: stopReasonTag,
    );
  }

  bool _verifyEligibleForFixedProduct(RakutenManagedProduct e, String fixedId) {
    if (e.coredActivitySource != RakutenCoredActivitySource.roomImport) {
      return false;
    }
    if (!RakutenManagedProduct.isMemberForStatusTab(
      e,
      RakutenManagedProductStatus.done,
    )) {
      return false;
    }
    final pid = e.productId.trim();
    final fid = fixedId.trim();
    if (pid == fid) return true;
    if (pid.endsWith(':$fid') && pid.contains(':')) return true;
    return false;
  }

  /// 検証モード: `4901085161999` 単体と `soukaidrink:4901085161999` 形式の両方。
  ({String shop, String pure})? _verifyResolveShopAndPure(
    RakutenManagedProduct row,
    String fixedId,
  ) {
    final fid = fixedId.trim();
    final pid = row.productId.trim();
    var shop = row.shopCode.trim();

    if (pid == fid) {
      if (shop.isEmpty) return null;
      return (shop: shop, pure: fid);
    }
    if (pid.endsWith(':$fid') && pid.contains(':')) {
      final i = pid.lastIndexOf(':');
      final left = pid.substring(0, i).trim();
      final right = pid.substring(i + 1).trim();
      if (right != fid) return null;
      if (shop.isEmpty) shop = left;
      if (shop.isEmpty) return null;
      return (shop: shop, pure: right);
    }
    return null;
  }

  /// `ROOM_IMPORT_ENRICH_VERIFY`: 固定1件のみ A→B→C 検証（通常キューには入らない）。
  Future<RoomImportEnrichmentBatchResult> _runVerifyOnlyEnrichment({
    required int skippedComplete,
  }) async {
    const verifyFailSnack = '検証失敗: 詳細はログを確認してください';

    final fixedId = RoomImportEnrichmentVerifyConfig.fixedProductId.trim();
    roomImportVerifyLog('mode=on fixedProductId=$fixedId');

    final rows = _productRepository.loadAll();
    RakutenManagedProduct? target;
    for (final e in rows) {
      if (_verifyEligibleForFixedProduct(e, fixedId)) {
        target = e;
        break;
      }
    }

    if (target == null) {
      roomImportVerifyLog('noRow matched productId=$fixedId');
      _emitVerifyResultFailed(
        productId: fixedId,
        seq: null,
        message: 'ROOM取り込み商品の補完検証に失敗しました',
        extraError: 'no_eligible_row',
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: skippedComplete,
        pausedByRateLimit: false,
        remainingPending: _pendingQueueRows().length,
        verifyUiMessage: verifyFailSnack,
        successProductIds: const [],
      );
    }

    final resolved = _verifyResolveShopAndPure(target, fixedId);
    if (resolved == null) {
      roomImportVerifyLog(
        'resolveShopPure failed productId=${target.productId} shopCode=${target.shopCode}',
      );
      _emitVerifyResultFailed(
        productId: target.productId.trim(),
        seq: null,
        message: 'ROOM取り込み商品の補完検証に失敗しました',
        extraError: 'resolve_shop_pure_failed',
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: skippedComplete,
        pausedByRateLimit: false,
        remainingPending: _pendingQueueRows().length,
        verifyUiMessage: verifyFailSnack,
        successProductIds: const [],
      );
    }

    final pid = target.productId.trim();
    roomImportVerifyLog(
      'target productId=$pid shop=${resolved.shop} pureItem=${resolved.pure} '
      'patternCKeyword=${RoomImportEnrichmentVerifyConfig.patternCKeyword}',
    );

    try {
      await _productRepository.updateManagedProduct(pid, (e) {
        return e.copyWith(roomImportMetadataEnriching: true);
      });
    } catch (_) {
      _emitVerifyResultFailed(
        productId: pid,
        seq: null,
        message: 'ROOM取り込み商品の補完検証に失敗しました',
        extraError: 'mark_enriching_failed',
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: skippedComplete,
        pausedByRateLimit: false,
        remainingPending: _pendingQueueRows().length,
        verifyUiMessage: verifyFailSnack,
        successProductIds: const [],
      );
    }

    RoomImportVerifySequenceOutcome outcome;
    try {
      outcome = await _searchRepository.runRoomImportVerifySequence(
        shopCode: resolved.shop,
        pureItemCode: resolved.pure,
        patternCKeyword: RoomImportEnrichmentVerifyConfig.patternCKeyword,
      );
    } catch (e, st) {
      debugPrint('[ROOM_IMPORT_ENRICH_VERIFY] exception $e\n$st');
      await _productRepository.updateManagedProduct(pid, (e) {
        return e.copyWith(roomImportMetadataEnriching: false);
      });
      _emitVerifyResultFailed(
        productId: pid,
        seq: null,
        message: 'ROOM取り込み商品の補完検証に失敗しました',
        extraError: e.toString(),
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 0,
        attempted: 0,
        skippedAlreadyComplete: skippedComplete,
        pausedByRateLimit: false,
        remainingPending: _pendingQueueRows().length,
        verifyUiMessage: verifyFailSnack,
        successProductIds: const [],
      );
    }

    if (outcome.pausedByRateLimit) {
      roomImportApiLog('status=rateLimited http=429');
      await RoomImportEnrichmentCooldownStore.armAfterRateLimit429();
      await _productRepository.updateManagedProduct(pid, (e) {
        return e.copyWith(roomImportMetadataEnriching: false);
      });
      roomImportEnrichPausedLog('reason=rateLimit verifyMode=true');
      _emitVerifyResultFailed(
        productId: pid,
        seq: outcome,
        message: 'ROOM取り込み商品の補完検証に失敗しました',
        extraError: 'rate_limited',
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 1,
        attempted: outcome.apiCallCount,
        skippedAlreadyComplete: skippedComplete,
        pausedByRateLimit: true,
        remainingPending: _pendingQueueRows().length,
        verifyUiMessage: verifyFailSnack,
        successProductIds: const [],
      );
    }

    final env = outcome.envelope;
    final item = env?.item;
    if (item != null) {
      final genreDiag = _verifyGenreDiagnostics(item);
      if (kDebugMode) {
        debugPrint(
          '[ROOM_IMPORT_ENRICH_VERIFY] genreDiag apiRaw="${genreDiag.apiGenreName}" '
          'genreId="${genreDiag.genreId}" mappedGenre="${genreDiag.mappedGenreName}" '
          '(mapped は RakutenProductGenreDisplay / マージ処理と同系)',
        );
      }
      try {
        await _productRepository.mergeRoomImportMetadataFromSearchItem(
          productId: pid,
          api: item,
        );
      } catch (_) {
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
        _emitVerifyResultFailed(
          productId: pid,
          seq: outcome,
          message: 'ROOM取り込み商品の補完検証に失敗しました',
          extraError: 'merge_failed',
        );
        return RoomImportEnrichmentBatchResult(
          updated: 0,
          failedInBatch: 1,
          attempted: outcome.apiCallCount,
          skippedAlreadyComplete: skippedComplete,
          pausedByRateLimit: false,
          remainingPending: _pendingQueueRows().length,
          verifyUiMessage: verifyFailSnack,
          successProductIds: const [],
        );
      }

      final saved = _productRepository.getByProductId(pid);
      final img = item.imageUrl.trim();
      final imgLog = img.isEmpty
          ? '-'
          : (img.length > 80 ? '${img.substring(0, 80)}…' : img);
      roomImportEnrichSuccessLog(
        'VERIFY pattern=${outcome.winningPattern} productId=$pid '
        'price=${item.itemPrice} image=$imgLog '
        'shopName(api)=${item.shopName.trim()} '
        'apiGenreName="${genreDiag.apiGenreName}" '
        'mappedGenreName="${genreDiag.mappedGenreName}" '
        'genreId=${genreDiag.genreId.isEmpty ? '(empty)' : genreDiag.genreId}',
      );

      await _productRepository.updateManagedProduct(pid, (e) {
        return e.copyWith(roomImportMetadataEnriching: false);
      });

      if (saved != null) {
        roomImportVerifyLog(
          'saved pattern=${outcome.winningPattern} itemPrice=${item.itemPrice} '
          'savedGenreName=${saved.genreName.trim()} savedShopName=${saved.shopName.trim()} '
          '(api.genreName は空でも genreId 経由でマージ後 genreName が埋まることがあります)',
        );
        _emitVerifyResultSuccess(
          productId: pid,
          winningPattern: outcome.winningPattern ?? 'unknown',
          apiItem: item,
          saved: saved,
          apiCalls: outcome.apiCallCount,
        );
        final wp = outcome.winningPattern ?? '?';
        final snack =
            '検証成功: pattern $wp / ${saved.shopName.trim()} / ${saved.genreName.trim()}';
        return RoomImportEnrichmentBatchResult(
          updated: 1,
          failedInBatch: 0,
          attempted: outcome.apiCallCount,
          skippedAlreadyComplete: skippedComplete,
          pausedByRateLimit: false,
          remainingPending: _pendingQueueRows().length,
          verifyUiMessage: snack,
          successProductIds: <String>[pid],
        );
      }

      _emitVerifyResultFailed(
        productId: pid,
        seq: outcome,
        message: 'ROOM取り込み商品の補完検証に失敗しました',
        extraError: 'saved_row_missing_after_merge',
      );
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        failedInBatch: 1,
        attempted: outcome.apiCallCount,
        skippedAlreadyComplete: skippedComplete,
        pausedByRateLimit: false,
        remainingPending: _pendingQueueRows().length,
        verifyUiMessage: verifyFailSnack,
        successProductIds: const [],
      );
    }

    await _productRepository.updateManagedProduct(pid, (e) {
      return e.copyWith(roomImportMetadataEnriching: false);
    });
    roomImportVerifyLog('noSelectableItem apiCalls=${outcome.apiCallCount}');
    _emitVerifyResultFailed(
      productId: pid,
      seq: outcome,
      message: 'ROOM取り込み商品の補完検証に失敗しました',
      extraError: outcome.lastError,
    );
    return RoomImportEnrichmentBatchResult(
      updated: 0,
      failedInBatch: 1,
      attempted: outcome.apiCallCount,
      skippedAlreadyComplete: skippedComplete,
      pausedByRateLimit: false,
      remainingPending: _pendingQueueRows().length,
      verifyUiMessage: verifyFailSnack,
      successProductIds: const [],
    );
  }

  ({String apiGenreName, String mappedGenreName, String genreId})
  _verifyGenreDiagnostics(RakutenSearchItem item) {
    final gid = item.genreId.trim();
    final apiGn = item.genreName.trim();
    final mapped = RakutenProductGenreDisplay.resolve(
      apiGenreName: item.genreName,
      persistedGenreName: null,
      prefetchedGenreName: null,
      genreId: item.genreId,
      traceItemCode: null,
    ).trim();
    return (
      apiGenreName: apiGn,
      mappedGenreName: mapped.isEmpty || mapped == RakutenProductGenreDisplay.unknownLabel
          ? ''
          : mapped,
      genreId: gid,
    );
  }

  void _emitVerifyResultSuccess({
    required String productId,
    required String winningPattern,
    required RakutenSearchItem apiItem,
    required RakutenManagedProduct saved,
    required int apiCalls,
  }) {
    final dg = _verifyGenreDiagnostics(apiItem);
    final imageSaved = apiItem.imageUrl.trim().isNotEmpty;
    roomImportEnrichVerifyResultLog(
      LinkedHashMap<String, String>.from({
        'status': 'success',
        'winningPattern': winningPattern,
        'productId': productId,
        'itemPrice': '${apiItem.itemPrice}',
        'imageSaved': '$imageSaved',
        'shopName(api)': apiItem.shopName.trim(),
        'shopName(saved)': saved.shopName.trim(),
        'genreName': saved.genreName.trim(),
        'apiGenreName': dg.apiGenreName.isEmpty ? '(empty)' : dg.apiGenreName,
        'mappedGenreName':
            dg.mappedGenreName.isEmpty ? '(empty)' : dg.mappedGenreName,
        'genreId': dg.genreId.isEmpty ? '(empty)' : dg.genreId,
        'savedShopName': saved.shopName.trim(),
        'savedGenreName': saved.genreName.trim(),
        'apiCalls': '$apiCalls',
        'message': 'ROOM取り込み商品の補完検証に成功しました',
      }),
    );
  }

  void _emitVerifyResultFailed({
    required String productId,
    required RoomImportVerifySequenceOutcome? seq,
    required String message,
    String extraError = '',
  }) {
    final tried = seq?.patternsTried ?? const [];
    final blocked = seq?.blockedPatterns ?? const [];
    final baseErr = seq?.lastError ?? '';
    final last = [
      if (baseErr.isNotEmpty) baseErr,
      if (extraError.isNotEmpty) extraError,
    ].join('; ');
    roomImportEnrichVerifyResultLog(
      LinkedHashMap<String, String>.from({
        'status': 'failed',
        'winningPattern': seq?.winningPattern ?? 'none',
        'productId': productId,
        'triedPatterns': tried.isEmpty ? 'none' : tried.join(','),
        'blockedPatterns': blocked.isEmpty ? 'none' : blocked.join(','),
        'lastError': last.isEmpty ? 'unknown' : last,
        'message': message,
      }),
    );
  }
}
