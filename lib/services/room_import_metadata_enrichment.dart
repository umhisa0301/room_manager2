import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
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

/// Phase 3 向けに ROOM 取り込みコレのメタデータをバッチで API 補完するサービス。
///
/// 取り込み直後の補完は [RakutenSearchRepository.fetchFirstItemForRoomImportEnrichment] を
/// [RoomSyncService] / [RoomCollectedRegisterService] から呼び出す。
///
/// 自動補完は **低速キュー**（件数上限・呼び出し間隔・429 後クールダウン）で 429 を避ける。
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
    var okCount = 0;
    var apiAttempts = 0;
    var pausedByRateLimit = false;
    final failedApiKeys = <String>{};

    try {
      for (var i = 0; i < pendingAll.length && apiAttempts < maxApiCalls; i++) {
        final row = pendingAll[i];
        final shop = row.shopCode.trim();
        final pid = row.productId.trim();
        if (shop.isEmpty || pid.isEmpty) continue;

        final flags = needFlagsForProduct(row);
        roomImportEnrichTargetLog(
          'productId=$pid needsPrice=${flags.needsPrice} needsImage=${flags.needsImage} '
          'needsShopName=${flags.needsShopName} needsGenre=${flags.needsGenre} '
          'willEnrich=${flags.willEnrich}',
        );

        final failKey = '$shop\x1f$pid';
        if (failedApiKeys.contains(failKey)) {
          continue;
        }

        if (apiAttempts > 0) {
          await Future<void>.delayed(
            const Duration(
              milliseconds: RoomImportLimitPolicy.enrichMinDelayMsBetweenCalls,
            ),
          );
        }

        try {
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: true);
          });
        } catch (_) {
          continue;
        }

        final delayMs = apiAttempts == 0
            ? 0
            : RoomImportLimitPolicy.enrichMinDelayMsBetweenCalls;
        roomImportEnrichApiLog(
          'productId=$pid index=${apiAttempts + 1} maxPerRun=$maxApiCalls '
          'delayMs=$delayMs shopCode=$shop itemCode=$pid',
        );

        RoomImportEnrichmentFetchEnvelope env;
        try {
          RoomImportDebugLogBuffer.incEnrichment();
          apiAttempts++;
          env = await _searchRepository
              .fetchFirstItemForRoomImportEnrichmentEnvelope(
                shopCode: shop,
                itemCode: pid,
              );
        } catch (e, st) {
          debugPrint('[ROOM_IMPORT_ENRICH] envelope exception $e\n$st');
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          roomImportPerfLog('enrichmentStopped reason=exception');
          roomImportEnrichStopLog('exception');
          break;
        }

        if (env.rateLimited || env.httpStatus == 429) {
          roomImportApiLog('status=rateLimited http=429');
          await RoomImportEnrichmentCooldownStore.armAfterRateLimit429();
          final remaining = _pendingQueueRows().length;
          roomImportEnrichPausedLog(
            'reason=rateLimit '
            'cooldownMinutes=${RoomImportLimitPolicy.enrichCooldownAfter429Minutes} '
            'remainingPending=$remaining',
          );
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          pausedByRateLimit = true;
          break;
        }

        if (env.httpStatus == 400) {
          failedApiKeys.add(failKey);
          roomImportApiLog('rateLimitDetected=false');
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          continue;
        }

        if (env.item == null) {
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          continue;
        }

        final before = _productRepository.getByProductId(pid);
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
          continue;
        }

        final after = _productRepository.getByProductId(pid);
        if (before != null && after != null) {
          final api = env.item!;
          final apiShopOk =
              api.shopName.trim().isNotEmpty &&
              api.shopName.trim() != 'ショップ名不明';
          final priceSaved =
              api.itemPrice > 0 &&
              after.itemPrice == api.itemPrice &&
              (before.itemPrice != after.itemPrice || before.itemPrice <= 0);
          final imageSaved =
              api.imageUrl.trim().isNotEmpty &&
              after.imageUrl.trim() == api.imageUrl.trim() &&
              (before.imageUrl.trim().isEmpty ||
                  before.imageUrl.trim() != after.imageUrl.trim());
          final shopNameSaved =
              apiShopOk &&
              after.shopName.trim() == api.shopName.trim() &&
              before.shopName.trim() != after.shopName.trim();
          final genreNameSaved =
              after.genreName.trim() != before.genreName.trim() &&
              (api.genreId.trim().isNotEmpty ||
                  api.genreName.trim().isNotEmpty);
          roomImportEnrichSuccessLog(
            'productId=$pid priceSaved=$priceSaved imageSaved=$imageSaved '
            'shopNameSaved=$shopNameSaved genreNameSaved=$genreNameSaved',
          );
        }

        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
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
