import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../models/rakuten_managed_product.dart';
import 'app_debug_log.dart';

/// ROOMコレ候補／コレ済の状態追跡用デバッグログ（[kDebugMode] のみ出力）。
class ManagedProductDiagLog {
  ManagedProductDiagLog._();

  /// 診断以外から件数だけ参照する場合に使用。
  static (int pending, int done) pendingAndDoneCounts(
    Iterable<RakutenManagedProduct> items,
  ) {
    return (_pendingCount(items), _doneCount(items));
  }

  static int _pendingCount(Iterable<RakutenManagedProduct> items) {
    var n = 0;
    for (final e in items) {
      if (RakutenManagedProduct.isMemberForStatusTab(
            e,
            RakutenManagedProductStatus.candidate,
          )) {
        n++;
      }
    }
    return n;
  }

  static int _doneCount(Iterable<RakutenManagedProduct> items) {
    var n = 0;
    for (final e in items) {
      if (RakutenManagedProduct.isMemberForStatusTab(
            e,
            RakutenManagedProductStatus.done,
          )) {
        n++;
      }
    }
    return n;
  }

  static void logSave({
    required String action,
    String productId = '',
    String itemCode = '',
    int beforePendingCount = -1,
    int afterPendingCount = -1,
    int beforeDoneCount = -1,
    int afterDoneCount = -1,
  }) {
    if (!kDebugMode) return;
    if (!DebugLogFlags.kVerboseItemLogsEnabled) {
      if (DebugLogFlags.kDebugLogSummaryEnabled) {
        debugSummaryLog(
          '[MANAGED_PRODUCT_SAVE] action=$action productId=$productId '
          'pending=$beforePendingCount→$afterPendingCount '
          'done=$beforeDoneCount→$afterDoneCount',
        );
      }
      return;
    }
    verboseItemLog('[MANAGED_PRODUCT_SAVE]');
    verboseItemLog('action=$action');
    verboseItemLog('productId=$productId');
    verboseItemLog('itemCode=$itemCode');
    verboseItemLog('beforePendingCount=$beforePendingCount');
    verboseItemLog('afterPendingCount=$afterPendingCount');
    verboseItemLog('beforeDoneCount=$beforeDoneCount');
    verboseItemLog('afterDoneCount=$afterDoneCount');
  }

  static void logLoad({
    required String source,
    required int pendingCount,
    required int doneCount,
    String filter = '',
    String tab = '',
  }) {
    if (!kDebugMode) return;
    if (!DebugLogFlags.kVerboseItemLogsEnabled) {
      if (DebugLogFlags.kDebugLogSummaryEnabled) {
        debugSummaryLog(
          '[MANAGED_PRODUCT_LOAD] source=$source pending=$pendingCount '
          'done=$doneCount filter=$filter tab=$tab',
        );
      }
      return;
    }
    verboseItemLog('[MANAGED_PRODUCT_LOAD]');
    verboseItemLog('source=$source');
    verboseItemLog('pendingCount=$pendingCount');
    verboseItemLog('doneCount=$doneCount');
    verboseItemLog('filter=$filter');
    verboseItemLog('tab=$tab');
  }

  static void logMutationLock({
    required bool isBulkRunning,
    required String blockedAction,
  }) {
    if (!kDebugMode) return;
    importantDebugLog(
      '[MANAGED_PRODUCT_MUTATION_LOCK] isBulkRunning=$isBulkRunning '
      'blockedAction=$blockedAction',
    );
  }
}
