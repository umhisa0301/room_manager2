import 'package:flutter/foundation.dart';

import '../config/demo_mode.dart';
import '../models/room_collected_persist_kind.dart';
import '../models/room_sync_result.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_item_url_parser.dart';
import 'room_url_resolver.dart';
import 'room_user_posted_listing_fetcher.dart';

/// ROOM プロフィール起点の投稿商品を、管理アプリのコレ済データへ **バッチ同期** する。
///
/// - 一覧取得・roomUrl 事前照合・ROOM 商品ページ解析・楽天URL抽出・DB更新をまとめる。
/// - 単品登録は既存 [RoomCollectedRegisterService] 経由の [persistRoomCollectedFromRoomPage] を再利用。
///
/// 楽天 IchibaItem/Search は **itemCode 単体検索非対応**のため、ROOM同期では API での詳細取得は行わない。
// TODO: 必要であれば商品詳細はスクレイピング or 別APIで補完
class RoomSyncService {
  RoomSyncService({
    required RakutenManagedProductRepository repository,
    RoomUrlResolver? roomUrlResolver,
    RoomUserPostedListingFetcher? listingFetcher,
  }) : _repository = repository,
       _resolver = roomUrlResolver ?? RoomUrlResolver(),
       _listingFetcher = listingFetcher ?? RoomUserPostedListingFetcher();

  final RakutenManagedProductRepository _repository;
  final RoomUrlResolver _resolver;
  final RoomUserPostedListingFetcher _listingFetcher;

  static const int defaultMaxBatch = 10;
  static const int _collectsApiPageLimit = 20;
  static const int _maxCollectsApiPages = 40;

  /// 未同期の ROOM 商品を最大 [maxItems] 件処理する。
  Future<RoomSyncResult> syncPostedRoomProducts({
    required String userRoomProfileUrl,
    int maxItems = defaultMaxBatch,
    void Function(int currentIndex, int batchSize)? onCheckingProgress,
  }) async {
    roomSyncLog('START');
    roomSyncLog('登録済みユーザーROOM URL: $userRoomProfileUrl');
    roomSyncLog('今回の最大処理件数: $maxItems');

    if (kDemoModeEnabled) {
      roomSyncWarn('デモモードのため中断（fatal 相当）');
      roomSyncLog('FINISH (demo) processedChecked=0 queued=0 newly=0 roomAdd=0 skip=0 fail=0');
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        fatalErrorMessage: 'デモモードではROOM同期を実行できません',
      );
    }

    final profile = userRoomProfileUrl.trim();
    if (profile.isEmpty) {
      roomSyncWarn('ROOM URL 空のため中断');
      roomSyncLog('FINISH (empty profile)');
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        fatalErrorMessage: 'ROOM URLが未登録です',
      );
    }

    String? listingHtml;
    final initialOrdered = await _listingFetcher.fetchPostedRoomProductPageUrls(
      profile,
      onListingHtml: (h) => listingHtml = h,
    );
    roomSyncLog('一覧HTMLから得られたROOM商品URL総数（未同期フィルタ前）: ${initialOrdered.length}');

    final listingInitialCandidateCount = initialOrdered.length;

    if (initialOrdered.isEmpty) {
      roomSyncError(
        'ROOMの投稿一覧を取得できませんでした（抽出0件または接続失敗）。',
      );
      roomSyncLog(
        'FINISH (fatal listing) processedChecked=0 queued=0 newly=0 roomAdd=0 skip=0 fail=0',
      );
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        fatalErrorMessage: 'ROOMの投稿一覧を取得できませんでした。URLを確認するか、しばらくしてからもう一度お試しください',
      );
    }

    roomSyncLog('初期HTML候補数: $listingInitialCandidateCount');
    final initialUnsynced = initialOrdered
        .where(
          (k) => !_repository.isRoomProductPageKeySynced(k),
        )
        .length;
    roomSyncLog('初期HTML未同期候補数: $initialUnsynced');

    final userSeg = _roomUserSegment(profile);
    final orderedKeys = List<String>.from(initialOrdered);
    final seenKeys = orderedKeys.toSet();
    var discoveryIdx = 0;
    var listingChecked = 0;
    var listingSkip = 0;
    final toProcess = <String>[];

    void advanceQueueFromDiscovery() {
      while (toProcess.length < maxItems && discoveryIdx < orderedKeys.length) {
        final k = orderedKeys[discoveryIdx++];
        listingChecked++;
        if (_repository.isRoomProductPageKeySynced(k)) {
          listingSkip++;
        } else {
          toProcess.add(k);
        }
      }
    }

    advanceQueueFromDiscovery();

    var additionalFetchStatus = '不要';
    if (toProcess.length < maxItems) {
      final allInitialSynced = initialOrdered.isNotEmpty &&
          initialOrdered.every(_repository.isRoomProductPageKeySynced);
      if (allInitialSynced) {
        roomSyncLog('初期HTML候補がすべて同期済みのため追加取得を試行します');
      }

      var numericUserId = listingHtml == null
          ? null
          : RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
              listingHtml!,
            );
      if (numericUserId == null || numericUserId.isEmpty) {
        final itemsUri = _itemsListingUri(profile);
        if (itemsUri != null && itemsUri != Uri.parse(profile)) {
          roomSyncLog('userData.id 未取得のため /items へ再GETして再試行: $itemsUri');
          final h = await _listingFetcher.fetchListingHtmlBody(itemsUri.toString());
          if (h != null) {
            RoomUserPostedListingFetcher.logListingHtmlInvestigation(h);
            numericUserId =
                RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                  h,
                );
          }
        }
      }

      if (numericUserId == null || numericUserId.isEmpty || userSeg.isEmpty) {
        additionalFetchStatus = '未対応（WebView fallback 候補）';
        roomSyncLog('追加取得方式: 未対応（API用 userData.id 未取得またはユーザーセグメント空）');
      } else {
        roomSyncLog('追加取得方式: API');
        additionalFetchStatus = '実行済み(API)';
        String? cursor;
        for (var pageIdx = 0;
            pageIdx < _maxCollectsApiPages && toProcess.length < maxItems;
            pageIdx++) {
          roomSyncLog(
            '追加取得 page/cursor: ${cursor ?? '(先頭ページ)'}',
          );
          final page = await _listingFetcher.fetchCollectsApiPage(
            numericUserId: numericUserId,
            roomUserSegment: userSeg,
            afterId: cursor,
            limit: _collectsApiPageLimit,
          );
          if (page == null) {
            additionalFetchStatus = '失敗(API)';
            roomSyncWarn('追加取得 collects API が失敗したため打ち切り');
            break;
          }

          roomSyncLog('追加取得候補数: ${page.roomPageKeysOrdered.length}');
          var appended = 0;
          for (final k in page.roomPageKeysOrdered) {
            if (seenKeys.contains(k)) continue;
            seenKeys.add(k);
            orderedKeys.add(k);
            appended++;
          }
          advanceQueueFromDiscovery();

          final unsyncedAmongDiscovered = orderedKeys
              .where((k) => !_repository.isRoomProductPageKeySynced(k))
              .length;
          roomSyncLog('追加取得後の未同期候補数: $unsyncedAmongDiscovered');

          cursor = page.nextAfterId;
          if (cursor == null ||
              cursor.isEmpty ||
              page.rawItemCount == 0) {
            break;
          }
          if (appended == 0 && toProcess.length < maxItems) {
            // 重複のみのページが返る場合もあるためカーソルで先へ進む。
            continue;
          }
        }
      }
    } else {
      roomSyncLog('追加取得方式: 不要（初期候補でキュー充足見込み）');
    }

    roomSyncLog('同期対象キュー件数: ${toProcess.length}');

    if (toProcess.isEmpty) {
      roomSyncLog(
        '処理キューが空（一覧上は最大限走査、またはすべて同期済み）',
      );
      roomSyncLog(
        'FINISH processedChecked=$listingChecked queued=0 newly=0 roomAdd=0 skip=$listingSkip fail=0',
      );
      return RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        listingCheckedCount: listingChecked,
        listingSyncedSkipCount: listingSkip,
        listingInitialCandidateCount: listingInitialCandidateCount,
        additionalFetchStatusLabel: additionalFetchStatus,
      );
    }

    var newly = 0;
    var roomAdd = 0;
    var skipped = 0;
    var failed = 0;
    final failedUrls = <String>[];

    final batchSize = toProcess.length;
    onCheckingProgress?.call(0, batchSize);
    for (var i = 0; i < toProcess.length; i++) {
      final roomPageUrl = toProcess[i];
      final ordinal = i + 1;
      roomSyncLog('$ordinal件目の商品を確認');
      roomSyncLog('roomUrl: $roomPageUrl');
      onCheckingProgress?.call(i + 1, batchSize);

      final normalizedKey =
          RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomPageUrl);
      final preSynced = _repository.isRoomProductPageKeySynced(normalizedKey);
      roomSyncLog('同期済み判定（再確認）: $preSynced');
      if (preSynced) {
        roomSyncLog('同期済みのためスキップ: $roomPageUrl');
        skipped++;
        continue;
      }

      RoomUrlResolveOutcome resolved;
      try {
        resolved = await _resolver.resolveRakutenItemUrlFromRoomPage(
          roomPageUrl,
          traceRoomSync: kDebugMode,
        );
      } catch (e, st) {
        roomSyncError('ROOM商品ページ解決で例外', e, st);
        failed++;
        failedUrls.add(roomPageUrl);
        continue;
      }

      if (resolved is! RoomUrlResolveSuccess) {
        final f = resolved as RoomUrlResolveFailure;
        roomSyncWarn(
          'ROOM商品ページから楽天URL解決失敗 kind=${f.kind} detail=${f.debugDetail ?? '-'}',
        );
        failed++;
        failedUrls.add(roomPageUrl);
        continue;
      }

      final parsed = resolved.rakutenItem;
      roomSyncLog('楽天URL解析開始: ${parsed.rakutenUrl}');
      roomSyncLog(
        '使用した正規表現: ${RakutenItemUrlParser.itemRakutenUrlPattern.pattern}',
      );
      final verified = RakutenItemUrlParser.tryParse(parsed.rakutenUrl);
      if (verified == null) {
        roomSyncError('shopCode / itemCode の抽出に失敗');
        roomSyncLog('対象URL: ${parsed.rakutenUrl}');
        roomSyncLog(
          '使用した正規表現: ${RakutenItemUrlParser.itemRakutenUrlPattern.pattern}',
        );
        failed++;
        failedUrls.add(roomPageUrl);
        continue;
      }
      roomSyncLog('shopCode: ${verified.shopCode}');
      roomSyncLog('itemCode: ${verified.itemPathSegment}');

      roomSyncLog('APIスキップ（仕様により）');
      roomSyncLog('最低限データで保存');

      try {
        final outcome = await _repository.persistRoomCollectedFromRoomPage(
          roomUrlStoredCanonical: normalizedKey,
          normalizedRoomUrlKey: normalizedKey,
          parsedItem: parsed,
          roomPageTitle: resolved.roomPageTitle ?? '',
          roomPageImageUrl: resolved.roomPageImageUrl ?? '',
          traceRoomSync: kDebugMode,
        );

        final k = outcome.kind;
        if (k == RoomCollectedPersistKind.demoUnsupported) {
          roomSyncWarn('保存種別: デモ拒否');
          failed++;
          failedUrls.add(roomPageUrl);
        } else if (k == RoomCollectedPersistKind.roomPageAlreadySynced ||
            k == RoomCollectedPersistKind.alreadyCollectedSkip) {
          roomSyncLog('保存種別: スキップ (${k.name})');
          skipped++;
        } else if (k == RoomCollectedPersistKind.updatedRoomUrlOnly) {
          roomSyncLog('保存種別: 既存商品へROOM URL追加 完了');
          roomAdd++;
        } else if (k == RoomCollectedPersistKind.insertedNewCollected) {
          roomSyncLog('保存種別: 新規コレ済登録 完了');
          newly++;
        }
      } catch (e, st) {
        roomSyncError('永続化例外（persistRoomCollectedFromRoomPage）', e, st);
        failed++;
        failedUrls.add(roomPageUrl);
      }
    }

    roomSyncLog('FINISH');
    roomSyncLog('処理対象: $batchSize');
    roomSyncLog('新規登録: $newly');
    roomSyncLog('ROOM URL追加: $roomAdd');
    roomSyncLog('同期済みスキップ: $skipped');
    roomSyncLog('取得失敗: $failed');
    roomSyncLog('failedRoomUrls: $failedUrls');
    roomSyncLog(
      'FINISH processedChecked=$listingChecked queued=$batchSize newly=$newly roomAdd=$roomAdd skip=$listingSkip fail=$failed',
    );

    return RoomSyncResult(
      processedCount: batchSize,
      newlyCollectedCount: newly,
      roomUrlAddedCount: roomAdd,
      skippedCount: skipped,
      failedCount: failed,
      failedRoomUrls: failedUrls,
      listingCheckedCount: listingChecked,
      listingSyncedSkipCount: listingSkip,
      listingInitialCandidateCount: listingInitialCandidateCount,
      additionalFetchStatusLabel: additionalFetchStatus,
    );
  }

  static String _roomUserSegment(String profile) {
    try {
      final u = Uri.parse(profile.trim());
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      return segs.isEmpty ? '' : segs.first;
    } catch (_) {
      return '';
    }
  }

  /// プロフィール URL を `/items` 付きの一覧 URL に揃える（同一なら null）。
  static Uri? _itemsListingUri(String profile) {
    try {
      final u = Uri.parse(profile.trim());
      if (!u.hasScheme || u.host.isEmpty) return null;
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length >= 2 && segs.last == 'items') {
        return null;
      }
      final trimmed =
          u.path.isEmpty ? '' : u.path.replaceAll(RegExp(r'/+$'), '');
      final newPath = '${trimmed.isEmpty ? '' : trimmed}/items';
      return u.replace(path: newPath.startsWith('/') ? newPath : '/$newPath');
    } catch (_) {
      return null;
    }
  }
}
