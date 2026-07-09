import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../models/room_activity_event.dart';
import '../repository/pending_collect_notice_repository.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import 'room_activity_event_provider.dart';
import 'bulk_operation_state_controller.dart';
import '../services/app_action_service.dart';
import '../services/analytics_service.dart';
import '../services/room_collect_post_limit.dart';
import '../services/room_url_extraction_coordinator.dart';
import '../services/room_url_extraction_service.dart';
import '../services/room_collected_register_service.dart';
import '../utils/app_debug_log.dart';
import '../utils/managed_product_diag_log.dart';
import '../utils/room_sync_log.dart';
import '../widgets/collect_post_success_overlay.dart';
import '../models/analytics_params.dart';

/// 楽天ROOM管理の一覧画面用ロード状態。
enum RakutenManagedProductListUiStatus { idle, loading, ready, error }

/// 楽天検索由来のローカル管理商品の状態（UI向け）。
class RakutenManagedProductProvider extends ChangeNotifier {
  RakutenManagedProductProvider({
    required RakutenManagedProductRepository repository,
    required PendingCollectNoticeRepository pendingCollectNoticeRepository,
    required RoomActivityEventProvider activityEventProvider,
    RakutenSearchRepository? rakutenSearchRepository,
    BulkOperationStateController? bulkOperationState,
    AnalyticsService? analytics,
  }) : _repository = repository,
       _pendingCollectNoticeRepository = pendingCollectNoticeRepository,
       _activityEventProvider = activityEventProvider,
       _bulkOperationState = bulkOperationState,
       _analytics = analytics ?? AnalyticsServiceRegistry.instance,
       _roomCollectedRegisterService = RoomCollectedRegisterService(
         repository: repository,
         searchRepository: rakutenSearchRepository,
       ) {
    _reloadFromStorage();
    _listUiStatus = RakutenManagedProductListUiStatus.ready;
    _listUiErrorMessage = null;
  }

  final RakutenManagedProductRepository _repository;
  final PendingCollectNoticeRepository _pendingCollectNoticeRepository;
  final RoomActivityEventProvider _activityEventProvider;
  final BulkOperationStateController? _bulkOperationState;
  final AnalyticsService _analytics;
  final RoomCollectedRegisterService _roomCollectedRegisterService;

  static String _newEventId(String productId, RoomActivityEventType type) =>
      '${DateTime.now().microsecondsSinceEpoch}_${productId.trim()}_${type.name}';

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
    final filtered = _items
        .where((e) => RakutenManagedProduct.isMemberForStatusTab(e, status))
        .toList();
    try {
      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      // 日時不整合時は並び替えを諦める（一覧は表示を優先）
    }
    return List.unmodifiable(filtered);
  }

  /// 一覧画面の再読込（ローディング・エラー状態を更新）。
  /// [showLoadingIndicator] が false のときは [RakutenManagedProductListUiStatus.loading] にしない（初回同期用）。
  Future<void> refreshManagedProductList({
    bool showLoadingIndicator = true,
    String loadSource = 'provider',
    String filter = '',
    String tab = '',
  }) async {
    if (showLoadingIndicator) {
      _listUiStatus = RakutenManagedProductListUiStatus.loading;
      _listUiErrorMessage = null;
      notifyListeners();
    }
    try {
      await Future<void>.delayed(Duration.zero);
      final before = ManagedProductDiagLog.pendingAndDoneCounts(_items);
      _items = _repository.loadAll();
      final after = ManagedProductDiagLog.pendingAndDoneCounts(_items);
      ManagedProductDiagLog.logSave(
        action: 'refresh',
        productId: '',
        itemCode: '',
        beforePendingCount: before.$1,
        afterPendingCount: after.$1,
        beforeDoneCount: before.$2,
        afterDoneCount: after.$2,
      );
      ManagedProductDiagLog.logLoad(
        source: loadSource,
        pendingCount: after.$1,
        doneCount: after.$2,
        filter: filter,
        tab: tab,
      );
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      roomAuditLog(
        '[ROOMコレ診断] refreshManagedProductList 完了 total=${_items.length} '
        'candidate=${sortedItemsForStatus(RakutenManagedProductStatus.candidate).length} '
        'done=${sortedItemsForStatus(RakutenManagedProductStatus.done).length} ui=ready',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[RakutenManagedProduct] refreshManagedProductList failed: $e',
        );
        debugPrint('$st');
      }
      _listUiStatus = RakutenManagedProductListUiStatus.error;
      _listUiErrorMessage = '一覧データの読み込みに失敗しました。少し待ってから「再試行」を押してください。';
    }
    notifyListeners();
  }

  /// ローカル保存から一覧を復旧し [ready] へ戻す（エラー画面の固定化回避）。内部ログのみ。
  void recoverListUiSilently() {
    try {
      _items = _repository.loadAll();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[RakutenManagedProduct] recoverListUiSilently failed: $e\n$st',
        );
      }
      _items = const [];
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
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

  /// キーワード検索 API 結果から除外する [RakutenSearchItem.productId]（楽天 itemCode）集合。
  Set<String> productIdsExcludedFromKeywordSearch() {
    return {
      ...candidateProductIdsExcludedFromKeywordSearch(),
      ...doneProductIdsExcludedFromKeywordSearch(),
    };
  }

  Set<String> candidateProductIdsExcludedFromKeywordSearch() {
    final out = <String>{};
    for (final e in _items) {
      if (!RakutenManagedProduct.isMemberForStatusTab(
        e,
        RakutenManagedProductStatus.candidate,
      )) {
        continue;
      }
      final id = e.productId.trim();
      if (id.isNotEmpty) out.add(id);
    }
    return out;
  }

  Set<String> doneProductIdsExcludedFromKeywordSearch() {
    final out = <String>{};
    for (final e in _items) {
      if (!RakutenManagedProduct.isMemberForStatusTab(
        e,
        RakutenManagedProductStatus.done,
      )) {
        continue;
      }
      final id = e.productId.trim();
      if (id.isNotEmpty) out.add(id);
    }
    return out;
  }

  bool isRegistering(String productId) =>
      _registeringProductIds.contains(productId.trim());

  void _reloadFromStorage() {
    _items = _repository.loadAll();
  }

  /// ROOM 取り込み・反応同期・補完中は「探す」系の新規追加を抑止する。
  String? _roomTourSearchBlockUserMessage(String blockedAction) {
    final b = _bulkOperationState;
    if (b == null || !b.isRoomTourSearchBlocking) {
      return null;
    }
    roomSyncUiGuardLog(
      'blockedAction=$blockedAction currentJob=${b.roomTourBlockingJobLabel} '
      'message=searchPaused',
    );
    return BulkOperationStateController.roomTourSearchBlockedUserMessage;
  }

  String? _bulkBlocksMutation(String blockedAction) {
    final b = _bulkOperationState;
    if (b == null || !b.isAnyBlockingOperationRunning) {
      return null;
    }
    // 一括候補登録の逐次処理中は、自分自身の addCandidate をブロックしない。
    if (blockedAction == 'addCandidate' && b.isBulkCandidateRegistering) {
      return null;
    }
    ManagedProductDiagLog.logMutationLock(
      isBulkRunning: true,
      blockedAction: blockedAction,
    );
    return BulkOperationStateController.blockingSnackMessage;
  }

  /// コレ候補として登録。成功時は null、失敗時はエラーメッセージ。
  /// 既に候補・コレ済の場合は重複せず成功扱い（null）。URL抽出は新規登録時のみ非同期で開始。
  Future<String?> registerCandidate(
    RakutenSearchItem item, {
    AnalyticsCandidateSource analyticsSource = AnalyticsCandidateSource.unknown,
  }) async {
    final id = item.productId.trim();
    if (id.isEmpty) {
      return '商品IDが空のため登録できません';
    }
    final roomTour = _roomTourSearchBlockUserMessage('registerCandidate');
    if (roomTour != null) {
      return roomTour;
    }
    final blocked = _bulkBlocksMutation('addCandidate');
    if (blocked != null) {
      return blocked;
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
      if (kDebugMode) {
        final nCand = sortedItemsForStatus(
          RakutenManagedProductStatus.candidate,
        ).length;
        final nDone = sortedItemsForStatus(
          RakutenManagedProductStatus.done,
        ).length;
        roomAuditLog(
          '[ROOMコレ診断] registerCandidate 反映 productId=$id persisted→memory '
          'total=${_items.length} candidate=$nCand done=$nDone '
          'added=$added status saved=candidate',
        );
      }
      if (added) {
        final now = DateTime.now();
        await _activityEventProvider.append(
          RoomActivityEvent(
            id: _newEventId(id, RoomActivityEventType.candidateAdded),
            productId: id,
            type: RoomActivityEventType.candidateAdded,
            createdAt: now,
          ),
        );
        await _repository.markExtractionExtracting(id);
        _reloadFromStorage();
        notifyListeners();
        final extractionPageUrl = item.browserLaunchUrl;
        unawaited(_runPostRegisterExtraction(id, extractionPageUrl));
      }
      final candidateCount = sortedItemsForStatus(
        RakutenManagedProductStatus.candidate,
      ).length;
      unawaited(
        _analytics.logCandidateAdded(
          source: analyticsSource,
          alreadySaved: !added,
          candidateCountAfter: candidateCount,
        ),
      );
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
        debugPrint('[RoomUrlExtraction] 失敗 [登録フロー] productId=$productId: $msg');
        await _repository.completeExtractionFailed(productId, msg);
      } else {
        try {
          final url = await RoomUrlExtractionService.extractRoomTargetUrl(
            pageUrl,
          );
          await _repository.completeExtractionSuccess(productId, url);
        } on Exception catch (e) {
          debugPrint('[RoomUrlExtraction] 失敗 [登録フロー] productId=$productId: $e');
          await _repository.completeExtractionFailed(productId, e.toString());
        } catch (e) {
          debugPrint('[RoomUrlExtraction] 失敗 [登録フロー] productId=$productId: $e');
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

  /// 楽天の商品ページ URL を外部ブラウザで開く（[RakutenManagedProduct.rakutenOpenUrl]）。
  Future<String?> openRakutenItemPage(
    BuildContext context,
    String productId,
  ) async {
    final id = productId.trim();
    if (id.isEmpty) return '商品IDが空です';
    final p = _repository.getByProductId(id);
    if (p == null) return '商品が見つかりません';
    final url = p.rakutenOpenUrl.trim();
    if (url.isEmpty) return '商品URLがありません';
    await AppActionService.openUrl(context, url: url);
    if (context.mounted) {
      try {
        await _activityEventProvider.append(
          RoomActivityEvent(
            id: _newEventId(id, RoomActivityEventType.openedRakuten),
            productId: id,
            type: RoomActivityEventType.openedRakuten,
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }
    return null;
  }

  bool canCollectRoomUrl(String productId) {
    final p = _repository.getByProductId(productId.trim());
    if (p == null) return false;
    return p.extractionStatus == RakutenUrlExtractionStatus.success &&
        p.extractedUrl.trim().isNotEmpty;
  }

  /// ROOM 商品ページ URL からコレ済行を登録・更新する（HTTP 解析ベース）。
  Future<RoomCollectedRegisterViewResult> registerCollectedFromRoomProductPage(
    String rawRoomUrl,
  ) async {
    final roomTour = _roomTourSearchBlockUserMessage('urlAdd');
    if (roomTour != null) {
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: roomTour,
      );
    }
    final blocked = _bulkBlocksMutation('registerCollectedFromRoomProductPage');
    if (blocked != null) {
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: blocked,
      );
    }
    try {
      final r =
          await _roomCollectedRegisterService.registerFromRoomProductPageUrl(
            rawRoomUrl,
          );
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      roomAuditLog(
        '[ROOMコレ診断] registerCollectedFromRoomProductPage '
        'kind=${r.kind} productId=${r.productId ?? '-'}',
      );
      notifyListeners();
      return r;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[RakutenManagedProduct] registerCollectedFromRoomProductPage: $e\n$st',
        );
      }
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: RoomCollectedRegisterService.messageFetchFailed,
      );
    }
  }

  /// コレ済に更新してから ROOM（抽出 URL）を開く。
  /// 上限超過・入力不備はダイアログで通知する。成功時は true（URL 起動まで試行した場合も含む）。
  ///
  /// [notifyInsteadOfDialogs] を渡した場合、入力不備・上限・永続化失敗など **ブロッキング通知** は
  /// コールバックへ委譲し [AlertDialog] / 上限ダイアログを出さない（URL から追加の BottomSheet 向け）。
  /// 成功時オーバーレイと ROOM URL 起動は従来どおり行う。
  Future<bool> collectRoomAndLaunch(
    BuildContext context,
    String productId, {
    void Function(String message)? notifyInsteadOfDialogs,
    AnalyticsRoomLaunchSource analyticsSource =
        AnalyticsRoomLaunchSource.unknown,
  }) async {
    void notifyOrDialog(String message) {
      if (notifyInsteadOfDialogs != null) {
        notifyInsteadOfDialogs(message);
      } else {
        _collectIssueDialog(context, message);
      }
    }

    final id = productId.trim();
    if (id.isEmpty) {
      notifyOrDialog('商品IDが空です');
      return false;
    }
    final p = _repository.getByProductId(id);
    if (p == null) {
      notifyOrDialog('商品が見つかりません');
      return false;
    }
    if (p.status == RakutenManagedProductStatus.done) {
      const msg = 'すでにコレ済です';
      if (notifyInsteadOfDialogs != null) {
        notifyInsteadOfDialogs(msg);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(msg)),
        );
      }
      return false;
    }
    final bulkMsg = _bulkBlocksMutation('collectRoomAndLaunch');
    if (bulkMsg != null) {
      if (notifyInsteadOfDialogs != null) {
        notifyInsteadOfDialogs(bulkMsg);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bulkMsg)),
        );
      }
      return false;
    }
    if (p.extractionStatus != RakutenUrlExtractionStatus.success ||
        p.extractedUrl.trim().isEmpty) {
      notifyOrDialog('ROOM用URLがまだ取得できていません');
      return false;
    }
    final nowPre = DateTime.now();
    final preLimit = RoomCollectPostLimitSnapshot.compute(
      items: _items,
      events: _activityEventProvider.events,
      now: nowPre,
    );
    if (!preLimit.canAcceptAnotherCollect) {
      if (notifyInsteadOfDialogs != null) {
        final headline = preLimit.userBlockMessage ?? '現在は投稿できません。';
        final detail = preLimit.isHourlyReached
            ? preLimit.recoveryFootnote(nowPre)
            : preLimit.isDailyReached
                ? 'カウントは「直近24時間」の投稿のみです。0時ではリセットされません。'
                : '';
        notifyInsteadOfDialogs(
          detail.isNotEmpty ? '$headline\n\n$detail' : headline,
        );
      } else if (context.mounted) {
        await showCollectPostBlockedDialog(context, preLimit);
      }
      return false;
    }

    final roomUrl = p.extractedUrl.trim();
    final noticeName = p.itemName.trim().isNotEmpty ? p.itemName : id;
    try {
      await _repository.markCollectedDone(id);
      final now = DateTime.now();
      await _activityEventProvider.append(
        RoomActivityEvent(
          id: _newEventId(id, RoomActivityEventType.movedToCored),
          productId: id,
          type: RoomActivityEventType.movedToCored,
          createdAt: now,
        ),
      );
      await _pendingCollectNoticeRepository.enqueuePendingCollectNotice(
        noticeName,
      );
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      roomAuditLog(
        '[ROOMコレ診断] collectRoomAndLaunch 反映 productId=$id '
        'total=${_items.length} '
        'candidate=${sortedItemsForStatus(RakutenManagedProductStatus.candidate).length} '
        'done=${sortedItemsForStatus(RakutenManagedProductStatus.done).length} '
        'status saved=done',
      );
      notifyListeners();
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] collectRoomAndLaunch failed: $e');
      }
      if (context.mounted) {
        notifyOrDialog(
          'コレ済への更新に失敗しました。通信状況を確認のうえ、もう一度お試しください。',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] collectRoomAndLaunch failed: $e');
      }
      if (context.mounted) {
        notifyOrDialog(
          'コレ済への更新に失敗しました。通信状況を確認のうえ、もう一度お試しください。',
        );
      }
      return false;
    }
    if (!context.mounted) return false;

    unawaited(
      _analytics.logRoomLaunchTapped(
        source: analyticsSource,
        launchType: AnalyticsRoomLaunchType.room,
      ),
    );

    final snap = RoomCollectPostLimitSnapshot.compute(
      items: _items,
      events: _activityEventProvider.events,
      now: DateTime.now(),
    );
    showCollectPostSuccessCelebration(context, todayOrdinal: snap.todayCount);
    await AppActionService.openUrl(context, url: roomUrl);
    return true;
  }

  void _collectIssueDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿できません'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// 商品カードの「反応よかった」を ON/OFF。ON 時に活動ログへ1件追加。
  Future<String?> toggleFeedbackLiked(
    BuildContext context,
    String productId,
  ) async {
    return _toggleFeedback(context, productId, liked: true);
  }

  /// 「売れた」トグル。
  Future<String?> toggleFeedbackSold(
    BuildContext context,
    String productId,
  ) async {
    return _toggleFeedback(context, productId, sold: true);
  }

  /// 「微妙」トグル。
  Future<String?> toggleFeedbackWeak(
    BuildContext context,
    String productId,
  ) async {
    return _toggleFeedback(context, productId, weak: true);
  }

  Future<String?> _toggleFeedback(
    BuildContext context,
    String productId, {
    bool liked = false,
    bool sold = false,
    bool weak = false,
  }) async {
    final id = productId.trim();
    if (id.isEmpty) return '商品IDが空です';
    final p = _repository.getByProductId(id);
    if (p == null) return '商品が見つかりません';

    final blocked = _bulkBlocksMutation('toggleFeedback');
    if (blocked != null) {
      return blocked;
    }

    final now = DateTime.now();
    late final RakutenManagedProduct next;
    RoomActivityEventType? eventOnEnable;

    if (liked) {
      final on = p.feedbackLikedAt == null;
      next = on
          ? p.copyWith(feedbackLikedAt: now, updatedAt: now)
          : p.copyWith(clearFeedbackLiked: true, updatedAt: now);
      if (on) eventOnEnable = RoomActivityEventType.feedbackLiked;
    } else if (sold) {
      final on = p.feedbackSoldAt == null;
      next = on
          ? p.copyWith(feedbackSoldAt: now, updatedAt: now)
          : p.copyWith(clearFeedbackSold: true, updatedAt: now);
      if (on) eventOnEnable = RoomActivityEventType.feedbackSold;
    } else if (weak) {
      final on = p.feedbackWeakAt == null;
      next = on
          ? p.copyWith(feedbackWeakAt: now, updatedAt: now)
          : p.copyWith(clearFeedbackWeak: true, updatedAt: now);
      if (on) eventOnEnable = RoomActivityEventType.feedbackWeak;
    } else {
      return null;
    }

    try {
      await _repository.updateManagedProduct(id, (_) => next);
      if (eventOnEnable != null) {
        await _activityEventProvider.append(
          RoomActivityEvent(
            id: _newEventId(id, eventOnEnable),
            productId: id,
            type: eventOnEnable,
            createdAt: now,
          ),
        );
      }
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      notifyListeners();
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] _toggleFeedback failed: $e');
      }
      return '評価の更新に失敗しました';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RakutenManagedProduct] _toggleFeedback failed: $e');
      }
      return '評価の更新に失敗しました';
    }
    return null;
  }

  /// コレ候補を一覧から削除する。
  Future<String?> removeCandidate(
    BuildContext context,
    String productId,
  ) async {
    final id = productId.trim();
    if (id.isEmpty) return '商品IDが空です';
    final blocked = _bulkBlocksMutation('remove');
    if (blocked != null) {
      return blocked;
    }
    try {
      await _repository.removeCandidateProduct(id);
      try {
        await _activityEventProvider.append(
          RoomActivityEvent(
            id: _newEventId(id, RoomActivityEventType.deleted),
            productId: id,
            type: RoomActivityEventType.deleted,
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}
      _reloadFromStorage();
      _listUiStatus = RakutenManagedProductListUiStatus.ready;
      _listUiErrorMessage = null;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('候補から外しました')));
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
