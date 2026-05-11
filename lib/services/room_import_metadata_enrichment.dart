import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../utils/room_sync_log.dart';
import 'room_import_limit_policy.dart';

/// Phase 3 向けに ROOM 取り込みコレのメタデータをバッチで API 補完するサービス。
///
/// 取り込み直後の補完は [RakutenSearchRepository.fetchFirstItemForRoomImportEnrichment] を
/// [RoomSyncService] / [RoomCollectedRegisterService] から呼び出す。
///
/// 将来マイページや ROOM 取り込みカードから [enrichRoomImportedProducts] を叩けるようにする。
class RoomImportMetadataEnrichmentService {
  RoomImportMetadataEnrichmentService({
    required RakutenSearchRepository searchRepository,
    required RakutenManagedProductRepository productRepository,
  }) : _searchRepository = searchRepository,
       _productRepository = productRepository;

  final RakutenSearchRepository _searchRepository;
  final RakutenManagedProductRepository _productRepository;

  /// [shopName] または [genreName] が未設定の ROOM 取り込みコレ済を最大 [limit] 件まで API で補完する。
  ///
  /// - [shopCode] と [productId]（楽天 itemCode の数字側）が両方ある行のみ対象
  /// - 失敗しても次の行へ進む
  /// - 成功時は [RakutenManagedProductRepository.mergeRoomImportMetadataFromSearchItem] でマージ
  ///
  /// [applyPostImportAutoCap] が true のときだけ [RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls]
  /// で API 試行回数を抑える（取り込み直後の軽量補完用）。マイページの手動補完では false のまま。
  Future<int> enrichRoomImportedProducts({
    required int limit,
    bool applyPostImportAutoCap = false,
  }) async {
    final maxApiCalls = limit <= 0
        ? 0
        : (applyPostImportAutoCap
              ? (limit > RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls
                    ? RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls
                    : limit)
              : limit);
    if (maxApiCalls <= 0) {
      if (applyPostImportAutoCap) {
        roomImportPerfLog('enrichmentSkipped reason=autoDisabled');
      }
      return 0;
    }

    final rows = _productRepository.loadAll();
    final pendingAll = rows.where(_needsRoomImportMetadataEnrichment).toList();

    final failedApiKeys = <String>{};
    var consecutiveHttp400 = 0;
    var consecutiveNoItem = 0;
    var apiAttempts = 0;
    var okCount = 0;
    String? pendingLastShopForApiWalk;
    var didApiForCurrentShopBlock = false;

    for (final row in pendingAll) {
      if (apiAttempts >= maxApiCalls) break;

      final shop = row.shopCode.trim();
      final pid = row.productId.trim();
      if (shop.isEmpty || pid.isEmpty) continue;

      if (shop != pendingLastShopForApiWalk) {
        pendingLastShopForApiWalk = shop;
        didApiForCurrentShopBlock = false;
      }

      if (_rowHasShopGenreImage(row)) {
        continue;
      }

      final icRaw = pid;
      final apiItemCode = icRaw.contains(':') ? icRaw : '$shop:$icRaw';
      if (failedApiKeys.contains(apiItemCode)) {
        continue;
      }

      if (didApiForCurrentShopBlock) {
        continue;
      }

      debugPrint('[ROOM_IMPORT_ENRICH] start productId=$pid');
      try {
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: true);
        });
      } catch (_) {
        continue;
      }

      RoomImportEnrichmentFetchEnvelope env;
      try {
        RoomImportDebugLogBuffer.incEnrichment();
        apiAttempts++;
        didApiForCurrentShopBlock = true;
        env = await _searchRepository.fetchFirstItemForRoomImportEnrichmentEnvelope(
          shopCode: shop,
          itemCode: pid,
        );
      } catch (e, st) {
        debugPrint('[ROOM_IMPORT_ENRICH] envelope exception $e\n$st');
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
        roomImportPerfLog('enrichmentStopped reason=tooManyFailures');
        roomImportEnrichStopLog('exception');
        break;
      }

      if (env.rateLimited || env.httpStatus == 429) {
        roomImportApiLog('rateLimitDetected=true');
        roomImportPerfLog('enrichmentStopped reason=rateLimit');
        roomImportEnrichStopLog('rateLimit');
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
        break;
      }

      if (env.httpStatus == 400) {
        failedApiKeys.add(apiItemCode);
        consecutiveHttp400++;
        consecutiveNoItem = 0;
        if (consecutiveHttp400 >= 2) {
          roomImportPerfLog('enrichmentStopped reason=tooManyFailures');
          roomImportEnrichStopLog('proxyFailed');
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          break;
        }
        roomImportApiLog('rateLimitDetected=false');
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
        continue;
      }

      consecutiveHttp400 = 0;

      if (env.item == null) {
        consecutiveNoItem++;
        if (consecutiveNoItem >= 3) {
          roomImportPerfLog('enrichmentStopped reason=tooManyFailures');
          roomImportEnrichStopLog('emptyResponses');
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          break;
        }
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
        continue;
      }

      consecutiveNoItem = 0;

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

      await _productRepository.updateManagedProduct(pid, (e) {
        return e.copyWith(roomImportMetadataEnriching: false);
      });
    }

    if (kDebugMode && apiAttempts > 0) {
      roomImportPerfLog(
        'enrichmentBatchSummary apiAttempts=$apiAttempts updated=$okCount',
      );
    }
    return okCount;
  }

  static bool _rowHasShopGenreImage(RakutenManagedProduct e) {
    return !_isShopNameNeedsEnrichment(e.shopName) &&
        !_isGenreNameNeedsEnrichment(e.genreName) &&
        e.imageUrl.trim().isNotEmpty;
  }

  static bool _needsRoomImportMetadataEnrichment(RakutenManagedProduct e) {
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
    if (_rowHasShopGenreImage(e)) {
      return false;
    }
    final shopNeeds = _isShopNameNeedsEnrichment(e.shopName);
    final genreNeeds = _isGenreNameNeedsEnrichment(e.genreName);
    final aff = e.affiliateUrl?.trim() ?? '';
    final affiliateNeeds = aff.isEmpty;
    return shopNeeds || genreNeeds || affiliateNeeds;
  }

  /// [shopName] が未設定・プレースホルダのとき API で上書き対象にする。
  static bool _isShopNameNeedsEnrichment(String? raw) {
    final t = (raw ?? '').trim();
    return t.isEmpty || t == 'ショップ未設定' || t == 'ショップ名不明';
  }

  /// [genreName] が未設定・プレースホルダのとき API で名前解決の対象にする。
  static bool _isGenreNameNeedsEnrichment(String? raw) {
    final t = (raw ?? '').trim();
    return t.isEmpty || t == 'ジャンル未設定';
  }
}
