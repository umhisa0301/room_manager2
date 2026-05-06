import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';

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
    debugPrint('[MANAGED_PRODUCT_SAVE]');
    debugPrint('action=$action');
    debugPrint('productId=$productId');
    debugPrint('itemCode=$itemCode');
    debugPrint('beforePendingCount=$beforePendingCount');
    debugPrint('afterPendingCount=$afterPendingCount');
    debugPrint('beforeDoneCount=$beforeDoneCount');
    debugPrint('afterDoneCount=$afterDoneCount');
  }

  static void logLoad({
    required String source,
    required int pendingCount,
    required int doneCount,
    String filter = '',
    String tab = '',
  }) {
    if (!kDebugMode) return;
    debugPrint('[MANAGED_PRODUCT_LOAD]');
    debugPrint('source=$source');
    debugPrint('pendingCount=$pendingCount');
    debugPrint('doneCount=$doneCount');
    debugPrint('filter=$filter');
    debugPrint('tab=$tab');
  }

  static void logMutationLock({
    required bool isBulkRunning,
    required String blockedAction,
  }) {
    if (!kDebugMode) return;
    debugPrint('[MANAGED_PRODUCT_MUTATION_LOCK]');
    debugPrint('isBulkRunning=$isBulkRunning');
    debugPrint('blockedAction=$blockedAction');
  }
}
