import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_sync_result.dart';
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
  Future<RoomSyncResult?> runImport(BuildContext context) async {
    if (_phase == RoomImportPhase.running) return null;
    final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
      context.read<UserProfileProvider>().profile.roomUrl,
    );
    if (profile.isEmpty) return null;

    roomImportFlowLog(
      'action=importStart message=ROOM取り込みでは価格・画像・ショップ・ジャンルは更新しません',
    );

    _phase = RoomImportPhase.running;
    _checkedCount = 0;
    _targetCount = 0;
    _importProcessingHint = '';
    _bulkOperationState?.setRoomImportRunning(true);
    notifyListeners();

    RoomSyncResult? result;
    try {
      try {
        result = await RoomPostImportFlow.executeBatch(
          context,
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
          enrichmentBatchMs: 0,
          enrichmentUpdated: 0,
        );
      }
      _bulkOperationState?.setRoomImportRunning(false);
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
      'pendingEnrich=$pendingEnrich '
      'enrichmentAutoStarted=false '
      'message=ROOM取り込みでは価格・画像・ショップ・ジャンルは更新しません',
    );

    roomImportDeferredEnrichDecisionLog(
      'shouldStart=false reason=postImportDeferredEnrichRemoved '
      'manualBusy=${_bulkOperationState?.isMetadataEnriching ?? false} '
      'autoBusy=${RoomImportMetadataEnrichmentService.isEnrichmentSingleFlightHeld}',
    );

    return result;
  }
}
