import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_sync_result.dart';
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
    final profile = context.read<UserProfileProvider>().profile.roomUrl.trim();
    if (profile.isEmpty) return null;

    _phase = RoomImportPhase.running;
    _checkedCount = 0;
    _targetCount = 0;
    _bulkOperationState?.setRoomImportRunning(true);
    notifyListeners();

    try {
      RoomSyncResult? result;
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
        notifyListeners();
        return null;
      }

      if (result.hasFatalError) {
        _phase = RoomImportPhase.failed;
      } else {
        _phase = RoomImportPhase.completed;
        _applyResultSnapshot(result);
      }
      notifyListeners();
      return result;
    } finally {
      _bulkOperationState?.setRoomImportRunning(false);
      if (_phase == RoomImportPhase.running) {
        _phase = RoomImportPhase.idle;
        notifyListeners();
      }
    }
  }
}
