import 'package:flutter/foundation.dart';

import '../config/demo_mode.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/room_collected_persist_kind.dart';
import '../models/room_sync_result.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_item_url_parser.dart';
import 'room_url_resolver.dart';
import 'room_user_posted_listing_fetcher.dart';

/// ROOM プロフィール起点の投稿商品を、管理アプリのコレ済データへ **バッチ同期** する。
///
/// - 一覧取得・roomUrl 事前照合・ROOM 商品ページ解析・楽天URL抽出・DB更新をまとめる。
/// - 単品登録は既存 [RoomCollectedRegisterService] 経由の [persistRoomCollectedFromRoomPage] を再利用。
class RoomSyncService {
  RoomSyncService({
    required RakutenManagedProductRepository repository,
    required RakutenSearchRepository searchRepository,
    RoomUrlResolver? roomUrlResolver,
    RoomUserPostedListingFetcher? listingFetcher,
  }) : _repository = repository,
       _searchRepository = searchRepository,
       _resolver = roomUrlResolver ?? RoomUrlResolver(),
       _listingFetcher = listingFetcher ?? RoomUserPostedListingFetcher();

  final RakutenManagedProductRepository _repository;
  final RakutenSearchRepository _searchRepository;
  final RoomUrlResolver _resolver;
  final RoomUserPostedListingFetcher _listingFetcher;

  static const int defaultMaxBatch = 10;

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
      roomSyncLog('FINISH (demo) processed=0');
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

    final discovered = await _listingFetcher.fetchPostedRoomProductPageUrls(
      profile,
    );
    roomSyncLog('一覧HTMLから得られたROOM商品URL総数（未同期フィルタ前）: ${discovered.length}');

    if (discovered.isEmpty) {
      roomSyncError(
        'ROOMの投稿一覧を取得できませんでした（抽出0件または接続失敗）。',
      );
      roomSyncLog(
        'FINISH (fatal listing) newly=0 roomAdd=0 skip=0 fail=0 processed=0',
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

    final toProcess = <String>[];
    roomSyncLog('未同期ROOM商品の選別（最大$maxItems件までキュー）');
    for (final u in discovered) {
      if (toProcess.length >= maxItems) break;
      final k = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(u);
      final synced = _repository.isRoomProductPageKeySynced(k);
      roomSyncLog('roomUrl: $u');
      roomSyncLog('同期済み判定（DB）: $synced');
      if (synced) {
        roomSyncLog('同期済みのためスキップ（一覧段階）: $u');
        continue;
      }
      toProcess.add(u);
    }

    if (toProcess.isEmpty) {
      roomSyncLog(
        '処理キューが空（すべて同期済み、または件数制限前に該当なし）',
      );
      roomSyncLog('FINISH processed=0 newly=0 roomAdd=0 skip=0 fail=0');
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
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

      roomSyncLog('楽天API商品詳細取得開始');
      roomSyncLog('shopCode: ${parsed.shopCode}');
      roomSyncLog('itemCode: ${parsed.itemPathSegment}');
      final apiItem = await _tryFetchRakutenItem(parsed);
      if (apiItem != null) {
        roomSyncLog('API取得成功: 商品名 ${apiItem.itemName}');
      } else {
        roomSyncWarn('API取得失敗または0件');
        roomSyncLog('最低限データで保存します');
      }

      try {
        final outcome = await _repository.persistRoomCollectedFromRoomPage(
          roomUrlStoredCanonical: normalizedKey,
          normalizedRoomUrlKey: normalizedKey,
          parsedItem: parsed,
          roomPageTitle: resolved.roomPageTitle ?? '',
          roomPageImageUrl: resolved.roomPageImageUrl ?? '',
          apiEnrichedItem: apiItem,
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

    return RoomSyncResult(
      processedCount: batchSize,
      newlyCollectedCount: newly,
      roomUrlAddedCount: roomAdd,
      skippedCount: skipped,
      failedCount: failed,
      failedRoomUrls: failedUrls,
    );
  }

  Future<RakutenSearchItem?> _tryFetchRakutenItem(
    RakutenItemUrlParseResult parsed,
  ) async {
    final wantSc = parsed.shopCode.trim();
    final wantSeg = parsed.itemPathSegment.trim();
    if (wantSc.isEmpty || wantSeg.isEmpty) return null;
    try {
      final items = await _searchRepository.search(
        condition: RakutenProductSearchCondition(
          shopCode: wantSc,
          itemCode: wantSeg,
        ),
      );
      for (final it in items) {
        if (it.shopCode.trim() == wantSc && it.productId.trim() == wantSeg) {
          return it;
        }
      }
      return items.isNotEmpty ? items.first : null;
    } catch (e, st) {
      roomSyncError('楽天API search 例外', e, st);
      return null;
    }
  }
}
