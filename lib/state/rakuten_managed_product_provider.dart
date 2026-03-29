import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../services/room_url_extraction_coordinator.dart';
import '../services/room_url_extraction_service.dart';

/// 楽天ROOM管理の一覧画面用ロード状態。
enum RakutenManagedProductListUiStatus {
  idle,
  loading,
  ready,
  error,
}

/// 楽天検索由来のローカル管理商品の状態（UI向け）。
class RakutenManagedProductProvider extends ChangeNotifier {
  RakutenManagedProductProvider({required RakutenManagedProductRepository repository})
      : _repository = repository {
    _reloadFromStorage();
  }

  final RakutenManagedProductRepository _repository;

  List<RakutenManagedProduct> _items = const [];
  final Set<String> _registeringProductIds = {};
  RakutenManagedProductListUiStatus _listUiStatus =
      RakutenManagedProductListUiStatus.idle;
  String? _listUiErrorMessage;

  List<RakutenManagedProduct> get items => List.unmodifiable(_items);

  RakutenManagedProductListUiStatus get listUiStatus => _listUiStatus;
  String? get listUiErrorMessage => _listUiErrorMessage;

  /// [status] ごとの一覧（メモリ上の [_items] から。更新日時降順）。
  List<RakutenManagedProduct> sortedItemsForStatus(
    RakutenManagedProductStatus status,
  ) {
    final filtered = _items.where((e) => e.status == status).toList();
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(filtered);
  }

  /// 一覧画面の再読込（ローディング・エラー状態を更新）。
  /// [showLoadingIndicator] が false のときは [RakutenManagedProductListUiStatus.loading] にしない（初回同期用）。
  Future<void> refreshManagedProductList({
    bool showLoadingIndicator = true,
  }) async {
    if (showLoadingIndicator) {
      _listUiStatus = RakutenManagedProductListUiStatus.loading;
      _listUiErrorMessage = null;
      notifyListeners();
    }
    try {
      await Future<void>.delayed(Duration.zero);
      _items = _repository.loadAll();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
    } catch (e) {
      _listUiStatus = RakutenManagedProductListUiStatus.error;
      _listUiErrorMessage = e.toString();
    }
    notifyListeners();
  }

  /// 永続化一覧に無い場合は [RakutenManagedProductStatus.none]。
  RakutenManagedProductStatus statusForProduct(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return RakutenManagedProductStatus.none;
    for (final e in _items) {
      if (e.productId == id) return e.status;
    }
    return RakutenManagedProductStatus.none;
  }

  bool isRegistering(String productId) =>
      _registeringProductIds.contains(productId.trim());

  void _reloadFromStorage() {
    _items = _repository.loadAll();
  }

  /// コレ候補として登録。成功時は null、失敗時はエラーメッセージ。
  /// 既に候補・コレ済の場合は重複せず成功扱い（null）。URL抽出は新規登録時のみ非同期で開始。
  Future<String?> registerCandidate(RakutenSearchItem item) async {
    final id = item.productId.trim();
    if (id.isEmpty) {
      return '商品IDが空のため登録できません';
    }
    if (_registeringProductIds.contains(id)) {
      return null;
    }
    _registeringProductIds.add(id);
    notifyListeners();
    try {
      final added = await _repository.registerCandidateFromSearchItem(item);
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      if (added) {
        await _repository.markExtractionExtracting(id);
        _reloadFromStorage();
        notifyListeners();
        final launch = item.browserLaunchUrl;
        unawaited(_runPostRegisterExtraction(id, launch));
      }
      return null;
    } on Exception catch (e) {
      return e.toString();
    } catch (e) {
      return '登録に失敗しました: $e';
    } finally {
      _registeringProductIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> _runPostRegisterExtraction(
    String productId,
    String pageUrl,
  ) async {
    try {
      for (var i = 0; i < 120; i++) {
        if (RoomUrlExtractionCoordinator.instance.isReady) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!RoomUrlExtractionCoordinator.instance.isReady) {
        const msg = 'URL抽出エンジンが初期化されませんでした';
        debugPrint(
          '[RoomUrlExtraction] 失敗 [登録フロー] productId=$productId: $msg',
        );
        await _repository.completeExtractionFailed(productId, msg);
      } else {
        try {
          final url =
              await RoomUrlExtractionService.extractRoomTargetUrl(pageUrl);
          await _repository.completeExtractionSuccess(productId, url);
        } on Exception catch (e) {
          debugPrint(
            '[RoomUrlExtraction] 失敗 [登録フロー] productId=$productId: $e',
          );
          await _repository.completeExtractionFailed(productId, e.toString());
        } catch (e) {
          debugPrint(
            '[RoomUrlExtraction] 失敗 [登録フロー] productId=$productId: $e',
          );
          await _repository.completeExtractionFailed(productId, e.toString());
        }
      }
    } catch (e) {
      try {
        await _repository.completeExtractionFailed(productId, e.toString());
      } catch (_) {}
    }
    _reloadFromStorage();
    notifyListeners();
  }
}
