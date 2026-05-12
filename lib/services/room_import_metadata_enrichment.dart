import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/rakuten_item_url_parser.dart';
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
    required this.attempted,
    required this.skippedAlreadyComplete,
    required this.pausedByRateLimit,
    required this.remainingPending,
    this.skippedCooldown = false,
    this.duplicateSessionSkipped = false,
  });

  final int updated;
  final int attempted;
  final int skippedAlreadyComplete;
  final bool pausedByRateLimit;
  final int remainingPending;
  final bool skippedCooldown;
  final bool duplicateSessionSkipped;
}

/// 取り込み後メタ補完で試す検索経路（ログ名と一致）。
enum _RoomImportEnrichMethod { shopItem, shopTitleKeyword, productIdKeyword }

class _ResolvedImportCodes {
  const _ResolvedImportCodes({
    required this.apiShop,
    required this.apiItem,
    required this.storedProductId,
    required this.source,
  });

  final String apiShop;
  final String apiItem;
  final String storedProductId;
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
    if (e.shopCode.trim().isEmpty || e.productId.trim().isEmpty) {
      return false;
    }
    return true;
  }

  /// ROOM 取り込みコレ済のメタを最大 [limit] 件まで API で補完する。
  ///
  /// [applyPostImportAutoCap] が true のとき [RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls] を上限にする。
  /// 手動でも [RoomImportLimitPolicy.manualEnrichMaxApiCallsPerRun] を超えないよう内部でキャップする。
  Future<RoomImportEnrichmentBatchResult> enrichRoomImportedProducts({
    required int limit,
    bool applyPostImportAutoCap = false,
  }) async {
    var maxApiCalls = limit <= 0
        ? 0
        : (applyPostImportAutoCap
              ? (limit > RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls
                    ? RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls
                    : limit)
              : (limit > RoomImportLimitPolicy.manualEnrichMaxApiCallsPerRun
                    ? RoomImportLimitPolicy.manualEnrichMaxApiCallsPerRun
                    : limit));
    if (maxApiCalls <= 0) {
      if (applyPostImportAutoCap) {
        roomImportPerfLog('enrichmentSkipped reason=autoDisabled');
      }
      final pending0 = _pendingQueueRows().length;
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        attempted: 0,
        skippedAlreadyComplete: 0,
        pausedByRateLimit: false,
        remainingPending: pending0,
      );
    }

    if (_singleFlight) {
      roomImportPerfLog('enrichmentSkipped reason=singleFlightBusy');
      roomImportEnrichSkipLog('reason=singleFlightBusy');
      final pending = _pendingQueueRows().length;
      return RoomImportEnrichmentBatchResult(
        updated: 0,
        attempted: 0,
        skippedAlreadyComplete: 0,
        pausedByRateLimit: false,
        remainingPending: pending,
        duplicateSessionSkipped: true,
      );
    }

    if (await RoomImportEnrichmentCooldownStore.isInCooldown()) {
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
        attempted: 0,
        skippedAlreadyComplete: 0,
        pausedByRateLimit: false,
        remainingPending: pending,
        skippedCooldown: true,
      );
    }

    _singleFlight = true;
    try {
      return await _runEnrichmentLoop(maxApiCalls: maxApiCalls);
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

  _ResolvedImportCodes _resolveImportCodes(RakutenManagedProduct row) {
    for (final u in [row.itemUrl, row.rakutenUrl ?? '', row.affiliateUrl ?? '']) {
      final t = u.trim();
      if (t.isEmpty) continue;
      final p = RakutenItemUrlParser.tryParse(t);
      if (p != null &&
          p.shopCode.trim().isNotEmpty &&
          p.itemPathSegment.trim().isNotEmpty) {
        return _ResolvedImportCodes(
          apiShop: p.shopCode.trim(),
          apiItem: p.itemPathSegment.trim(),
          storedProductId: row.productId.trim(),
          source: 'itemUrl',
        );
      }
    }
    return _ResolvedImportCodes(
      apiShop: row.shopCode.trim(),
      apiItem: row.productId.trim(),
      storedProductId: row.productId.trim(),
      source: 'storedFields',
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

  _RoomImportEnrichMethod? _peekNextMethod(RakutenManagedProduct row, DateTime now) {
    final codes = _resolveImportCodes(row);
    if (_shopItemAllowed(row, now) &&
        codes.apiShop.isNotEmpty &&
        codes.apiItem.isNotEmpty) {
      return _RoomImportEnrichMethod.shopItem;
    }
    final title = _titleKeywordRaw(row.itemName);
    if (_titleKeywordAllowed(row, now) &&
        title != null &&
        codes.apiShop.isNotEmpty) {
      return _RoomImportEnrichMethod.shopTitleKeyword;
    }
    if (!_productIdKeywordAllowed(row, now)) return null;
    if (row.shopCode.trim().isEmpty || row.productId.trim().length < 5) {
      return null;
    }
    final cannotUseShopItemNow =
        codes.apiItem.isEmpty || !_shopItemAllowed(row, now);
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

  Future<RoomImportEnrichmentBatchResult> _runEnrichmentLoop({
    required int maxApiCalls,
  }) async {
    final rows = _productRepository.loadAll();
    var skippedComplete = 0;
    for (final row in rows) {
      if (!_baseEligibleForEnrichmentQueue(row)) continue;
      final flags = needFlagsForProduct(row);
      if (!flags.willEnrich) {
        skippedComplete++;
      }
    }

    final pendingAll = _pendingQueueRows();
    final now = DateTime.now();
    var inBackoff = 0;
    var noMethod = 0;
    var eligible = 0;
    for (final e in pendingAll) {
      if (_inProductBackoff(e, now)) {
        inBackoff++;
        continue;
      }
      if (_peekNextMethod(e, now) == null) {
        noMethod++;
        continue;
      }
      eligible++;
    }
    roomImportEnrichQueueLog(
      'pending=${pendingAll.length} eligible=$eligible '
      'skippedCooldown=$inBackoff skippedFailed=$noMethod',
    );

    var okCount = 0;
    var apiAttempts = 0;
    var pausedByRateLimit = false;

    try {
      while (apiAttempts < maxApiCalls) {
        final sorted = _sortedEnrichmentCandidates(pendingAll, now);
        _RoomImportEnrichMethod? chosenMethod;
        RakutenManagedProduct? chosen;
        var pickLogged = 0;
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
        if (chosen == null || chosenMethod == null) {
          roomImportEnrichMethodLog('method=skip');
          break;
        }

        if (apiAttempts > 0) {
          await Future<void>.delayed(
            const Duration(
              milliseconds: RoomImportLimitPolicy.enrichMinDelayMsBetweenCalls,
            ),
          );
        }

        final pid = chosen.productId.trim();
        final shop = chosen.shopCode.trim();
        if (shop.isEmpty || pid.isEmpty) break;

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

        final delayMs = apiAttempts == 0
            ? 0
            : RoomImportLimitPolicy.enrichMinDelayMsBetweenCalls;
        roomImportEnrichApiLog(
          'productId=$pid index=${apiAttempts + 1} maxPerRun=$maxApiCalls '
          'delayMs=$delayMs shopCode=$shop itemCode=$pid',
        );

        final codes = _resolveImportCodes(chosen);
        roomImportEnrichRequestLog(
          'codesDiag productId=$pid source=${codes.source} '
          'apiShop=${codes.apiShop} apiItem=${codes.apiItem} '
          'storedShop=${chosen.shopCode.trim()} storedProductId=${codes.storedProductId}',
        );
        roomImportEnrichMethodLog('method=${_methodLogName(chosenMethod)}');

        RoomImportEnrichmentFetchEnvelope env;
        try {
          RoomImportDebugLogBuffer.incEnrichment();
          apiAttempts++;
          switch (chosenMethod) {
            case _RoomImportEnrichMethod.shopItem:
              env = await _searchRepository.fetchRoomImportEnrichmentSingleSearch(
                condition: RakutenProductSearchCondition(
                  keyword: '',
                  shopCode: codes.apiShop,
                  itemCode: codes.apiItem,
                ),
                phase: 'shopItem',
                page: 1,
                hits: 30,
                matchPureItemForPick: codes.apiItem,
                matchShopCodeForPick: codes.apiShop,
              );
              break;
            case _RoomImportEnrichMethod.shopTitleKeyword:
              final kw = _titleKeywordRaw(chosen.itemName)!;
              env = await _searchRepository.fetchRoomImportEnrichmentSingleSearch(
                condition: RakutenProductSearchCondition(
                  keyword: kw,
                  shopCode: codes.apiShop,
                  itemCode: null,
                ),
                phase: 'shopTitleKeyword',
                page: 1,
                hits: 30,
                matchPureItemForPick: '',
                matchShopCodeForPick: codes.apiShop,
                preferShopFirstForKeyword: true,
              );
              break;
            case _RoomImportEnrichMethod.productIdKeyword:
              env = await _searchRepository.fetchRoomImportEnrichmentSingleSearch(
                condition: RakutenProductSearchCondition(
                  keyword: chosen.productId.trim(),
                  shopCode: chosen.shopCode.trim(),
                  itemCode: null,
                ),
                phase: 'productIdKeyword',
                page: 1,
                hits: 30,
                matchPureItemForPick: '',
                matchShopCodeForPick: chosen.shopCode.trim(),
                preferShopFirstForKeyword: true,
              );
              break;
          }
        } catch (e, st) {
          debugPrint('[ROOM_IMPORT_ENRICH] envelope exception $e\n$st');
          await _applyEnrichException(chosen, now, chosenMethod);
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=exception',
          );
          roomImportPerfLog('enrichmentStopped reason=exception');
          roomImportEnrichStopLog('exception');
          break;
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
          await _apply429Row(chosen, now, chosenMethod);
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=429',
          );
          pausedByRateLimit = true;
          break;
        }

        if (env.httpStatus == 400) {
          roomImportApiLog('rateLimitDetected=false');
          if (chosenMethod == _RoomImportEnrichMethod.shopItem) {
            await _applyShopItemHttp400(chosen, now);
          } else {
            await _applyNonShopItemHttp400(chosen, now, chosenMethod);
          }
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=400',
          );
          break;
        }

        if (env.item == null) {
          await _applyNoItems(chosen, now, chosenMethod);
          roomImportEnrichFailLog(
            'productId=$pid method=${_methodLogName(chosenMethod)} reason=noItems',
          );
          break;
        }

        try {
          await _productRepository.mergeRoomImportMetadataFromSearchItem(
            productId: pid,
            api: env.item!,
          );
          okCount++;
        } catch (_) {
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          break;
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
        break;
      }
    } finally {
      final remainingPending = _pendingQueueRows().length;
      roomImportEnrichSummaryLog(
        'attempted=$apiAttempts updated=$okCount skipped=$skippedComplete '
        'pausedByRateLimit=$pausedByRateLimit remainingPending=$remainingPending',
      );

      if (kDebugMode && apiAttempts > 0) {
        roomImportPerfLog(
          'enrichmentBatchSummary apiAttempts=$apiAttempts updated=$okCount',
        );
      }
    }

    return RoomImportEnrichmentBatchResult(
      updated: okCount,
      attempted: apiAttempts,
      skippedAlreadyComplete: skippedComplete,
      pausedByRateLimit: pausedByRateLimit,
      remainingPending: _pendingQueueRows().length,
    );
  }
}
