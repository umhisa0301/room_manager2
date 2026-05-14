import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_sync_result.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../services/room_profile_url_validation_service.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_managed_product_provider.dart';
import 'user_profile_provider.dart';
import '../widgets/room_post_import_flow.dart';
import 'bulk_operation_state_controller.dart';

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

  /// [RoomSyncService.onProcessingHint] から渡る短文（ホーム等の進捗表示用）。
  String get importProcessingHint => _importProcessingHint;

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
    _checkedCount = r.listingCheckedCount;
    _targetCount = r.listingCheckedCount;
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
    roomImportFlowLog(
      'action=importStart message=新規取り込み商品のみ初回楽天API補完',
    );

    _phase = RoomImportPhase.running;
    _checkedCount = 0;
    _targetCount = 0;
    _importProcessingHint = '';
    _bulkOperationState?.setRoomImportRunning(true);
    notifyListeners();

    RoomSyncResult? result;
    var enrichmentBatchMs = 0;
    var enrichmentUpdated = 0;
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
                  notifyListeners();
                }
              },
          onProcessingHint: (hint) {
            _importProcessingHint = hint;
            notifyListeners();
          },
        );
      } catch (e, st) {
        debugPrint('[RoomImportController] executeBatch failed: $e\n$st');
        result = null;
      }

      if (context.mounted) {
        await context
            .read<RakutenManagedProductProvider>()
            .refreshManagedProductList(showLoadingIndicator: false);
      }

      if (result != null &&
          !result.hasFatalError &&
          result.newlyImportedProductIds.isNotEmpty &&
          context.mounted) {
        final sw = Stopwatch()..start();
        final searchRepo = context.read<RakutenSearchRepository>();
        final productRepo = context.read<RakutenManagedProductRepository>();
        final svc = RoomImportMetadataEnrichmentService(
          searchRepository: searchRepo,
          productRepository: productRepo,
        );
        final er = await svc.enrichRoomImportedProducts(
          limit: RoomImportLimitPolicy.freeBatchLimit,
          applyPostImportAutoCap: true,
          manualSessionPacing: false,
          restrictToProductIdsInOrder: result.newlyImportedProductIds,
        );
        sw.stop();
        enrichmentBatchMs = sw.elapsedMilliseconds;
        enrichmentUpdated = er.updated;
        if (context.mounted) {
          await context
              .read<RakutenManagedProductProvider>()
              .refreshManagedProductList(showLoadingIndicator: false);
        }
        roomImportBatchResultLog(
          'imported=${result.newlyCollectedCount} '
          'enrichedSuccess=$enrichmentUpdated '
          'enrichedFailed=${er.failedInBatch} '
          'nextCursor=${result.collectsLastNextCursor ?? '-'} '
          'cursorAction=postEnrich',
        );
      } else if (result != null && !result.hasFatalError) {
        roomImportBatchResultLog(
          'imported=${result.newlyCollectedCount} '
          'enrichedSuccess=0 enrichedFailed=0 '
          'nextCursor=${result.collectsLastNextCursor ?? '-'} '
          'cursorAction=none',
        );
      }

      if (result == null) {
        _phase = RoomImportPhase.idle;
      } else if (result.hasFatalError) {
        _phase = RoomImportPhase.failed;
      } else {
        _phase = RoomImportPhase.completed;
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
      pendingEnrich = RoomImportMetadataEnrichmentService.countPendingEnrichment(
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

    roomSyncJobLockLog(
      'action=acquire job=syncingReactions currentJob=none',
    );
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
      debugPrint('[RoomImportController] executeReactionSyncBatch failed: $e\n$st');
      out = null;
    } finally {
      _bulkOperationState?.setRoomReactionSyncRunning(false);
      roomSyncJobLockLog(
        'action=release job=syncingReactions currentJob=none',
      );
    }
    return out;
  }
}
