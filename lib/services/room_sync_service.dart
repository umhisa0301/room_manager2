import '../config/demo_mode.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_collected_persist_kind.dart';
import '../models/room_sync_result.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_item_url_parser.dart';
import 'room_import_limit_policy.dart';
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

  static const int defaultMaxBatch = RoomImportLimitPolicy.freeBatchLimit;
  static const int _collectsApiPageLimit = 20;
  static const int _maxCollectsApiPages = 40;

  static bool _postedRoomImportInFlight = false;

  /// 未同期の ROOM 商品を最大 [maxItems] 件処理する。
  Future<RoomSyncResult?> syncPostedRoomProducts({
    required String userRoomProfileUrl,
    int maxItems = defaultMaxBatch,
    void Function(int currentIndex, int batchSize)? onCheckingProgress,
    void Function(String hint)? onProcessingHint,
  }) async {
    if (_postedRoomImportInFlight) {
      roomSyncSummaryLog(
        'ROOM投稿取り込み 実行中のためスキップ（二重起動防止）',
      );
      return null;
    }
    _postedRoomImportInFlight = true;
    try {
    roomSyncSummaryLog('ROOM投稿取り込み 開始（最大$maxItems件）');

    if (kDemoModeEnabled) {
      roomSyncWarn('デモモードのため中断（fatal 相当）');
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        fatalErrorMessage: 'デモモードではROOM投稿取り込みを実行できません',
      );
    }

    final profile = userRoomProfileUrl.trim();
    if (profile.isEmpty) {
      roomSyncWarn('ROOM URL 空のため中断');
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        fatalErrorMessage:
            'マイページで楽天ROOMのプロフィールURLを登録してください',
      );
    }

    String? listingHtml;
    final initialOrdered = await _listingFetcher.fetchPostedRoomProductPageUrls(
      profile,
      onListingHtml: (h) => listingHtml = h,
    );
    roomSyncVerboseLog(
      '一覧HTMLから得られたROOM商品URL総数（未取り込みフィルタ前）: ${initialOrdered.length}',
    );

    final listingInitialCandidateCount = initialOrdered.length;

    if (initialOrdered.isEmpty) {
      roomSyncError(
        'ROOMの投稿一覧を取得できませんでした（抽出0件または接続失敗）。',
      );
      return const RoomSyncResult(
        processedCount: 0,
        newlyCollectedCount: 0,
        roomUrlAddedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        fatalErrorMessage:
            'ROOMの投稿一覧を取得できませんでした。URLを確認するか、しばらくしてからもう一度お試しください',
      );
    }

    /// ROOM同期バッチ中は共有し、[persistRoomCollectedFromRoomPage] に渡して再読込を避ける。
    final workingManagedList =
        List<RakutenManagedProduct>.from(_repository.loadAll());
    final syncedRoomKeys =
        RakutenManagedProductRepository.normalizedRoomProductUrlKeys(
          workingManagedList,
        );

    final initialUnsynced =
        initialOrdered.where((k) => !syncedRoomKeys.contains(k)).length;
    roomSyncSummaryLog(
      '投稿一覧 ${initialOrdered.length}件 · 未取り込み推定 $initialUnsynced件',
    );

    roomSyncVerboseLog('初期HTML候補数: $listingInitialCandidateCount');
    roomSyncVerboseLog('初期HTML未取り込み候補数: $initialUnsynced');

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
        if (syncedRoomKeys.contains(k)) {
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
          initialOrdered.every(syncedRoomKeys.contains);
      if (allInitialSynced) {
        roomSyncVerboseLog('初期HTML候補がすべて取り込み済みのため追加取得を試行します');
      }

      var numericUserId = listingHtml == null
          ? null
          : RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
              listingHtml!,
            );
      if (numericUserId == null || numericUserId.isEmpty) {
        final itemsUri = _itemsListingUri(profile);
        if (itemsUri != null && itemsUri != Uri.parse(profile)) {
          roomSyncVerboseLog(
            'userData.id 未取得のため /items へ再GETして再試行: $itemsUri',
          );
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
        roomSyncVerboseLog(
          '追加取得方式: 未対応（API用 userData.id 未取得またはユーザーセグメント空）',
        );
      } else {
        roomSyncVerboseLog('追加取得方式: API');
        additionalFetchStatus = '実行済み(API)';
        String? cursor;
        for (var pageIdx = 0;
            pageIdx < _maxCollectsApiPages && toProcess.length < maxItems;
            pageIdx++) {
          roomSyncVerboseLog(
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

          roomSyncVerboseLog('追加取得候補数: ${page.roomPageKeysOrdered.length}');
          var appended = 0;
          for (final k in page.roomPageKeysOrdered) {
            if (seenKeys.contains(k)) continue;
            seenKeys.add(k);
            orderedKeys.add(k);
            appended++;
          }
          advanceQueueFromDiscovery();

          final unsyncedAmongDiscovered =
              orderedKeys.where((k) => !syncedRoomKeys.contains(k)).length;
          roomSyncVerboseLog('追加取得後の未取り込み候補数: $unsyncedAmongDiscovered');

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
      roomSyncVerboseLog('追加取得方式: 不要（初期候補でキュー充足見込み）');
    }

    roomSyncVerboseLog('取り込み対象キュー件数: ${toProcess.length}');

    if (toProcess.isEmpty) {
      roomSyncSummaryLog(
        '完了 · キューなし（一覧確認 $listingChecked件 · リスト側スキップ $listingSkip件）',
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
    final newlyCollectedSamples = <RakutenManagedProduct>[];
    final reactionHitsByPid = <String, RakutenManagedProduct>{};
    final reactionHitOrdinal = <String, int>{};
    var reactionOrdinalSeq = 0;

    final batchSize = toProcess.length;
    final traceDetailed = debugVerboseRoomImport;
    onCheckingProgress?.call(0, batchSize);

    for (var i = 0; i < toProcess.length; i++) {
      final roomPageUrl = toProcess[i];
      final ordinal = i + 1;
      roomSyncVerboseLog('$ordinal件目の商品を確認');
      roomSyncVerboseLog('roomUrl: $roomPageUrl');

      final normalizedKey =
          RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomPageUrl);
      final preSynced = syncedRoomKeys.contains(normalizedKey);
      roomSyncVerboseLog('取り込み済み判定（再確認）: $preSynced');
      if (preSynced) {
        roomSyncVerboseLog('取り込み済みのためスキップ: $roomPageUrl');
        skipped++;
        onCheckingProgress?.call(i + 1, batchSize);
        continue;
      }

      RoomUrlResolveOutcome resolved;
      try {
        resolved = await _resolver.resolveRakutenItemUrlFromRoomPage(
          roomPageUrl,
          traceRoomSync: traceDetailed,
        );
      } catch (e, st) {
        roomSyncError('ROOM商品ページ解決で例外', e, st);
        failed++;
        failedUrls.add(roomPageUrl);
        onCheckingProgress?.call(i + 1, batchSize);
        continue;
      }

      if (resolved is! RoomUrlResolveSuccess) {
        final f = resolved as RoomUrlResolveFailure;
        roomSyncWarn(
          'ROOM商品ページから楽天URL解決失敗 kind=${f.kind} detail=${f.debugDetail ?? '-'}',
        );
        failed++;
        failedUrls.add(roomPageUrl);
        onCheckingProgress?.call(i + 1, batchSize);
        continue;
      }

      final parsed = resolved.rakutenItem;
      roomSyncVerboseLog('楽天URL解析開始: ${parsed.rakutenUrl}');
      roomSyncVerboseLog(
        '使用した正規表現: ${RakutenItemUrlParser.itemRakutenUrlPattern.pattern}',
      );
      final verified = RakutenItemUrlParser.tryParse(parsed.rakutenUrl);
      if (verified == null) {
        roomSyncError('shopCode / itemCode の抽出に失敗');
        roomSyncVerboseLog('対象URL: ${parsed.rakutenUrl}');
        roomSyncVerboseLog(
          '使用した正規表現: ${RakutenItemUrlParser.itemRakutenUrlPattern.pattern}',
        );
        failed++;
        failedUrls.add(roomPageUrl);
        onCheckingProgress?.call(i + 1, batchSize);
        continue;
      }
      roomSyncVerboseLog('shopCode: ${verified.shopCode}');
      roomSyncVerboseLog('itemCode: ${verified.itemPathSegment}');

      roomSyncVerboseLog('APIスキップ（仕様により）');
      roomSyncVerboseLog('最低限データで保存');

      try {
        final outcome = await _repository.persistRoomCollectedFromRoomPage(
          roomUrlStoredCanonical: normalizedKey,
          normalizedRoomUrlKey: normalizedKey,
          parsedItem: parsed,
          roomPageTitle: resolved.roomPageTitle ?? '',
          roomPageImageUrl: resolved.roomPageImageUrl ?? '',
          traceRoomSync: traceDetailed,
          workingMutableList: workingManagedList,
          roomLikeCount: resolved.roomLikeCount,
          roomCommentCount: resolved.roomCommentCount,
        );

        final k = outcome.kind;
        if (k == RoomCollectedPersistKind.demoUnsupported) {
          roomSyncWarn('保存種別: デモ拒否');
          failed++;
          failedUrls.add(roomPageUrl);
        } else if (k == RoomCollectedPersistKind.roomPageAlreadySynced ||
            k == RoomCollectedPersistKind.alreadyCollectedSkip) {
          roomSyncVerboseLog('保存種別: スキップ (${k.name})');
          skipped++;
        } else if (k == RoomCollectedPersistKind.updatedRoomUrlOnly) {
          roomSyncVerboseLog('保存種別: 既存商品へROOM URL追加 完了');
          roomAdd++;
        } else if (k == RoomCollectedPersistKind.insertedNewCollected) {
          roomSyncVerboseLog('保存種別: 新規コレ済登録 完了');
          newly++;
          if (newlyCollectedSamples.length < 3) {
            final pid = outcome.productId?.trim() ?? '';
            if (pid.isNotEmpty) {
              for (final row in workingManagedList) {
                if (row.productId.trim() == pid) {
                  newlyCollectedSamples.add(row);
                  break;
                }
              }
            }
          }
        }
        if (k != RoomCollectedPersistKind.demoUnsupported) {
          final pid = outcome.productId?.trim() ?? '';
          if (pid.isNotEmpty) {
            RakutenManagedProduct? hitRow;
            for (final row in workingManagedList) {
              if (row.productId.trim() == pid) {
                hitRow = row;
                break;
              }
            }
            if (hitRow != null) {
              final lc = hitRow.roomLikeCount;
              final cc = hitRow.roomCommentCount;
              if ((lc != null && lc > 0) || (cc != null && cc > 0)) {
                reactionHitsByPid[pid] = hitRow;
                reactionHitOrdinal.putIfAbsent(pid, () => reactionOrdinalSeq++);
              }
            }
          }
        }
        if (k == RoomCollectedPersistKind.updatedRoomUrlOnly ||
            k == RoomCollectedPersistKind.insertedNewCollected) {
          syncedRoomKeys.add(normalizedKey);
        }
      } catch (e, st) {
        roomSyncError('永続化例外（persistRoomCollectedFromRoomPage）', e, st);
        failed++;
        failedUrls.add(roomPageUrl);
      }

      onCheckingProgress?.call(i + 1, batchSize);
    }

    roomSyncSummaryLog(
      '完了 · 確認キュー $batchSize件 · 新規コレ済$newly · ROOMリンク追加$roomAdd · '
      'ページ側スキップ$skipped · 失敗$failed · 一覧スキップ$listingSkip',
    );
    if (failedUrls.isNotEmpty) {
      roomSyncVerboseLog('failedRoomUrls: $failedUrls');
    }

    final highlightKeys = reactionHitsByPid.keys.toList();
    highlightKeys.sort((a, b) {
      final pa = reactionHitsByPid[a]!;
      final pb = reactionHitsByPid[b]!;
      final ca = pa.roomCommentCount ?? -1;
      final cb = pb.roomCommentCount ?? -1;
      if (cb != ca) return cb.compareTo(ca);
      final la = pa.roomLikeCount ?? -1;
      final lb = pb.roomLikeCount ?? -1;
      if (lb != la) return lb.compareTo(la);
      return (reactionHitOrdinal[a] ?? 0).compareTo(reactionHitOrdinal[b] ?? 0);
    });
    final reactionHighlightSamples = highlightKeys
        .take(3)
        .map((k) => reactionHitsByPid[k]!)
        .toList(growable: false);

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
      newlyCollectedSamples:
          List<RakutenManagedProduct>.unmodifiable(newlyCollectedSamples),
      reactionHighlightSamples:
          List<RakutenManagedProduct>.unmodifiable(reactionHighlightSamples),
    );
    } finally {
      _postedRoomImportInFlight = false;
    }
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
