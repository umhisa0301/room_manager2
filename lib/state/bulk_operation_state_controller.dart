import 'package:flutter/material.dart';

/// DB 更新を伴う一括処理の競合防止用（ROOM取り込み・一括候補登録・メタデータ補完など）。
class BulkOperationStateController extends ChangeNotifier {
  bool _roomImport = false;
  bool _bulkCandidate = false;
  bool _metadataEnrich = false;

  bool get isRoomImportRunning => _roomImport;

  bool get isBulkCandidateRegistering => _bulkCandidate;

  bool get isMetadataEnriching => _metadataEnrich;

  bool get isAnyBlockingOperationRunning =>
      _roomImport || _bulkCandidate || _metadataEnrich;

  void setRoomImportRunning(bool value) {
    if (_roomImport == value) return;
    _roomImport = value;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('処理中です。完了してからもう一度お試しください'),
      ),
    );
    return true;
  }
}
