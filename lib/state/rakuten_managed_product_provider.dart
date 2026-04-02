import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/pending_collect_notice_repository.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../services/app_action_service.dart';
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
  RakutenManagedProductProvider({
    required RakutenManagedProductRepository repository,
    required PendingCollectNoticeRepository pendingCollectNoticeRepository,
  })  : _repository = repository,
        _pendingCollectNoticeRepository = pendingCollectNoticeRepository {
    _reloadFromStorage();
  }

  final RakutenManagedProductRepository _repository;
  final PendingCollectNoticeRepository _pendingCollectNoticeRepository;

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
      _listUiErrorMessage = null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] refreshManagedProductList failed: $e');
        debugPrint('$st');
      }
      _listUiStatus = RakutenManagedProductListUiStatus.error;
      _listUiErrorMessage =
          '一覧データの読み込みに失敗しました。少し待ってから「再試行」を押してください。';
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
        final extractionPageUrl = item.itemUrl.trim().isNotEmpty
            ? item.itemUrl.trim()
            : item.browserLaunchUrl;
        unawaited(_runPostRegisterExtraction(id, extractionPageUrl));
      }
      return null;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] registerCandidate failed: $e');
      }
      return '候補の登録に失敗しました。しばらく待ってからもう一度お試しください。';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] registerCandidate failed: $e');
      }
      return '候補の登録に失敗しました。しばらく待ってからもう一度お試しください。';
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

  /// 楽天の商品ページ URL（itemUrl）を外部ブラウザで開く。
  Future<String?> openRakutenItemPage(
    BuildContext context,
    String productId,
  ) async {
    final id = productId.trim();
    if (id.isEmpty) return '商品IDが空です';
    final p = _repository.getByProductId(id);
    if (p == null) return '商品が見つかりません';
    final url = p.itemUrl.trim().isNotEmpty
        ? p.itemUrl.trim()
        : p.browserLaunchUrl.trim();
    if (url.isEmpty) return '商品URLがありません';
    await AppActionService.openUrl(context, url: url);
    return null;
  }

  bool canCollectRoomUrl(String productId) {
    final p = _repository.getByProductId(productId.trim());
    if (p == null) return false;
    return p.extractionStatus == RakutenUrlExtractionStatus.success &&
        p.extractedUrl.trim().isNotEmpty;
  }

  /// コレ済に更新してから ROOM（抽出 URL）を開く。抽出 URL 不備時は [SnackBar] で通知。
  Future<void> collectRoomAndLaunch(BuildContext context, String productId) async {
    final id = productId.trim();
    if (id.isEmpty) {
      _snack(context, '商品IDが空です');
      return;
    }
    final p = _repository.getByProductId(id);
    if (p == null) {
      _snack(context, '商品が見つかりません');
      return;
    }
    if (p.extractionStatus != RakutenUrlExtractionStatus.success ||
        p.extractedUrl.trim().isEmpty) {
      _snack(context, 'ROOM用URLがまだ取得できていません');
      return;
    }
    final roomUrl = p.extractedUrl.trim();
    final noticeName = p.itemName.trim().isNotEmpty ? p.itemName : id;
    try {
      await _repository.markCollectedDone(id);
      await _pendingCollectNoticeRepository.enqueuePendingCollectNotice(
        noticeName,
      );
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      notifyListeners();
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] collectRoomAndLaunch failed: $e');
      }
      if (context.mounted) {
        _snack(
          context,
          'コレ済への更新に失敗しました。通信状況を確認のうえ、もう一度お試しください。',
        );
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] collectRoomAndLaunch failed: $e');
      }
      if (context.mounted) {
        _snack(
          context,
          'コレ済への更新に失敗しました。通信状況を確認のうえ、もう一度お試しください。',
        );
      }
      return;
    }
    if (!context.mounted) return;
    await AppActionService.openUrl(context, url: roomUrl);
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// コレ候補を一覧から削除する。
  Future<String?> removeCandidate(BuildContext context, String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return '商品IDが空です';
    try {
      await _repository.removeCandidateProduct(id);
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('候補から外しました')),
        );
      }
      return null;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] removeCandidate failed: $e');
      }
      return '候補から外せませんでした。しばらく待ってからもう一度お試しください。';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] removeCandidate failed: $e');
      }
      return '候補から外せませんでした。しばらく待ってからもう一度お試しください。';
    }
  }
}
