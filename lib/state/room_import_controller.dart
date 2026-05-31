import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_activity_event.dart';
import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_sync_result.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../services/room_reaction_sync_history_store.dart';
import '../services/room_profile_url_validation_service.dart';
import '../utils/room_sync_card_copy.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_managed_product_provider.dart';
import 'user_profile_provider.dart';
import '../widgets/room_post_import_flow.dart';
import 'bulk_operation_state_controller.dart';
import 'room_activity_event_provider.dart';

/// ROOM 取り込みのフェーズ（ホーム／マイページ共通）。
enum RoomImportPhase { idle, running, completed, failed }

/// ホーム／マイページ共通の ROOM 投稿取り込み実行状態。
///
/// TODO(RewardedAd|Subscription): RoomImportLimitPolicy.effectiveBatchLimit と連動して
/// `phase` 以外に「追加バッチ解放済み」などを持てるようにする。
class RoomImportController extends ChangeNotifier {
  RoomImportController({BulkOperationStateController? bulkOperationState})
    : _bulkOperationState = bulkOperationState;

  final BulkOperationStateController? _bulkOperationState;

  RoomImportPhase _phase = RoomImportPhase.idle;
  int _checkedCount = 0;
  int _targetCount = 0;
  int _newlyAddedCount = 0;
  int _skippedCount = 0;
  int _failedCount = 0;
  List<RakutenManagedProduct> _latestAddedItems = [];

  RoomImportPhase get phase => _phase;

  bool get isRunning => _phase == RoomImportPhase.running;

  int get checkedCount => _checkedCount;

  int get targetCount => _targetCount;

  int get newlyAddedCount => _newlyAddedCount;

  int get skippedCount => _skippedCount;

  int get failedCount => _failedCount;

  List<RakutenManagedProduct> get latestAddedItems =>
      List<RakutenManagedProduct>.unmodifiable(_latestAddedItems);

  String _importProcessingHint = '';
  RoomImportUiPhase _uiPhase = RoomImportUiPhase.checkingTargets;

  /// [RoomSyncService.onProcessingHint] から渡る短文（ホーム等の進捗表示用）。
  String get importProcessingHint => _importProcessingHint;

  RoomImportUiPhase get uiPhase => _uiPhase;

  String get uiPhaseLabel => RoomSyncCardCopy.importPhaseLabel(_uiPhase);

  double get uiPhaseProgress => RoomSyncCardCopy.importPhaseProgress(_uiPhase);

  void _setUiPhase(RoomImportUiPhase phase) {
    if (_uiPhase == phase) return;
    _uiPhase = phase;
    roomImportPhaseUiLog(
      phase: phase.name,
      label: RoomSyncCardCopy.importPhaseLabel(phase),
      progress: RoomSyncCardCopy.importPhaseProgress(phase),
    );
    notifyListeners();
  }

  void _mapHintToUiPhase(String hint) {
    final h = hint.trim();
    if (h.isEmpty) return;
    if (h.contains('ショップ名') || h.contains('ジャンル')) {
      _setUiPhase(RoomImportUiPhase.checkingProductInfo);
    } else if (h.contains('反応') || h.contains('いいね') || h.contains('コメント')) {
      _setUiPhase(RoomImportUiPhase.checkingReactions);
    } else if (h.contains('取り込み') ||
        h.contains('保存') ||
        RegExp(r'\d+\s*/\s*\d+').hasMatch(h)) {
      _setUiPhase(RoomImportUiPhase.importingPosts);
    } else if (h.contains('確認')) {
      _setUiPhase(RoomImportUiPhase.checkingTargets);
    }
  }

  /// ROOMコレ表示・マイページ表示などで呼ばれていた低速補完フック。
  ///
  /// 取り込みと楽天API補完を分離したため、**自動補完は行わない**（手動ボタンへ誘導）。
  Future<void> tickSlowRoomMetadataEnrichmentIfNeeded(
    BuildContext context,
  ) async {
    if (kDemoModeEnabled || !context.mounted) return;
  }

  void _applyResultSnapshot(RoomSyncResult r) {
    _newlyAddedCount = r.newlyCollectedCount;
    _skippedCount = r.skippedCount;
    _failedCount = r.failedCount;
    _latestAddedItems = List<RakutenManagedProduct>.from(
      r.newlyCollectedSamples,
    );
    _checkedCount = r.processedCount;
    _targetCount = r.processedCount > 0 ? r.processedCount : r.listingCheckedCount;
  }

  /// 取り込みバッチを実行。実行中に再度呼ぶと null（UI はボタン disabled で抑止）。
  Future<RoomSyncResult?> runImport(
    BuildContext context, {
    bool deepCollectsExplore = false,
  }) async {
    if (_phase == RoomImportPhase.running) return null;
    final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
      context.read<UserProfileProvider>().profile.roomUrl,
    );
    if (profile.isEmpty) return null;

    final bulk = _bulkOperationState;
    if (bulk != null) {
      if (bulk.isRoomReactionSyncRunning) {
        roomSyncJobLockLog(
          'action=blocked job=importingCollectedItems currentJob=syncingReactions',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(bulk.blockingRoomTourUserMessage ?? '')),
          );
        }
        return null;
      }
      if (bulk.isMetadataEnriching) {
        roomSyncJobLockLog(
          'action=blocked job=importingCollectedItems currentJob=enrichingMetadata',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(bulk.blockingRoomTourUserMessage ?? '')),
          );
        }
        return null;
      }
    }

    roomSyncJobLockLog(
      'action=acquire job=importingCollectedItems currentJob=none',
    );
    roomImportFlowLog('action=importStart message=postImportInitialEnrich');

    _phase = RoomImportPhase.running;
    _checkedCount = 0;
    _targetCount = 0;
    _importProcessingHint = '';
    _uiPhase = RoomImportUiPhase.checkingTargets;
    roomImportPhaseUiLog(
      phase: RoomImportUiPhase.checkingTargets.name,
      label: RoomSyncCardCopy.importPhaseLabel(
        RoomImportUiPhase.checkingTargets,
      ),
      progress: RoomSyncCardCopy.importPhaseProgress(
        RoomImportUiPhase.checkingTargets,
      ),
    );
    _bulkOperationState?.setRoomImportRunning(true);
    notifyListeners();

    RoomSyncResult? result;
    var enrichmentBatchMs = 0;
    var enrichmentUpdated = 0;
    var enrichmentProductAttempts = 0;
    try {
      try {
        result = await RoomPostImportFlow.executeBatch(
          context,
          collectsExploreMode: deepCollectsExplore
              ? RoomImportCollectsExploreMode.deep
              : RoomImportCollectsExploreMode.normal,
          onProgress:
              ({
                required bool busy,
                required int completed,
                required int total,
              }) {
                if (busy) {
                  _checkedCount = completed;
                  _targetCount = total;
                  if (total > 0) {
                    _setUiPhase(RoomImportUiPhase.importingPosts);
                  }
                  notifyListeners();
                }
              },
          onProcessingHint: (hint) {
            _importProcessingHint = hint;
            _mapHintToUiPhase(hint);
            notifyListeners();
          },
        );
      } catch (e, st) {
        debugPrint('[RoomImportController] executeBatch failed: $e\n$st');
        result = null;
      }

      if (result != null &&
          !result.hasFatalError &&
          result.newlyImportedProductIds.isNotEmpty &&
          context.mounted) {
        final idsCsv = result.newlyImportedProductIds.join(',');
        roomImportInitialEnrichStartLog(
          'importedProductIds=$idsCsv limit=${RoomImportLimitPolicy.freeBatchLimit}',
        );
        final sw = Stopwatch()..start();
        final searchRepo = context.read<RakutenSearchRepository>();
        final productRepo = context.read<RakutenManagedProductRepository>();
        final catalogRepo = context.read<ProductCatalogRepository>();
        final svc = RoomImportMetadataEnrichmentService(
          searchRepository: searchRepo,
          productRepository: productRepo,
          productCatalogRepository: catalogRepo,
        );
        _setUiPhase(RoomImportUiPhase.checkingProductInfo);
        final er = await svc.enrichRoomImportedProducts(
          limit: RoomImportLimitPolicy.freeBatchLimit,
          applyPostImportAutoCap: true,
          manualSessionPacing: true,
          restrictToProductIdsInOrder: result.newlyImportedProductIds,
          maxRunDuration: const Duration(seconds: 20),
          onEnrichSlotProgress: (done, total) {
            _importProcessingHint = '商品情報を確認しています';
            _setUiPhase(RoomImportUiPhase.checkingProductInfo);
            notifyListeners();
          },
        );
        for (final id in result.newlyImportedProductIds) {
          final row = productRepo.getByProductId(id);
          if (row == null) continue;
          final flags = RoomImportMetadataEnrichmentService.needFlagsForProduct(
            row,
          );
          if (!flags.willEnrich) continue;
          roomImportProductInfoPendingReasonLog(
            productId: row.productId,
            title: row.itemName,
            shopCode: row.shopCode,
            urlProductCode: row.roomApiCompositeItemCode,
            hasRoomTitle: row.itemName.trim().isNotEmpty,
            hasRoomImage: row.imageUrl.trim().isNotEmpty,
            hasRoomPrice: row.itemPrice > 0,
            hasRoomUrl: row.roomUrl.trim().isNotEmpty,
            apiSearchTried: row.roomImportEnrichLastAttemptAt != null,
            apiSearchReason: row.roomImportEnrichFailureReason,
            pendingFields: _pendingFieldLabels(flags),
            reason: _pendingReasonLabel(row),
          );
        }
        sw.stop();
        enrichmentBatchMs = sw.elapsedMilliseconds;
        enrichmentUpdated = er.updated;
        enrichmentProductAttempts = er.productEnrichmentSlots;
        var pendingAfterRestrict = 0;
        for (final id in result.newlyImportedProductIds) {
          final row = productRepo.getByProductId(id);
          if (row != null &&
              RoomImportMetadataEnrichmentService.needFlagsForProduct(row)
                  .willEnrich) {
            pendingAfterRestrict++;
          }
        }
        roomImportInitialEnrichStopLog(
          'reason=${er.initialEnrichStopReason} attempted=${er.productEnrichmentSlots} '
          'success=${er.updated} failed=${er.failedInBatch} '
          'remainingImportedPending=$pendingAfterRestrict durationMs=${sw.elapsedMilliseconds}',
        );
        roomImportInitialEnrichResultLog(
          'attempted=${er.productEnrichmentSlots} success=${er.updated} '
          'failed=${er.failedInBatch} rateLimited=${er.pausedByRateLimit} '
          'pendingAfter=${er.remainingPending}',
        );
        roomImportBatchResultLog(
          'imported=${result.newlyCollectedCount} '
          'enrichedSuccess=$enrichmentUpdated '
          'enrichedFailed=${er.failedInBatch} '
          'enrichedSkipped=${er.skippedRestrictedAlreadyComplete} '
          'nextCursor=${result.collectsLastNextCursor ?? '-'} '
          'cursorAction=postEnrich',
        );
        result = result.withPostImportEnrichSummary(
          success: er.updated,
          fail: er.failedInBatch,
          remainingImportedPending: pendingAfterRestrict,
          hitTimeLimit: er.initialEnrichStopReason == 'maxDurationReached',
        );
      } else if (result != null && !result.hasFatalError) {
        roomImportBatchResultLog(
          'imported=${result.newlyCollectedCount} '
          'enrichedSuccess=0 enrichedFailed=0 enrichedSkipped=0 '
          'nextCursor=${result.collectsLastNextCursor ?? '-'} '
          'cursorAction=none',
        );
      }

      if (context.mounted) {
        await context
            .read<RakutenManagedProductProvider>()
            .refreshManagedProductList(showLoadingIndicator: false);
      }

      if (context.mounted &&
          result != null &&
          !result.hasFatalError &&
          result.newlyImportedProductIds.isNotEmpty) {
        final act = context.read<RoomActivityEventProvider>();
        final existing = act.events;
        final now = DateTime.now();
        final dayStart = DateTime(now.year, now.month, now.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final rawIds = result.newlyImportedProductIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final orderedUnique = <String>[];
        final seen = <String>{};
        for (final id in rawIds) {
          if (seen.add(id)) orderedUnique.add(id);
        }
        final duplicateBatch = rawIds.length - orderedUnique.length;
        var created = 0;
        var duplicateDay = 0;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        var i = 0;
        for (final id in orderedUnique) {
          if (existing.any(
            (e) =>
                e.productId.trim() == id &&
                e.type == RoomActivityEventType.importedFromRoom &&
                !e.createdAt.isBefore(dayStart) &&
                e.createdAt.isBefore(dayEnd),
          )) {
            duplicateDay++;
            roomImportEventCreateLog(
              'productId=$id eventType=importedFromRoom created=false reason=alreadyExists',
            );
            continue;
          }
          await act.append(
            RoomActivityEvent(
              id: '${id}_importedFromRoom_${stamp}_$i',
              productId: id,
              type: RoomActivityEventType.importedFromRoom,
              createdAt: DateTime.now(),
            ),
          );
          created++;
          i++;
          roomImportEventCreateLog(
            'productId=$id eventType=importedFromRoom created=true reason=newlyImported',
          );
        }
        roomImportEventSummaryLog(
          'newlyImported=${orderedUnique.length} eventsCreated=$created '
          'eventsSkipped=$duplicateDay duplicatePrevented=$duplicateBatch',
        );
      }

      if (result == null) {
        _phase = RoomImportPhase.idle;
      } else if (result.hasFatalError) {
        _phase = RoomImportPhase.failed;
      } else {
        _phase = RoomImportPhase.completed;
        _setUiPhase(RoomImportUiPhase.finished);
        _applyResultSnapshot(result);
        roomImportUiLog(
          'phase=finished added=${result.newlyCollectedCount} updated=${result.roomUrlAddedCount} skipped=${result.skippedCount} failed=${result.failedCount}',
        );
      }
      notifyListeners();
    } finally {
      if (kDebugMode) {
        RoomImportDebugLogBuffer.emitImportSummary(
          result: result,
          enrichmentBatchMs: enrichmentBatchMs,
          enrichmentUpdated: enrichmentUpdated,
          enrichmentProductAttempts: enrichmentProductAttempts,
        );
      }
      _bulkOperationState?.setRoomImportRunning(false);
      roomSyncJobLockLog(
        'action=release job=importingCollectedItems currentJob=none',
      );
      if (_phase == RoomImportPhase.running) {
        _phase = RoomImportPhase.idle;
        notifyListeners();
      }
    }

    var pendingEnrich = 0;
    if (context.mounted) {
      pendingEnrich =
          RoomImportMetadataEnrichmentService.countPendingEnrichment(
            context.read<RakutenManagedProductProvider>().items,
          );
    }

    roomImportFlowLog(
      'action=importEnd '
      'newItems=${result?.newlyCollectedCount ?? 0} '
      'updatedRoomReactions=${result?.reactionsResyncedCount ?? 0} '
      'roomUrlAdded=${result?.roomUrlAddedCount ?? 0} '
      'postImportEnrichUpdated=$enrichmentUpdated '
      'pendingEnrich=$pendingEnrich',
    );

    roomImportDeferredEnrichDecisionLog(
      'shouldStart=false reason=postImportInlineEnrich '
      'manualBusy=${_bulkOperationState?.isMetadataEnriching ?? false} '
      'autoBusy=${RoomImportMetadataEnrichmentService.isEnrichmentSingleFlightHeld}',
    );

    return result;
  }

  /// 反応数のみ同期（最大10件）。他ジョブ実行中は null。
  Future<RoomReactionSyncBatchResult?> runReactionSync(
    BuildContext context,
  ) async {
    final bulk = _bulkOperationState;
    if (bulk != null) {
      if (bulk.isRoomImportRunning) {
        roomSyncJobLockLog(
          'action=blocked job=syncingReactions currentJob=importingCollectedItems',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(bulk.blockingRoomTourUserMessage ?? '')),
          );
        }
        return null;
      }
      if (bulk.isMetadataEnriching) {
        roomSyncJobLockLog(
          'action=blocked job=syncingReactions currentJob=enrichingMetadata',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(bulk.blockingRoomTourUserMessage ?? '')),
          );
        }
        return null;
      }
    }
    if (_phase == RoomImportPhase.running) return null;

    final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
      context.read<UserProfileProvider>().profile.roomUrl,
    );
    if (profile.isEmpty) return null;

    roomSyncJobLockLog('action=acquire job=syncingReactions currentJob=none');
    _bulkOperationState?.setRoomReactionSyncRunning(true);
    RoomReactionSyncBatchResult? out;
    try {
      out = await RoomPostImportFlow.executeReactionSyncBatch(
        context,
        onProgress:
            ({
              required bool busy,
              required int completed,
              required int total,
            }) {},
        onProcessingHint: (_) {},
      );
      if (context.mounted) {
        await context
            .read<RakutenManagedProductProvider>()
            .refreshManagedProductList(showLoadingIndicator: false);
      }
    } catch (e, st) {
      debugPrint(
        '[RoomImportController] executeReactionSyncBatch failed: $e\n$st',
      );
      out = null;
    } finally {
      _bulkOperationState?.setRoomReactionSyncRunning(false);
      roomSyncJobLockLog('action=release job=syncingReactions currentJob=none');
    }
    if (out != null && !out.hasFatalError) {
      final entry = await RoomReactionSyncHistoryStore.appendFromBatchResult(out);
      _bulkOperationState?.setLastReactionSyncSummary(entry);
    }
    return out;
  }
}

String _pendingFieldLabels(RoomImportEnrichmentNeedFlags flags) {
  final parts = <String>[];
  if (flags.needsShopName) parts.add('shopName');
  if (flags.needsGenre) parts.add('genreName');
  if (flags.needsImage) parts.add('image');
  if (flags.needsPrice) parts.add('price');
  return parts.isEmpty ? 'none' : parts.join(',');
}

String _pendingReasonLabel(RakutenManagedProduct row) {
  final reason = row.roomImportEnrichFailureReason.trim();
  if (reason == '429' || reason.contains('rate')) return 'rateLimit';
  if (reason.contains('timeout')) return 'timeout';
  if (reason == 'noItems' || reason.contains('noMatch')) return 'noApiMatch';
  if (row.shopCode.trim().isEmpty) return 'shopCodeMissing';
  if (row.imageUrl.trim().isEmpty) return 'noImageInRoom';
  if (row.itemPrice <= 0) return 'priceMissing';
  if (reason.isNotEmpty) return reason;
  return 'unknown';
}
