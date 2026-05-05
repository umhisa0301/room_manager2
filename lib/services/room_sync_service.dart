import '../config/demo_mode.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/room_collected_persist_kind.dart';
import '../models/room_sync_result.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../utils/room_rakuten_url_normalize.dart';
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
    if (kDemoModeEnabled) {
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
    if (discovered.isEmpty) {
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
    for (final u in discovered) {
      if (toProcess.length >= maxItems) break;
      final k = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(u);
      if (_repository.isRoomProductPageKeySynced(k)) {
        continue;
      }
      toProcess.add(u);
    }

    if (toProcess.isEmpty) {
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
      onCheckingProgress?.call(i + 1, batchSize);

      final normalizedKey =
          RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomPageUrl);
      if (_repository.isRoomProductPageKeySynced(normalizedKey)) {
        skipped++;
        continue;
      }

      RoomUrlResolveOutcome resolved;
      try {
        resolved = await _resolver.resolveRakutenItemUrlFromRoomPage(
          roomPageUrl,
        );
      } catch (_) {
        failed++;
        failedUrls.add(roomPageUrl);
        continue;
      }

      if (resolved is! RoomUrlResolveSuccess) {
        failed++;
        failedUrls.add(roomPageUrl);
        continue;
      }

      final parsed = resolved.rakutenItem;
      if (RakutenItemUrlParser.tryParse(parsed.rakutenUrl) == null) {
        failed++;
        failedUrls.add(roomPageUrl);
        continue;
      }

      final apiItem = await _tryFetchRakutenItem(parsed);

      try {
        final outcome = await _repository.persistRoomCollectedFromRoomPage(
          roomUrlStoredCanonical: normalizedKey,
          normalizedRoomUrlKey: normalizedKey,
          parsedItem: parsed,
          roomPageTitle: resolved.roomPageTitle ?? '',
          roomPageImageUrl: resolved.roomPageImageUrl ?? '',
          apiEnrichedItem: apiItem,
        );

        final k = outcome.kind;
        if (k == RoomCollectedPersistKind.demoUnsupported) {
          failed++;
          failedUrls.add(roomPageUrl);
        } else if (k == RoomCollectedPersistKind.roomPageAlreadySynced ||
            k == RoomCollectedPersistKind.alreadyCollectedSkip) {
          skipped++;
        } else if (k == RoomCollectedPersistKind.updatedRoomUrlOnly) {
          roomAdd++;
        } else if (k == RoomCollectedPersistKind.insertedNewCollected) {
          newly++;
        }
      } catch (_) {
        failed++;
        failedUrls.add(roomPageUrl);
      }
    }

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
    } catch (_) {
      return null;
    }
  }
}
