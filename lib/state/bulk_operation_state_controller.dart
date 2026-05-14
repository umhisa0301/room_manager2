import 'dart:async' show Timer;

import 'package:flutter/material.dart';

/// DB 更新を伴う一括処理の競合防止用（ROOM取り込み・一括候補登録・メタデータ補完など）。
class BulkOperationStateController extends ChangeNotifier {
  static const String blockingSnackMessage =
      '処理中です。完了後に操作してください';
  bool _roomImport = false;
  bool _roomReactionSync = false;
  bool _bulkCandidate = false;
  bool _metadataEnrich = false;

  /// 直近の手動「情報を補完」結果（ROOMコレバナー・一覧ハイライト用）。
  bool _hasManualEnrichSummary = false;
  var _lastManualSuccess = 0;
  var _lastManualFail = 0;
  var _lastManualRemaining = 0;
  var _lastManualPausedRateLimit = false;

  final Set<String> _roomImportEnrichHighlightIds = {};
  Timer? _roomImportEnrichHighlightTimer;

  bool get hasManualEnrichSummary => _hasManualEnrichSummary;

  int get lastManualEnrichSuccess => _lastManualSuccess;

  int get lastManualEnrichFail => _lastManualFail;

  int get lastManualEnrichRemaining => _lastManualRemaining;

  bool get lastManualEnrichPausedRateLimit => _lastManualPausedRateLimit;

  bool isRoomImportEnrichHighlighted(String productId) =>
      _roomImportEnrichHighlightIds.contains(productId.trim());

  void setManualEnrichSummary({
    required int success,
    required int fail,
    required int remaining,
    required bool pausedByRateLimit,
  }) {
    _hasManualEnrichSummary = true;
    _lastManualSuccess = success;
    _lastManualFail = fail;
    _lastManualRemaining = remaining;
    _lastManualPausedRateLimit = pausedByRateLimit;
    notifyListeners();
  }

  /// 補完に成功した商品をしばらく一覧で強調する。
  void flashRoomImportEnrichedIds(Iterable<String> productIds) {
    _roomImportEnrichHighlightIds
      ..clear()
      ..addAll(
        productIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    _roomImportEnrichHighlightTimer?.cancel();
    _roomImportEnrichHighlightTimer = Timer(
      const Duration(seconds: 50),
      () {
        _roomImportEnrichHighlightIds.clear();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  bool get isRoomImportRunning => _roomImport;

  bool get isRoomReactionSyncRunning => _roomReactionSync;

  bool get isBulkCandidateRegistering => _bulkCandidate;

  bool get isMetadataEnriching => _metadataEnrich;

  bool get isAnyBlockingOperationRunning =>
      _roomImport || _roomReactionSync || _bulkCandidate || _metadataEnrich;

  /// ROOM 巡回系（取り込み・反応同期・補完）のどれが動いているか。null は該当なし。
  String? get blockingRoomTourUserMessage {
    if (_roomImport) {
      return '投稿済み商品の取り込みが実行中です。完了後にお試しください。';
    }
    if (_roomReactionSync) {
      return '反応数の同期が実行中です。完了後にお試しください。';
    }
    if (_metadataEnrich) {
      return '商品情報の補完が実行中です。完了後にお試しください。';
    }
    return null;
  }

  void setRoomImportRunning(bool value) {
    if (_roomImport == value) return;
    _roomImport = value;
    notifyListeners();
  }

  void setRoomReactionSyncRunning(bool value) {
    if (_roomReactionSync == value) return;
    _roomReactionSync = value;
    notifyListeners();
  }

  void setBulkCandidateRegistering(bool value) {
    if (_bulkCandidate == value) return;
    _bulkCandidate = value;
    notifyListeners();
  }

  void setMetadataEnriching(bool value) {
    if (_metadataEnrich == value) return;
    _metadataEnrich = value;
    notifyListeners();
  }

  /// いずれかのブロック対象処理が走っているとき SnackBar を出して true。
  bool guardBlockingOperations(BuildContext context) {
    if (!isAnyBlockingOperationRunning) return false;
    final roomMsg = blockingRoomTourUserMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          roomMsg ?? blockingSnackMessage,
        ),
      ),
    );
    return true;
  }
}
