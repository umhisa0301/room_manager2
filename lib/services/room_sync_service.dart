import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/demo_mode.dart';
import '../models/catalog_product.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_collected_persist_kind.dart';
import '../models/room_import_cursor_state.dart';
import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_reaction_sync_top_product.dart';
import '../models/room_sync_result.dart';
import '../models/rakuten_search_item.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/room_sync_cursor_repository.dart';
import '../utils/catalog_product_mapper.dart';
import '../utils/room_catalog_enrichment.dart';
import '../utils/room_import_product_image.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_reaction_sync_user_message.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_item_url_parser.dart';
import 'room_import_collects_policy.dart';
import 'room_import_collects_resume_store.dart';
import 'room_import_limit_policy.dart';
import 'room_profile_url_validation_service.dart';
import 'room_url_resolver.dart';
import 'room_user_posted_listing_fetcher.dart';

/// ROOM プロフィール起点の投稿商品を、管理アプリのコレ済データへ **バッチ同期** する。
///
/// - 一覧取得・roomUrl 事前照合・ROOM 商品ページ解析・楽天URL抽出・DB更新をまとめる。
/// - 単品登録は既存 [RoomCollectedRegisterService] 経由の [persistRoomCollectedFromRoomPage] を再利用。
///
/// 取り込み時は **商品画像のみ** 楽天APIで即時確認する（shopCode+itemCode がある場合）。
/// 価格・ジャンル等のその他メタは [RoomImportMetadataEnrichmentService] の後段キュー。
class RoomSyncService {
  RoomSyncService({
    required RakutenManagedProductRepository repository,
    RakutenSearchRepository? searchRepository,
    ProductCatalogRepository? productCatalogRepository,
    RoomUrlResolver? roomUrlResolver,
    RoomUserPostedListingFetcher? listingFetcher,
    RoomSyncCursorRepository? roomSyncCursorRepository,
  }) : _repository = repository,
       _searchRepository = searchRepository,
       _productCatalogRepository = productCatalogRepository,
       _resolver = roomUrlResolver ?? RoomUrlResolver(),
       _listingFetcher = listingFetcher ?? RoomUserPostedListingFetcher(),
       _cursorRepo = roomSyncCursorRepository;

  final RakutenManagedProductRepository _repository;
  final RakutenSearchRepository? _searchRepository;
  final ProductCatalogRepository? _productCatalogRepository;
  final RoomUrlResolver _resolver;
  final RoomUserPostedListingFetcher _listingFetcher;
  final RoomSyncCursorRepository? _cursorRepo;

  static const int defaultMaxBatch = RoomImportLimitPolicy.freeBatchLimit;
  static const int _collectsApiPageLimit = 20;

  static bool _postedRoomImportInFlight = false;
  static bool _postedRoomReactionSyncInFlight = false;

  /// 未同期の ROOM 商品を最大 [maxItems] 件処理する。
  Future<RoomSyncResult?> syncPostedRoomProducts({
    required String userRoomProfileUrl,
    int maxItems = defaultMaxBatch,
    void Function(int currentIndex, int batchSize)? onCheckingProgress,
    void Function(String hint)? onProcessingHint,
    RoomImportCollectsExploreMode collectsExploreMode =
        RoomImportCollectsExploreMode.normal,
  }) async {
    if (_postedRoomImportInFlight) {
      roomSyncSummaryLog('ROOM投稿取り込み 実行中のためスキップ（二重起動防止）');
      return null;
    }
    _postedRoomImportInFlight = true;
    final totalSw = Stopwatch()..start();
    try {
      if (kDebugMode) {
        RoomImportDebugLogBuffer.clear();
      }
      roomSyncSummaryLog('ROOM投稿取り込み 開始（最大$maxItems件）');
      roomImportPerfLog('totalStart');
      roomImportPerfLog('prepareStart');
      onProcessingHint?.call('ROOM投稿を確認しています');
      roomImportUiLog('phase=preparing message=ROOM投稿を確認しています');

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

      final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
        userRoomProfileUrl,
      );
      if (profile.isEmpty) {
        roomSyncWarn('ROOM URL 空のため中断');
        return const RoomSyncResult(
          processedCount: 0,
          newlyCollectedCount: 0,
          roomUrlAddedCount: 0,
          skippedCount: 0,
          failedCount: 0,
          fatalErrorMessage: 'マイページで楽天ROOMのプロフィールURLを登録してください',
        );
      }

      final userSeg = _roomUserSegment(profile);
      final listingFastPath = <String, RoomUrlResolveSuccess>{};
      final metadataSourceByRoomKey = <String, String>{};
      String? listingHtml;
      final listingUrl = RoomProfileUrlValidationService.buildItemsUrl(profile);
      if (listingUrl.isEmpty) {
        roomSyncWarn('ROOM URL 正規化後の /items URL 生成に失敗');
        return const RoomSyncResult(
          processedCount: 0,
          newlyCollectedCount: 0,
          roomUrlAddedCount: 0,
          skippedCount: 0,
          failedCount: 0,
          fatalErrorMessage: 'ROOMの投稿一覧URLを作成できませんでした。URLを確認してください',
        );
      }
      roomSyncLog('ROOMプロフィールURL（保存値）: $profile');
      roomSyncLog('ROOM投稿一覧URL（取得用）: $listingUrl');
      roomImportPerfLog('fetchRoomListStart url=$listingUrl');
      final prepareSw = Stopwatch()..start();
      final swRoomListHtml = Stopwatch()..start();
      List<String> initialOrdered = const [];
      var importSourcePrimary = 'collects';
      var pcHtmlSkipped = false;
      var sourceDecisionReason = 'normalImportUsesCollects';
      var usedFullListingHtmlForPrepare = false;
      var postedUrlListFetchCount = 0;

      if (debugVerboseRoomImport) {
        importSourcePrimary = 'pcHtml';
        pcHtmlSkipped = false;
        sourceDecisionReason = 'debugFallback';
        usedFullListingHtmlForPrepare = true;
        roomImportListingLog('source=html page=1 url=$listingUrl reason=debugVerboseRoomImport');
        initialOrdered = await _listingFetcher.fetchPostedRoomProductPageUrls(
          listingUrl,
          onListingHtml: (h) => listingHtml = h,
        );
        postedUrlListFetchCount = 1;
        swRoomListHtml.stop();
        if (listingHtml != null) {
          final nid =
              RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                listingHtml!,
              );
          if (nid != null && nid.isNotEmpty) {
            await RoomImportCollectsResumeStore.saveNumericUserId(profile, nid);
          }
        }
      } else {
        final cached = await RoomImportCollectsResumeStore.readNumericUserId(profile);
        if (cached != null && cached.isNotEmpty && userSeg.isNotEmpty) {
          swRoomListHtml.stop();
          importSourcePrimary = 'collects';
          pcHtmlSkipped = true;
          sourceDecisionReason = 'normalImportUsesCollects';
          initialOrdered = [];
        } else {
          roomImportListingLog(
            'source=html_minimal page=1 url=$listingUrl reason=numericUserIdBootstrap',
          );
          var h = await _listingFetcher.fetchListingHtmlBody(listingUrl);
          listingHtml = h;
          String? nid = h == null
              ? null
              : RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(h);
          if (nid == null || nid.isEmpty) {
            final itemsUri = _itemsListingUri(profile);
            if (itemsUri != null) {
              final listingNorm = _canonicalRoomListingUrl(listingUrl);
              final itemsNorm = _canonicalRoomListingUrl(itemsUri.toString());
              final sameListingUrl = listingNorm == itemsNorm;
              if (sameListingUrl && (h ?? '').isNotEmpty) {
                nid =
                    RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                      h!,
                    );
              } else if (!sameListingUrl) {
                roomImportListingLog(
                  'source=html_minimal page=2 url=$itemsUri reason=userIdBootstrap',
                );
                final h2 = await _listingFetcher.fetchListingHtmlBody(
                  itemsUri.toString(),
                );
                if (h2 != null) {
                  listingHtml = h2;
                  nid =
                      RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                        h2,
                      );
                  if (userSeg.isNotEmpty) {
                    RoomUrlResolver.mergeListingFastPathHintsFromHtml(
                      h2,
                      userSeg,
                      listingFastPath,
                    );
                  }
                }
              }
            }
          }
          swRoomListHtml.stop();
          if (nid != null && nid.isNotEmpty) {
            await RoomImportCollectsResumeStore.saveNumericUserId(profile, nid);
          }
          if (nid != null && nid.isNotEmpty && userSeg.isNotEmpty) {
            importSourcePrimary = 'collects';
            pcHtmlSkipped = true;
            sourceDecisionReason = 'normalImportUsesCollects';
            initialOrdered = [];
          } else {
            usedFullListingHtmlForPrepare = true;
            pcHtmlSkipped = false;
            importSourcePrimary = 'pcHtml';
            sourceDecisionReason = 'numericIdUnavailableFallbackToPcHtml';
            roomImportListingLog(
              'source=html page=1 url=$listingUrl reason=numericIdFallbackFullListing',
            );
            swRoomListHtml.reset();
            swRoomListHtml.start();
            initialOrdered = await _listingFetcher.fetchPostedRoomProductPageUrls(
              listingUrl,
              onListingHtml: (html) => listingHtml = html,
            );
            postedUrlListFetchCount = 1;
            swRoomListHtml.stop();
            if (listingHtml != null) {
              final nid2 =
                  RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                    listingHtml!,
                  );
              if (nid2 != null && nid2.isNotEmpty) {
                await RoomImportCollectsResumeStore.saveNumericUserId(profile, nid2);
              }
            }
          }
        }
      }

      roomImportSourceDecisionLog(
        'job=import primary=$importSourcePrimary pcHtmlSkipped=$pcHtmlSkipped '
        'reason=$sourceDecisionReason',
      );
      roomImportSourceDecisionDetailLog(
        'job=import primary=$importSourcePrimary pcHtmlSkipped=$pcHtmlSkipped '
        'reason=$sourceDecisionReason imageNeedsFallback=${pcHtmlSkipped ? 'true' : 'false'}',
      );

      roomSyncVerboseLog(
        '一覧HTMLから得られたROOM商品URL総数（未取り込みフィルタ前）: ${initialOrdered.length}',
      );

      var listingInitialCandidateCount = initialOrdered.length;
      roomImportPerfLog('extractRoomItemsStart');
      roomImportPerfLog(
        'extractRoomItemsEnd found=$listingInitialCandidateCount durationMs=0',
      );

      if (debugVerboseRoomImport && initialOrdered.isEmpty) {
        roomSyncError('ROOMの投稿一覧を取得できませんでした（抽出0件または接続失敗）。');
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
      final swExistingProducts = Stopwatch()..start();
      final workingManagedList = List<RakutenManagedProduct>.from(
        _repository.loadAll(),
      );
      swExistingProducts.stop();
      final swSyncedKeys = Stopwatch()..start();
      final syncedRoomKeys =
          RakutenManagedProductRepository.normalizedRoomProductUrlKeys(
            workingManagedList,
          );
      swSyncedKeys.stop();

      final initialUnsynced = initialOrdered.where((k) {
        final nk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(k);
        return nk.isNotEmpty && !syncedRoomKeys.contains(nk);
      }).length;
      roomSyncSummaryLog(
        '投稿一覧 ${initialOrdered.length}件 · 未取り込み推定 $initialUnsynced件',
      );

      roomSyncVerboseLog('初期HTML候補数: $listingInitialCandidateCount');
      roomSyncVerboseLog('初期HTML未取り込み候補数: $initialUnsynced');

      final swQueueBuild = Stopwatch()..start();
      var collectsPreparePagesFetched = 0;
      var collectsPrepareStopReason = 'notUsed';
      var collectsPrepareIncompleteExplore = false;
      String? collectsPrepareLastNextCursor;
      final collectsPrepareModeLabel = collectsExploreMode.name;
      final importCollectsMaxPages =
          collectsExploreMode == RoomImportCollectsExploreMode.deep
          ? RoomImportCollectsPolicy.deepMaxCollectPages
          : RoomImportCollectsPolicy.normalMaxCollectPages;
      roomBatchFetchPlanLog(
        'job=import maxPages=$importCollectsMaxPages maxItems=$maxItems '
        'cursorMode=sequential reason=cursorDependsOnPreviousPage',
      );
      if ((listingHtml ?? '').isNotEmpty && userSeg.isNotEmpty) {
        RoomUrlResolver.mergeListingFastPathHintsFromHtml(
          listingHtml!,
          userSeg,
          listingFastPath,
        );
      }

      final page1HasUnsynced = initialOrdered.any((k) {
        final nk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(k);
        return nk.isNotEmpty && !syncedRoomKeys.contains(nk);
      });
      if (page1HasUnsynced) {
        await _cursorRepo?.clearImportCursor(
          profile,
          reason: 'latestPageHasUnregistered',
        );
      }

      final orderedKeys = List<String>.from(initialOrdered);
      final seenKeys = orderedKeys.toSet();
      var discoveryIdx = 0;
      var listingChecked = 0;
      var listingSkip = 0;
      final toProcess = <String>[];
      var skipFurtherCollectsPages = page1HasUnsynced;
      String? importCursorUsedPreview;

      final consecutiveLimit =
          collectsExploreMode == RoomImportCollectsExploreMode.deep
          ? 1000000
          : RoomImportCollectsPolicy.consecutiveKnownLimitForNormalStop;
      var consecutiveKnownStreak = 0;
      var stopDiscoveryForConsecutive = false;

      void advanceQueueFromDiscovery() {
        while (toProcess.length < maxItems &&
            discoveryIdx < orderedKeys.length) {
          final k = orderedKeys[discoveryIdx++];
          listingChecked++;
          if (syncedRoomKeys.contains(k)) {
            listingSkip++;
            consecutiveKnownStreak++;
            if (consecutiveKnownStreak >= consecutiveLimit &&
                toProcess.length < maxItems) {
              stopDiscoveryForConsecutive = true;
              break;
            }
          } else {
            consecutiveKnownStreak = 0;
            toProcess.add(k);
          }
        }
      }

      var importBatchStartStrategy = 'resumeCursor';
      if (page1HasUnsynced) {
        importBatchStartStrategy = 'latestPage';
        for (final k in initialOrdered) {
          if (toProcess.length >= maxItems) break;
          listingChecked++;
          if (syncedRoomKeys.contains(k)) {
            listingSkip++;
          } else {
            toProcess.add(k);
          }
        }
        discoveryIdx = initialOrdered.length;
        if (toProcess.length >= maxItems) {
          roomImportListingLog(
            'stop reason=enoughItems count=${toProcess.length} source=html_page1',
          );
          collectsPrepareStopReason = 'enoughItems';
        }
      } else {
        listingChecked = initialOrdered.length;
        listingSkip = initialOrdered.length;
        discoveryIdx = initialOrdered.length;
        advanceQueueFromDiscovery();
        if (toProcess.length >= maxItems) {
          roomImportListingLog(
            'stop reason=enoughItems count=${toProcess.length} source=html',
          );
          collectsPrepareStopReason = 'enoughItems';
        } else if (stopDiscoveryForConsecutive &&
            collectsExploreMode == RoomImportCollectsExploreMode.normal) {
          collectsPrepareStopReason = 'consecutiveKnownLimitReached';
          collectsPrepareIncompleteExplore = true;
        }
      }
      swQueueBuild.stop();

      final swCollects = Stopwatch()..start();
      var additionalFetchStatus = '不要';
      if (!skipFurtherCollectsPages && toProcess.length < maxItems) {
        final allInitialSynced =
            initialOrdered.isNotEmpty &&
            initialOrdered.every(syncedRoomKeys.contains);
        if (allInitialSynced) {
          roomSyncVerboseLog('初期HTML候補がすべて取り込み済みのため追加取得を試行します');
        }

        var numericUserId =
            await RoomImportCollectsResumeStore.readNumericUserId(profile);
        if (numericUserId == null || numericUserId.isEmpty) {
          numericUserId = listingHtml == null
              ? null
              : RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                  listingHtml!,
                );
        }
        if (numericUserId == null || numericUserId.isEmpty) {
          final itemsUri = _itemsListingUri(profile);
          if (itemsUri != null) {
            final listingNorm = _canonicalRoomListingUrl(listingUrl);
            final itemsNorm = _canonicalRoomListingUrl(itemsUri.toString());
            final sameListingUrl = listingNorm == itemsNorm;
            if (sameListingUrl && (listingHtml ?? '').isNotEmpty) {
              roomSyncVerboseLog(
                'userData.id 未取得だが一覧URL同一のため再GETせず HTML を再利用',
              );
              roomImportListingLog(
                'source=html_reuse page=1 url=$itemsUri reason=sameAsInitialListing',
              );
              numericUserId =
                  RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                    listingHtml!,
                  );
            } else {
              roomSyncVerboseLog(
                'userData.id 未取得のため /items へ再GETして再試行: $itemsUri',
              );
              roomImportListingLog(
                'source=html page=2 url=$itemsUri reason=userIdFromInitialState',
              );
              final h = await _listingFetcher.fetchListingHtmlBody(
                itemsUri.toString(),
              );
              if (h != null) {
                RoomUserPostedListingFetcher.logListingHtmlInvestigation(h);
                if (userSeg.isNotEmpty) {
                  RoomUrlResolver.mergeListingFastPathHintsFromHtml(
                    h,
                    userSeg,
                    listingFastPath,
                  );
                }
                numericUserId =
                    RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                      h,
                    );
              }
            }
          }
        }

        if (numericUserId != null && numericUserId.trim().isNotEmpty) {
          await RoomImportCollectsResumeStore.saveNumericUserId(
            profile,
            numericUserId.trim(),
          );
        }

        if (numericUserId == null || numericUserId.isEmpty || userSeg.isEmpty) {
          additionalFetchStatus = '未対応（WebView fallback 候補）';
          roomSyncVerboseLog('追加取得方式: 未対応（API用 userData.id 未取得またはユーザーセグメント空）');
        } else if (stopDiscoveryForConsecutive &&
            collectsExploreMode == RoomImportCollectsExploreMode.normal) {
          roomSyncVerboseLog(
            '追加取得方式: スキップ（通常モード・連続既知打ち切り）',
          );
          additionalFetchStatus = 'スキップ(連続既知打切)';
        } else {
          roomSyncVerboseLog('追加取得方式: API');
          additionalFetchStatus = '実行済み(API)';
          roomImportCollectsPolicyLog(
            'mode=${collectsExploreMode.name} maxPages=$importCollectsMaxPages '
            'consecutiveKnownLimit=$consecutiveLimit targetNewItems=$maxItems',
          );

          final importResume = await _cursorRepo?.loadImportCursor(profile);
          var cursor = importResume?.nextImportCursor?.trim();
          if (cursor == null || cursor.isEmpty) {
            cursor = await RoomImportCollectsResumeStore.readAfterId(profile);
          }
          if (cursor != null && cursor.isNotEmpty) {
            importCursorUsedPreview = cursor;
            roomImportCollectsPolicyLog('mode=${collectsExploreMode.name} resumeAfterId=present');
          }

          var brokeOnCollectsFailure = false;
          var exitedOnNoMoreData = false;

          for (
            var pageIdx = 0;
            pageIdx < importCollectsMaxPages &&
                toProcess.length < maxItems &&
                !skipFurtherCollectsPages;
            pageIdx++
          ) {
            if (stopDiscoveryForConsecutive &&
                collectsExploreMode == RoomImportCollectsExploreMode.normal) {
              break;
            }
            roomSyncVerboseLog('追加取得 page/cursor: ${cursor ?? '(先頭ページ)'}');
            roomImportListingLog(
              'source=collects page=${pageIdx + 1} '
              'url=https://room.rakuten.co.jp/api/$numericUserId/collects '
              'cursor=${cursor ?? '(start)'}',
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
              brokeOnCollectsFailure = true;
              collectsPrepareStopReason = 'collectsFailed';
              if (!debugVerboseRoomImport &&
                  !usedFullListingHtmlForPrepare &&
                  orderedKeys.isEmpty &&
                  toProcess.isEmpty) {
                usedFullListingHtmlForPrepare = true;
                pcHtmlSkipped = false;
                importSourcePrimary = 'pcHtml';
                sourceDecisionReason = 'collectsFailedFallbackToPcHtml';
                roomImportSourceDecisionLog(
                  'job=import primary=pcHtml pcHtmlSkipped=false '
                  'reason=collectsFailedFallbackToPcHtml',
                );
                roomImportListingLog(
                  'source=html page=1 url=$listingUrl reason=collectsFailedFallbackToPcHtml',
                );
                final swFb = Stopwatch()..start();
                final fallback = await _listingFetcher.fetchPostedRoomProductPageUrls(
                  listingUrl,
                  onListingHtml: (html) => listingHtml = html,
                );
                swFb.stop();
                if (kDebugMode) {
                  roomImportPrepareDetailLog(
                    'roomListHtmlFallbackFetchMs',
                    swFb.elapsedMilliseconds,
                  );
                }
                postedUrlListFetchCount++;
                for (final k in fallback) {
                  if (!seenKeys.contains(k)) {
                    seenKeys.add(k);
                    orderedKeys.add(k);
                  }
                }
                advanceQueueFromDiscovery();
                if (toProcess.isNotEmpty) {
                  additionalFetchStatus = '失敗後HTML救済';
                  brokeOnCollectsFailure = false;
                  collectsPrepareStopReason = 'collectsFailedHtmlFallback';
                }
              }
              break;
            }

            collectsPreparePagesFetched++;
            var knownOnPage = 0;
            var newOnPage = 0;
            for (final k in page.roomPageKeysOrdered) {
              if (seenKeys.contains(k)) continue;
              if (syncedRoomKeys.contains(k)) {
                knownOnPage++;
              } else {
                newOnPage++;
              }
            }

            roomSyncVerboseLog('追加取得候補数: ${page.roomPageKeysOrdered.length}');
            for (final raw in page.rawCollectRows) {
              RoomUrlResolver.mergeListingFastPathFromCollectsRow(
                raw,
                userSeg,
                listingFastPath,
              );
              final rowId = raw['id'];
              if (rowId is String && rowId.isNotEmpty) {
                final built = 'https://room.rakuten.co.jp/$userSeg/$rowId';
                final rk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
                  built,
                );
                if (rk.isNotEmpty) {
                  metadataSourceByRoomKey[rk] = 'collects';
                }
              }
            }
            var appended = 0;
            for (final k in page.roomPageKeysOrdered) {
              if (seenKeys.contains(k)) continue;
              seenKeys.add(k);
              orderedKeys.add(k);
              appended++;
            }
            advanceQueueFromDiscovery();

            if (pageIdx == 0) {
              final anyUnsyncedOnCollectsLatest = page.roomPageKeysOrdered.any((k) {
                final nk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(k);
                return nk.isNotEmpty && !syncedRoomKeys.contains(nk);
              });
              if (anyUnsyncedOnCollectsLatest) {
                await _cursorRepo?.clearImportCursor(
                  profile,
                  reason: 'collectsLatestPageHasUnregistered',
                );
                skipFurtherCollectsPages = true;
              }
            }

            final nextRaw = page.nextAfterId?.trim();
            if (nextRaw != null && nextRaw.isNotEmpty) {
              collectsPrepareLastNextCursor = nextRaw;
            }

            roomImportCollectsProgressLog(
              'page=${pageIdx + 1} foundNewOnPage=$newOnPage knownOnPage=$knownOnPage '
              'totalNew=${toProcess.length} totalKnown=$listingSkip '
              'nextCursor=${nextRaw ?? '(none)'}',
            );

            final unsyncedAmongDiscovered = orderedKeys
                .where((k) => !syncedRoomKeys.contains(k))
                .length;
            roomSyncVerboseLog('追加取得後の未取り込み候補数: $unsyncedAmongDiscovered');

            if (toProcess.length >= maxItems) {
              roomImportListingLog(
                'stop reason=enoughItems count=${toProcess.length} '
                'source=collects page=${pageIdx + 1}',
              );
              collectsPrepareStopReason = 'enoughItems';
              collectsPrepareIncompleteExplore = false;
              break;
            }
            if (stopDiscoveryForConsecutive &&
                collectsExploreMode == RoomImportCollectsExploreMode.normal) {
              collectsPrepareStopReason = 'consecutiveKnownLimitReached';
              collectsPrepareIncompleteExplore = true;
              break;
            }

            final nextCursor = page.nextAfterId;
            if (nextCursor == null ||
                nextCursor.trim().isEmpty ||
                page.rawItemCount == 0) {
              roomImportListingLog(
                'stop reason=apiNoMore cursorEmpty=${nextCursor == null || nextCursor.trim().isEmpty} '
                'rawItemCount=${page.rawItemCount}',
              );
              exitedOnNoMoreData = true;
              collectsPrepareStopReason = 'noMoreCursor';
              await _cursorRepo?.clearImportCursor(
                profile,
                reason: 'collectsNoMoreData',
              );
              if (_cursorRepo == null) {
                await RoomImportCollectsResumeStore.clearAfterId(profile);
              }
              break;
            }

            cursor = nextCursor;
            if (appended == 0 && toProcess.length < maxItems) {
              // 重複のみのページが返る場合もあるためカーソルで先へ進む。
              continue;
            }
          }

          if (!brokeOnCollectsFailure && !exitedOnNoMoreData) {
            if (toProcess.length >= maxItems) {
              collectsPrepareStopReason = 'enoughItems';
              collectsPrepareIncompleteExplore = false;
            } else if (stopDiscoveryForConsecutive &&
                collectsExploreMode == RoomImportCollectsExploreMode.normal) {
              collectsPrepareStopReason = 'consecutiveKnownLimitReached';
              collectsPrepareIncompleteExplore = true;
            } else if (collectsPreparePagesFetched >= importCollectsMaxPages) {
              collectsPrepareStopReason = 'maxPagesReached';
              collectsPrepareIncompleteExplore = true;
              roomImportListingLog(
                'stop reason=maxPagesReached pages=$collectsPreparePagesFetched '
                'queue=${toProcess.length}',
              );
            }
          }

          final resumeCursor = collectsPrepareLastNextCursor?.trim();
          if (!brokeOnCollectsFailure &&
              !exitedOnNoMoreData &&
              resumeCursor != null &&
              resumeCursor.isNotEmpty) {
            final lastKey = toProcess.isNotEmpty
                ? RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
                    toProcess.last,
                  )
                : null;
            if (_cursorRepo != null) {
              await _cursorRepo.saveImportCursor(
                RoomImportCursorState(
                  roomProfileKey: profile,
                  nextImportCursor: resumeCursor,
                  lastImportFinishedAt: DateTime.now().toUtc().toIso8601String(),
                  lastImportedCount: toProcess.length,
                  lastProcessedRoomKey:
                      (lastKey != null && lastKey.isNotEmpty) ? lastKey : null,
                ),
              );
            } else {
              await RoomImportCollectsResumeStore.saveAfterId(
                profile,
                resumeCursor,
              );
            }
          }

          roomImportCollectsStopLog(
            'reason=$collectsPrepareStopReason pagesFetched=$collectsPreparePagesFetched '
            'newItems=${toProcess.length} knownItems=$listingSkip '
            'durationMs=${swCollects.elapsedMilliseconds}',
          );
        }
      } else {
        roomSyncVerboseLog('追加取得方式: 不要（初期候補でキュー充足見込み）');
        if (toProcess.length >= maxItems) {
          collectsPrepareStopReason = 'enoughItems';
        }
      }

      swCollects.stop();
      listingInitialCandidateCount = orderedKeys.length;
      roomSyncVerboseLog('取り込み対象キュー件数: ${toProcess.length}');
      prepareSw.stop();
      final importPagesFetchedTotal =
          postedUrlListFetchCount + collectsPreparePagesFetched;
      roomBatchFetchResultLog(
        'job=import pagesFetched=$importPagesFetchedTotal '
        'itemsFetched=${orderedKeys.length} '
        'durationMs=${prepareSw.elapsedMilliseconds}',
      );
      roomImportPerfLog(
        'prepareEnd durationMs=${prepareSw.elapsedMilliseconds}',
      );
      if (kDebugMode) {
        RoomImportDebugLogBuffer.notePrepareMs(prepareSw.elapsedMilliseconds);
        roomImportPrepareDetailLog(
          'roomListHtmlFetchMs',
          swRoomListHtml.elapsedMilliseconds,
        );
        roomImportPrepareDetailLog(
          'collectsFetchMs',
          swCollects.elapsedMilliseconds,
        );
        roomImportPrepareDetailLog(
          'existingProductsLoadMs',
          swExistingProducts.elapsedMilliseconds,
        );
        roomImportPrepareDetailLog(
          'syncedKeyBuildMs',
          swSyncedKeys.elapsedMilliseconds,
        );
        roomImportPrepareDetailLog(
          'queueBuildMs',
          swQueueBuild.elapsedMilliseconds,
        );
        var prepareFastPathOverlap = 0;
        for (final k in toProcess) {
          if (listingFastPath.containsKey(k)) prepareFastPathOverlap++;
        }
        roomFastPathSummaryLog(
          'prepareQueueCanFastPath=$prepareFastPathOverlap '
          'prepareQueueSize=${toProcess.length} '
          'listingIndexedKeys=${listingFastPath.length}',
        );
      }
      onProcessingHint?.call('ROOM投稿を確認しています');
      if (toProcess.isNotEmpty) {
        onProcessingHint?.call('新規候補を${toProcess.length}件見つけました');
        onProcessingHint?.call('商品を保存しています');
        onProcessingHint?.call('0/${toProcess.length}件を取り込み中');
      }
      final catalogLookupSummary = RoomCatalogLookupSummary();
      final catalogRepoForEntry = _productCatalogRepository;
      RoomCatalogLookupSummary.logLookupEntry(
        enabled: RoomCatalogEnrichment.enabled,
        repositoryPresent: catalogRepoForEntry != null,
        targetCount: toProcess.length,
        source: 'roomSync',
      );

      roomImportBatchStartLog(
        'mode=importWithInitialEnrichment limit=$maxItems '
        'startStrategy=$importBatchStartStrategy '
        'cursor=${importCursorUsedPreview ?? '-'}',
      );

      if (toProcess.isEmpty) {
        catalogLookupSummary.logSummary(reason: 'noImportTargets');
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
          collectsExploreModeLabel: collectsPrepareModeLabel,
          collectsPagesFetched: collectsPreparePagesFetched,
          collectsStopReason: collectsPrepareStopReason == 'notUsed'
              ? null
              : collectsPrepareStopReason,
          collectsIncompleteExplore: collectsPrepareIncompleteExplore,
          collectsLastNextCursor: collectsPrepareLastNextCursor,
          newlyImportedProductIds: const [],
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

      var fastPathCount = 0;
      var fallbackRoomPageCount = 0;
      var totalRoomPageMs = 0;

      var reactionsResynced = 0;
      final newlyImportedProductIds = <String>[];

      var batchCompareExistingMatches = 0;
      var batchCompareNewCandidates = 0;
      var batchCompareReactionChanged = 0;
      var batchCompareUnchanged = 0;
      var batchSaveMutations = 0;

      if (batchSize > 0) {
        try {
          for (var i = 0; i < toProcess.length; i++) {
        final itemSw = Stopwatch()..start();
        final roomPageUrl = toProcess[i];
        final ordinal = i + 1;
        roomImportPerfLog('itemStart index=$ordinal roomUrl=$roomPageUrl');
        roomImportUiLog('phase=processing current=$ordinal total=$batchSize');
        onProcessingHint?.call('商品を保存しています $ordinal/$batchSize');
        roomSyncVerboseLog('$ordinal件目の商品を確認');
        roomSyncVerboseLog('roomUrl: $roomPageUrl');

        final normalizedKey =
            RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomPageUrl);
        final preSynced = syncedRoomKeys.contains(normalizedKey);
        roomSyncVerboseLog('取り込み済み判定（ROOMキー）: $preSynced');

        RoomUrlResolveOutcome resolved;
        var metadataSource = metadataSourceByRoomKey[normalizedKey] ?? 'roomDetailHtml';
        roomImportPerfLog('roomPageFetchStart index=$ordinal');
        final roomPageSw = Stopwatch()..start();
        final fast = listingFastPath[normalizedKey];
        if (fast != null) {
          resolved = fast;
          metadataSource = metadataSourceByRoomKey[normalizedKey] ?? 'collects';
          roomPageSw.stop();
          fastPathCount++;
          roomFastPathLog(
            'resolvedFromListing=true shopCode=${fast.rakutenItem.shopCode} '
            'itemCode=${fast.rakutenItem.itemPathSegment} roomKey=$normalizedKey',
          );
          roomImportPerfLog(
            'roomPageFetchEnd index=$ordinal status=fastPath durationMs=${roomPageSw.elapsedMilliseconds}',
          );
        } else {
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
            roomPageSw.stop();
            fallbackRoomPageCount++;
            totalRoomPageMs += roomPageSw.elapsedMilliseconds;
            roomImportPerfLog(
              'roomPageFetchEnd index=$ordinal status=exception htmlBytes=0 durationMs=${roomPageSw.elapsedMilliseconds}',
            );
            itemSw.stop();
            roomImportPerfLog(
              'itemEnd index=$ordinal result=failed durationMs=${itemSw.elapsedMilliseconds}',
            );
            continue;
          }
          roomPageSw.stop();
          fallbackRoomPageCount++;
          totalRoomPageMs += roomPageSw.elapsedMilliseconds;
          final resolvedStatus = resolved is RoomUrlResolveSuccess
              ? 200
              : 'resolveFailed';
          roomImportPerfLog(
            'roomPageFetchEnd index=$ordinal status=$resolvedStatus htmlBytes=-1 durationMs=${roomPageSw.elapsedMilliseconds}',
          );
        }

        if (resolved is! RoomUrlResolveSuccess) {
          final f = resolved as RoomUrlResolveFailure;
          roomSyncWarn(
            'ROOM商品ページから楽天URL解決失敗 kind=${f.kind} detail=${f.debugDetail ?? '-'}',
          );
          failed++;
          failedUrls.add(roomPageUrl);
          onCheckingProgress?.call(i + 1, batchSize);
          itemSw.stop();
          roomImportPerfLog(
            'itemEnd index=$ordinal result=failed durationMs=${itemSw.elapsedMilliseconds}',
          );
          continue;
        }

        var rs = resolved;
        if (rs.roomRatRedirectUrl.trim().isNotEmpty ||
            rs.roomRedirectShopCode.trim().isNotEmpty) {
          metadataSource = 'ratRedirect';
        } else if (metadataSource != 'collects') {
          metadataSource = 'roomDetailHtml';
        }
        final parsed = rs.rakutenItem;
        roomImportPerfLog('rakutenUrlResolveStart index=$ordinal');
        final rakutenResolveSw = Stopwatch()..start();
        roomSyncVerboseLog('楽天URL解析開始: ${parsed.rakutenUrl}');
        roomSyncVerboseLog(
          '使用した正規表現: ${RakutenItemUrlParser.itemRakutenUrlPattern.pattern}',
        );
        final verified = RakutenItemUrlParser.tryParse(parsed.rakutenUrl);
        rakutenResolveSw.stop();
        roomImportPerfLog(
          'rakutenUrlResolveEnd index=$ordinal durationMs=${rakutenResolveSw.elapsedMilliseconds}',
        );
        roomImportPerfLog('parseCodesStart index=$ordinal');
        final parseCodesSw = Stopwatch()..start();
        if (verified == null) {
          roomSyncError('shopCode / itemCode の抽出に失敗');
          roomSyncVerboseLog('対象URL: ${parsed.rakutenUrl}');
          roomSyncVerboseLog(
            '使用した正規表現: ${RakutenItemUrlParser.itemRakutenUrlPattern.pattern}',
          );
          failed++;
          failedUrls.add(roomPageUrl);
          onCheckingProgress?.call(i + 1, batchSize);
          parseCodesSw.stop();
          roomImportPerfLog(
            'parseCodesEnd index=$ordinal shopCode=- itemCode=- durationMs=${parseCodesSw.elapsedMilliseconds}',
          );
          itemSw.stop();
          roomImportPerfLog(
            'itemEnd index=$ordinal result=failed durationMs=${itemSw.elapsedMilliseconds}',
          );
          continue;
        }
        parseCodesSw.stop();
        roomImportPerfLog(
          'parseCodesEnd index=$ordinal shopCode=${verified.shopCode} itemCode=${verified.itemPathSegment} durationMs=${parseCodesSw.elapsedMilliseconds}',
        );
        roomImportPerfLog('existingCheckStart index=$ordinal');
        final existingMatch =
            RakutenManagedProductRepository.findRoomImportExistingRowMatch(
          list: workingManagedList,
          roomPageUrl: roomPageUrl,
          normalizedRoomUrlKey: normalizedKey,
          parsedItem: parsed,
          roomPageAffiliateUrl: rs.roomPageAffiliateUrl,
        );
        final firstImport = existingMatch == null;
        if (existingMatch != null && kDebugMode) {
          roomImportExistingMatchLog(
            'matchType=${existingMatch.matchType} productId=${existingMatch.row.productId} '
            'shopCode=${verified.shopCode} itemCode=${verified.itemPathSegment}',
          );
        }
        if (existingMatch != null) {
          final sr = existingMatch.row.roomUrl.trim();
          if (sr.isNotEmpty) {
            final rk =
                RoomRakutenUrlNormalize.normalizeRoomProductPageKey(sr);
            if (rk.isNotEmpty && rk != normalizedKey) {
              roomImportSameItemDifferentRoomLog(
                'productId=${existingMatch.row.productId} shopCode=${verified.shopCode} '
                'itemCode=${verified.itemPathSegment} storedRoomKey=$rk currentKey=$normalizedKey',
              );
              roomImportSkipApiLog('reason=alreadyImported');
              skipped++;
              batchCompareExistingMatches++;
              itemSw.stop();
              roomImportPerfLog(
                'existingCheckEnd index=$ordinal exists=true durationMs=0',
              );
              roomImportPerfLog(
                'itemEnd index=$ordinal result=skipped durationMs=${itemSw.elapsedMilliseconds}',
              );
              onCheckingProgress?.call(i + 1, batchSize);
              continue;
            }
          }
        }
        roomImportPerfLog(
          'existingCheckEnd index=$ordinal exists=${!firstImport} durationMs=0',
        );
        roomSyncVerboseLog('shopCode: ${verified.shopCode}');
        roomSyncVerboseLog('itemCode: ${verified.itemPathSegment}');

        RakutenSearchItem? apiEnriched;
        var rakutenApiPartialData = false;
        var roomImportFallbackRecovered = false;
        var listingHintFromResolve = rs.listingHintPriceYen;

        final addRoomUrlToExistingNoApi = existingMatch != null &&
            existingMatch.row.roomUrl.trim().isEmpty;

        if (preSynced) {
          RoomImportDebugLogBuffer.incApiSkipped();
          roomImportSkipApiLog(
            'reason=alreadyImportedSkipInCollectImportBatch',
          );
          skipped++;
          batchCompareUnchanged++;
          itemSw.stop();
          roomImportPerfLog(
            'itemEnd index=$ordinal result=skippedPreSynced durationMs=${itemSw.elapsedMilliseconds}',
          );
          onCheckingProgress?.call(i + 1, batchSize);
          continue;
        }

        final usedFastPath = fast != null;
        final collectsRaw = rs.roomPageImageUrl?.trim() ?? '';
        var collectsImageUrl = collectsRaw;
        var roomHtmlImageUrl = '';
        apiEnriched = null;
        rakutenApiPartialData = false;
        if (!firstImport) {
          RoomImportDebugLogBuffer.incApiSkipped();
          roomImportSkipApiLog('reason=alreadyImported');
        } else {
          final shop = verified.shopCode.trim();
          final item = verified.itemPathSegment.trim();
          final compositeId = shop.isNotEmpty && item.isNotEmpty ? '$shop:$item' : '';
          final catalogRepo = _productCatalogRepository;
          if (catalogRepo != null && RoomCatalogEnrichment.enabled) {
            final catalogHit = RoomCatalogEnrichment.lookupKeys(
              repository: catalogRepo,
              productId: compositeId,
              roomApiCompositeItemCode: compositeId,
              itemUrl: parsed.rakutenUrl,
              affiliateUrl: rs.roomPageAffiliateUrl ?? '',
              roomPageUrl: roomPageUrl,
              shopCode: shop,
              itemPathSegment: item,
            );
            catalogLookupSummary.recordLookup(catalogHit);
            final cat = catalogHit.product;
            if (cat != null) {
              final patch =
                  RoomCatalogEnrichment.buildImmediateImagePatchForNewImport(
                catalog: cat,
                productId: compositeId,
              );
              if (patch != null) {
                apiEnriched = patch;
                RoomImportDebugLogBuffer.incApiSkipped();
                roomImportSkipApiLog(
                  'reason=catalogImageHit shopCode=$shop itemCode=$item',
                );
              }
            }
          }
          final searchRepo = _searchRepository;
          if (apiEnriched == null &&
              searchRepo != null &&
              shop.isNotEmpty &&
              item.isNotEmpty) {
            try {
              RoomImportDebugLogBuffer.incApiExecuted();
              final env = await searchRepo.fetchFirstItemForRoomImportEnrichmentEnvelope(
                shopCode: shop,
                itemCode: item,
              );
              apiEnriched = env.item;
              if (apiEnriched != null) {
                roomImportSkipApiLog(
                  'reason=immediateImageFetch shopCode=$shop itemCode=$item',
                );
              } else {
                rakutenApiPartialData = true;
                RoomImportDebugLogBuffer.incApiSkipped();
                roomImportSkipApiLog(
                  'reason=immediateApiEmpty shopCode=$shop itemCode=$item',
                );
              }
            } catch (_) {
              rakutenApiPartialData = true;
              RoomImportDebugLogBuffer.incApiSkipped();
              roomImportSkipApiLog(
                'reason=immediateApiFailed shopCode=$shop itemCode=$item',
              );
            }
          } else if (apiEnriched == null) {
            rakutenApiPartialData = true;
            RoomImportDebugLogBuffer.incApiSkipped();
            roomImportSkipApiLog(
              'reason=deferredEnrichment shopCode=$shop itemCode=$item',
            );
          }

          final apiItemForImage = apiEnriched;
          final apiImgOk = apiItemForImage != null &&
              RoomImportProductImage.isSafeProductImageUrl(
                apiItemForImage.imageUrl,
              );
          final collectsSafe =
              RoomImportProductImage.isSafeProductImageUrl(collectsRaw);
          if (!apiImgOk &&
              (!collectsSafe || usedFastPath)) {
            var fallbackReason = 'apiImageMissing';
            if (!collectsSafe && collectsRaw.isNotEmpty) {
              fallbackReason = 'unsafeCollectsImage';
            } else if (collectsRaw.isEmpty) {
              fallbackReason = 'missingCollectsImage';
            }
            try {
              final full = await _resolver.resolveRakutenItemUrlFromRoomPage(
                roomPageUrl,
                traceRoomSync: traceDetailed,
              );
              if (full is RoomUrlResolveSuccess) {
                final htmlImg = full.roomPageImageUrl?.trim() ?? '';
                if (RoomImportProductImage.isSafeProductImageUrl(htmlImg)) {
                  roomHtmlImageUrl = htmlImg;
                  roomImportFallbackRecovered = true;
                  RoomImportDebugLogBuffer.incFallbackRecovered();
                  roomHtmlImageFallbackLog(
                    'productId=${verified.itemPathSegment} triggered=true '
                    'reason=$fallbackReason found=true',
                  );
                } else {
                  roomHtmlImageFallbackLog(
                    'productId=${verified.itemPathSegment} triggered=true '
                    'reason=$fallbackReason found=false',
                  );
                }
              }
            } catch (_) {
              roomHtmlImageFallbackLog(
                'productId=${verified.itemPathSegment} triggered=true '
                'reason=$fallbackReason found=false',
              );
            }
          }
        }

        try {
          roomImportPerfLog('reactionParseStart index=$ordinal');
          roomImportPerfLog(
            'reactionParseEnd index=$ordinal likes=${rs.roomLikeCount ?? -1} comments=${rs.roomCommentCount ?? -1} durationMs=0',
          );
          roomImportPerfLog('saveStart index=$ordinal');
          roomImportUiLog('phase=saving current=$ordinal');
          final saveSw = Stopwatch()..start();
          final outcome = await _repository.persistRoomCollectedFromRoomPage(
            roomUrlStoredCanonical: normalizedKey,
            normalizedRoomUrlKey: normalizedKey,
            parsedItem: parsed,
            roomPageAffiliateUrl: rs.roomPageAffiliateUrl,
            roomPageTitle: rs.roomPageTitle ?? '',
            roomPageImageUrl: collectsRaw,
            collectsImageUrl: collectsImageUrl,
            roomHtmlImageUrl: roomHtmlImageUrl,
            apiEnrichedItem: apiEnriched,
            traceRoomSync: traceDetailed,
            workingMutableList: workingManagedList,
            roomLikeCount: rs.roomLikeCount,
            roomCommentCount: rs.roomCommentCount,
            listingHintPriceYen: listingHintFromResolve,
            suppressListingHintPrice: false,
            rakutenApiPartialData: rakutenApiPartialData,
            roomImportFallbackRecovered: roomImportFallbackRecovered,
            roomImportResyncReactionsOnly: false,
            roomImportAddRoomUrlToExistingNoApi: addRoomUrlToExistingNoApi,
            confirmDiskWrite: false,
            roomProductSlugHint: rs.roomProductSlug,
            roomRatRedirectUrlHint: rs.roomRatRedirectUrl,
            roomRedirectShopCodeHint: rs.roomRedirectShopCode,
            roomRedirectItemCodeHint: rs.roomRedirectItemCode,
            roomApiCompositeItemCodeHint: rs.roomApiCompositeItemCode,
            roomEventGenreIdHint: rs.roomEventGenreId,
          );
          saveSw.stop();
          roomImportPerfLog(
            'saveEnd index=$ordinal durationMs=${saveSw.elapsedMilliseconds}',
          );

          final k = outcome.kind;
          String itemResult = 'updated';
          if (k == RoomCollectedPersistKind.demoUnsupported) {
            roomSyncWarn('保存種別: デモ拒否');
            failed++;
            failedUrls.add(roomPageUrl);
            itemResult = 'failed';
          } else if (k == RoomCollectedPersistKind.roomPageAlreadySynced ||
              k == RoomCollectedPersistKind.alreadyCollectedSkip) {
            roomSyncVerboseLog('保存種別: スキップ (${k.name})');
            skipped++;
            batchCompareUnchanged++;
            itemResult = 'skipped';
          } else if (k == RoomCollectedPersistKind.roomReactionsUpdated) {
            roomSyncVerboseLog('保存種別: ROOM反応のみ更新');
            reactionsResynced++;
            batchCompareReactionChanged++;
            batchSaveMutations++;
            itemResult = 'reactionsUpdated';
          } else if (k == RoomCollectedPersistKind.updatedRoomUrlOnly) {
            roomSyncVerboseLog('保存種別: 既存商品へROOM URL追加 完了');
            roomAdd++;
            batchCompareExistingMatches++;
            batchSaveMutations++;
            itemResult = 'updated';
          } else if (k == RoomCollectedPersistKind.insertedNewCollected) {
            roomSyncVerboseLog('保存種別: 新規コレ済登録 完了');
            newly++;
            batchCompareNewCandidates++;
            batchSaveMutations++;
            itemResult = 'added';
            final newPid = outcome.productId?.trim() ?? '';
            if (newPid.isNotEmpty) {
              newlyImportedProductIds.add(newPid);
              if (kDebugMode) {
                final rawTitle = (rs.roomPageTitle ?? '').replaceAll(
                  RegExp(r'[\r\n]+'),
                  ' ',
                );
                final titleLog = rawTitle.trim();
                final tOut = titleLog.length > 100
                    ? '${titleLog.substring(0, 100)}…'
                    : titleLog;
                final imgRaw = (rs.roomPageImageUrl ?? '').trim();
                final imageFound = imgRaw.isNotEmpty;
                final hint = listingHintFromResolve;
                final priceFound = hint != null && hint > 0;
                final shopCodeLog = verified.shopCode.trim();
                final urlProductCodeLog = verified.itemPathSegment.trim();
                final rakutenUrlLog = parsed.rakutenUrl.trim();
                roomImportRoomMetadataLog(
                  'productId=$newPid titleFound=${tOut.isNotEmpty} '
                  'imageFound=$imageFound priceFound=$priceFound '
                  'shopCode=$shopCodeLog urlProductCode=$urlProductCodeLog '
                  'rakutenItemUrl=$rakutenUrlLog roomPostUrl=$normalizedKey '
                  'roomLikeCount=${rs.roomLikeCount ?? '-'} '
                  'roomCommentCount=${rs.roomCommentCount ?? '-'} '
                  'source=$metadataSource',
                );
              }
            }
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
                  reactionHitOrdinal.putIfAbsent(
                    pid,
                    () => reactionOrdinalSeq++,
                  );
                }
              }
            }
          }
          if (k == RoomCollectedPersistKind.updatedRoomUrlOnly ||
              k == RoomCollectedPersistKind.insertedNewCollected) {
            syncedRoomKeys.add(normalizedKey);
          }
          itemSw.stop();
          roomImportPerfLog(
            'itemEnd index=$ordinal result=$itemResult durationMs=${itemSw.elapsedMilliseconds}',
          );
        } catch (e, st) {
          roomSyncError('永続化例外（persistRoomCollectedFromRoomPage）', e, st);
          failed++;
          failedUrls.add(roomPageUrl);
          itemSw.stop();
          roomImportPerfLog(
            'itemEnd index=$ordinal result=failed durationMs=${itemSw.elapsedMilliseconds}',
          );
        }

        onCheckingProgress?.call(i + 1, batchSize);
      }
        } finally {
          roomBatchCompareResultLog(
            'job=import fetchedItems=$batchSize '
            'existingMatches=$batchCompareExistingMatches '
            'newCandidates=$batchCompareNewCandidates '
            'reactionChanged=$batchCompareReactionChanged '
            'unchanged=$batchCompareUnchanged',
          );
          final flushSw = Stopwatch()..start();
          await _repository.flushSharedWorkingMutableList(workingManagedList);
          final searchRepoForRecovery = _searchRepository;
          if (newlyImportedProductIds.isNotEmpty) {
            final catalogRepo = _productCatalogRepository;
            if (catalogRepo != null && RoomCatalogEnrichment.enabled) {
              final importedRows = <RakutenManagedProduct>[];
              for (final pid in newlyImportedProductIds) {
                final row = _repository.getByProductId(pid);
                if (row != null) importedRows.add(row);
              }
              unawaited(
                upsertCatalogFromRoomManagedProducts(
                  catalogRepo,
                  importedRows,
                  source: CatalogProductSource.roomImport,
                  sourceTrust: CatalogProductSourceTrust.medium,
                ),
              );
            }
            if (searchRepoForRecovery != null) {
              await _repository.recoverSuspiciousImagesForProductIds(
                productIds: newlyImportedProductIds,
                fetchApi: (row) async {
                  final catalogRepo = _productCatalogRepository;
                  if (catalogRepo != null && RoomCatalogEnrichment.enabled) {
                    final hit = RoomCatalogEnrichment.lookupProduct(
                      repository: catalogRepo,
                      row: row,
                    );
                    final cat = hit.product;
                    if (cat != null) {
                      final patch = RoomCatalogEnrichment.buildImmediateImagePatch(
                        row: row,
                        catalog: cat,
                      );
                      if (patch != null) return patch;
                    }
                  }
                  final shop = row.shopCode.trim();
                  final item = row.productId.trim();
                  if (shop.isEmpty || item.isEmpty) return null;
                  final env = await searchRepoForRecovery
                      .fetchFirstItemForRoomImportEnrichmentEnvelope(
                    shopCode: shop,
                    itemCode: item,
                  );
                  return env.item;
                },
              );
            }
          }
          catalogLookupSummary.logSummary();
          flushSw.stop();
          final skippedUnchangedSave = batchSize - batchSaveMutations - failed;
          roomBatchSaveResultLog(
            'job=import saveTargets=$batchSaveMutations '
            'saved=$batchSaveMutations skippedUnchanged=$skippedUnchangedSave '
            'refreshListOnce=true durationMs=${flushSw.elapsedMilliseconds}',
          );
        }
      }

      if (kDebugMode && batchSize > 0) {
        final ex = RoomImportDebugLogBuffer.apiExecutedCount;
        final sk = RoomImportDebugLogBuffer.apiSkippedCount;
        final defer =
            ex == 0 ? 'reason=deferredEnrichment ' : '';
        roomImportApiSummaryLog(
          'apiExecuted=$ex apiSkipped=$sk $defer'
          'fallbackRecovered=${RoomImportDebugLogBuffer.fallbackRecoveredCount} '
          'rateLimited=${RoomImportDebugLogBuffer.apiRateLimitedCount} '
          'http400=${RoomImportDebugLogBuffer.apiHttp400Count}',
        );
        final avgMs = fallbackRoomPageCount > 0
            ? totalRoomPageMs / fallbackRoomPageCount
            : 0.0;
        final estimatedSavedMs = fallbackRoomPageCount > 0
            ? (fastPathCount * avgMs).round()
            : 0;
        roomFastPathSummaryLog(
          'fastPathCount=$fastPathCount '
          'fallbackRoomPageCount=$fallbackRoomPageCount '
          'avgRoomPageMs=${fallbackRoomPageCount > 0 ? avgMs.toStringAsFixed(0) : 'na'} '
          'estimatedSavedMs=$estimatedSavedMs '
          'listingIndexedKeys=${listingFastPath.length}',
        );
      }

      onProcessingHint?.call('取り込みが完了しました');

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
        return (reactionHitOrdinal[a] ?? 0).compareTo(
          reactionHitOrdinal[b] ?? 0,
        );
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
        newlyCollectedSamples: List<RakutenManagedProduct>.unmodifiable(
          newlyCollectedSamples,
        ),
        reactionHighlightSamples: List<RakutenManagedProduct>.unmodifiable(
          reactionHighlightSamples,
        ),
        reactionsResyncedCount: reactionsResynced,
        collectsExploreModeLabel: collectsPrepareModeLabel,
        collectsPagesFetched: collectsPreparePagesFetched,
        collectsStopReason: collectsPrepareStopReason == 'notUsed'
            ? null
            : collectsPrepareStopReason,
        collectsIncompleteExplore: collectsPrepareIncompleteExplore,
        collectsLastNextCursor: collectsPrepareLastNextCursor,
        newlyImportedProductIds: List<String>.unmodifiable(
          newlyImportedProductIds,
        ),
      );
    } finally {
      totalSw.stop();
      if (kDebugMode) {
        RoomImportDebugLogBuffer.noteTotalMs(totalSw.elapsedMilliseconds);
      }
      roomImportPerfLog('totalEnd durationMs=${totalSw.elapsedMilliseconds}');
      _postedRoomImportInFlight = false;
    }
  }

  /// 取り込み済み ROOM 商品の **反応数のみ** を最大 [maxItems] 件更新する（楽天APIなし）。
  Future<RoomReactionSyncBatchResult?> syncPostedRoomReactionsOnly({
    required String userRoomProfileUrl,
    int maxItems = defaultMaxBatch,
    void Function(int currentIndex, int batchSize)? onCheckingProgress,
    void Function(String hint)? onProcessingHint,
  }) async {
    if (_postedRoomReactionSyncInFlight) {
      roomSyncSummaryLog('ROOM反応数同期 実行中のためスキップ（二重起動防止）');
      return null;
    }
    _postedRoomReactionSyncInFlight = true;
    try {
      if (kDemoModeEnabled) {
        return const RoomReactionSyncBatchResult(
          updated: 0,
          latestPageUpdated: 0,
          resumedUpdated: 0,
          cursorAction: 'clear',
          fatalErrorMessage: 'デモモードでは反応数の同期を実行できません',
        );
      }

      final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
        userRoomProfileUrl,
      );
      if (profile.isEmpty) {
        return const RoomReactionSyncBatchResult(
          updated: 0,
          latestPageUpdated: 0,
          resumedUpdated: 0,
          cursorAction: 'clear',
          fatalErrorMessage: 'マイページで楽天ROOMのプロフィールURLを登録してください',
        );
      }

      final listingUrl = RoomProfileUrlValidationService.buildItemsUrl(profile);
      if (listingUrl.isEmpty) {
        return const RoomReactionSyncBatchResult(
          updated: 0,
          latestPageUpdated: 0,
          resumedUpdated: 0,
          cursorAction: 'clear',
          fatalErrorMessage: 'ROOMの投稿一覧URLを作成できませんでした。URLを確認してください',
        );
      }

      final swAll = Stopwatch()..start();

      final workingManagedList = List<RakutenManagedProduct>.from(
        _repository.loadAll(),
      );
      final syncedRoomKeys =
          RakutenManagedProductRepository.normalizedRoomProductUrlKeys(
            workingManagedList,
          );

      final userSeg = _roomUserSegment(profile);
      String? listingHtml;
      final latestPageUrls = <String>[];
      var reactionListingHtmlMs = 0;
      var reactionLatestSourceRowCount = 0;
      var reactionCollectsApiMsPre = 0;
      var reactionCollectsPagesFetchedPre = 0;

      var numericUserId =
          await RoomImportCollectsResumeStore.readNumericUserId(profile);
      if (numericUserId == null || numericUserId.isEmpty) {
        final h = await _listingFetcher.fetchListingHtmlBody(listingUrl);
        listingHtml = h;
        numericUserId = h == null
            ? null
            : RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(h);
      }
      if (numericUserId == null || numericUserId.isEmpty) {
        final itemsUri = _itemsListingUri(profile);
        if (itemsUri != null) {
          final listingNorm = _canonicalRoomListingUrl(listingUrl);
          final itemsNorm = _canonicalRoomListingUrl(itemsUri.toString());
          final sameListingUrl = listingNorm == itemsNorm;
          if (sameListingUrl && (listingHtml ?? '').isNotEmpty) {
            numericUserId =
                RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                  listingHtml!,
                );
          } else if (!sameListingUrl) {
            final h2 = await _listingFetcher.fetchListingHtmlBody(
              itemsUri.toString(),
            );
            if (h2 != null) {
              listingHtml = h2;
              numericUserId =
                  RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
                    h2,
                  );
            }
          }
        }
      }
      if (numericUserId != null && numericUserId.trim().isNotEmpty) {
        await RoomImportCollectsResumeStore.saveNumericUserId(
          profile,
          numericUserId.trim(),
        );
      }

      if (numericUserId != null &&
          numericUserId.isNotEmpty &&
          userSeg.isNotEmpty) {
        final swCollect = Stopwatch()..start();
        final page = await _listingFetcher.fetchCollectsApiPage(
          numericUserId: numericUserId,
          roomUserSegment: userSeg,
          afterId: null,
          limit: _collectsApiPageLimit,
        );
        swCollect.stop();
        reactionCollectsApiMsPre += swCollect.elapsedMilliseconds;
        if (page != null) {
          reactionCollectsPagesFetchedPre = 1;
          reactionLatestSourceRowCount = page.roomPageKeysOrdered.length;
          for (final k in page.roomPageKeysOrdered) {
            final nk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(k);
            if (nk.isNotEmpty && syncedRoomKeys.contains(nk)) {
              latestPageUrls.add(k);
            }
          }
        }
      }

      if (latestPageUrls.isEmpty) {
        final swListing = Stopwatch()..start();
        final initialOrdered = await _listingFetcher.fetchPostedRoomProductPageUrls(
          listingUrl,
          onListingHtml: (h) => listingHtml = h,
        );
        swListing.stop();
        reactionListingHtmlMs = swListing.elapsedMilliseconds;
        reactionLatestSourceRowCount = initialOrdered.length;
        if (initialOrdered.isEmpty) {
          return const RoomReactionSyncBatchResult(
            updated: 0,
            latestPageUpdated: 0,
            resumedUpdated: 0,
            cursorAction: 'clear',
            fatalErrorMessage:
                'ROOMの投稿一覧を取得できませんでした。URLを確認するか、しばらくしてからもう一度お試しください',
          );
        }
        for (final k in initialOrdered) {
          final nk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(k);
          if (nk.isNotEmpty && syncedRoomKeys.contains(nk)) {
            latestPageUrls.add(k);
          }
        }
      }

      roomBatchFetchPlanLog(
        'job=reactionSync maxPages=2 maxItems=$maxItems '
        'cursorMode=latestPlusResumeOnePage reason=budgetedReactionSync',
      );

      var updated = 0;
      var latestPageUpdated = 0;
      var resumedUpdated = 0;
      final seenNorm = <String>{};
      String? lastNormProcessed;
      final traceDetailed = debugVerboseRoomImport;
      var itemsChecked = 0;
      const maxReactionMs = 15000;
      const maxReactionChecks = 40;
      String? stopReason;

      var reactionCollectsApiMs = reactionCollectsApiMsPre;
      var reactionCollectsPagesFetched = reactionCollectsPagesFetchedPre;
      var reactionCollectsRowsListed = reactionLatestSourceRowCount;
      var reactionPersistAttempts = 0;
      var unchangedItemsCount = 0;
      var likeIncreasedItems = 0;
      var commentIncreasedItems = 0;
      var hasReactionItemsCount = 0;
      var commentedItemsCount = 0;
      final reactionTopCandidates = <RoomReactionSyncTopProduct>[];

      Future<int> tryUpdateReactions(String roomPageUrl) async {
        final normalizedKey =
            RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomPageUrl);
        if (normalizedKey.isEmpty || !syncedRoomKeys.contains(normalizedKey)) {
          return 0;
        }
        if (!seenNorm.add(normalizedKey)) return 0;
        if (updated >= maxItems ||
            itemsChecked >= maxReactionChecks ||
            swAll.elapsedMilliseconds >= maxReactionMs) {
          return 0;
        }
        itemsChecked++;

        RakutenManagedProduct? prevRow;
        for (final e in workingManagedList) {
          final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
            e.roomUrl,
          );
          if (ek.isNotEmpty && ek == normalizedKey) {
            prevRow = e;
            break;
          }
        }
        final prevL = prevRow?.roomLikeCount ?? 0;
        final prevC = prevRow?.roomCommentCount ?? 0;
        final title = prevRow?.itemName ?? '';

        RoomUrlResolveOutcome resolved;
        try {
          resolved = await _resolver.resolveRakutenItemUrlFromRoomPage(
            roomPageUrl,
            traceRoomSync: traceDetailed,
          );
        } catch (_) {
          return 0;
        }
        if (resolved is! RoomUrlResolveSuccess) return 0;
        final rs = resolved;
        final parsed = rs.rakutenItem;
        final verified = RakutenItemUrlParser.tryParse(parsed.rakutenUrl);
        if (verified == null) return 0;

        try {
          reactionPersistAttempts++;
          final outcome = await _repository.persistRoomCollectedFromRoomPage(
            roomUrlStoredCanonical: normalizedKey,
            normalizedRoomUrlKey: normalizedKey,
            parsedItem: parsed,
            roomPageAffiliateUrl: rs.roomPageAffiliateUrl,
            roomPageTitle: rs.roomPageTitle ?? '',
            roomPageImageUrl: rs.roomPageImageUrl ?? '',
            apiEnrichedItem: null,
            traceRoomSync: traceDetailed,
            workingMutableList: workingManagedList,
            roomLikeCount: rs.roomLikeCount,
            roomCommentCount: rs.roomCommentCount,
            listingHintPriceYen: rs.listingHintPriceYen,
            suppressListingHintPrice: true,
            rakutenApiPartialData: false,
            roomImportFallbackRecovered: false,
            roomImportResyncReactionsOnly: true,
            roomImportAddRoomUrlToExistingNoApi: false,
            confirmDiskWrite: false,
          );
          if (outcome.kind == RoomCollectedPersistKind.roomReactionsUpdated) {
            lastNormProcessed = normalizedKey;
            final pid = outcome.productId?.trim() ?? '';
            if (pid.isNotEmpty) {
              RakutenManagedProduct? row;
              for (final e in workingManagedList) {
                if (e.productId.trim() == pid) {
                  row = e;
                  break;
                }
              }
              if (row != null) {
                final nl = row.roomLikeCount ?? 0;
                final nc = row.roomCommentCount ?? 0;
                if (nl > prevL) likeIncreasedItems++;
                if (nc > prevC) commentIncreasedItems++;
                if (nl > 0 || nc > 0) {
                  hasReactionItemsCount++;
                  if (nc > 0) commentedItemsCount++;
                }
                reactionTopCandidates.add(
                  RoomReactionSyncTopProduct(
                    productId: pid,
                    title: title.isNotEmpty ? title : row.itemName.trim(),
                    imageUrl: row.imageUrl.trim(),
                    roomLikeCount: nl,
                    roomCommentCount: nc,
                    previousLikeCount: prevL,
                    previousCommentCount: prevC,
                    deltaLike: nl - prevL,
                    deltaComment: nc - prevC,
                  ),
                );
              }
            }
            return 1;
          }
          if (outcome.kind == RoomCollectedPersistKind.roomPageAlreadySynced ||
              outcome.kind == RoomCollectedPersistKind.alreadyCollectedSkip) {
            unchangedItemsCount++;
            RakutenManagedProduct? row;
            final pid = outcome.productId?.trim() ?? '';
            if (pid.isNotEmpty) {
              for (final e in workingManagedList) {
                if (e.productId.trim() == pid) {
                  row = e;
                  break;
                }
              }
            }
            if (row == null) {
              for (final e in workingManagedList) {
                final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
                  e.roomUrl,
                );
                if (ek.isNotEmpty && ek == normalizedKey) {
                  row = e;
                  break;
                }
              }
            }
            final nl = rs.roomLikeCount ?? row?.roomLikeCount ?? 0;
            final nc = rs.roomCommentCount ?? row?.roomCommentCount ?? 0;
            if (nl > 0 || nc > 0) {
              hasReactionItemsCount++;
              if (nc > 0) commentedItemsCount++;
            }
            return 2;
          }
          return 0;
        } catch (_) {
          return 0;
        }
      }

      onProcessingHint?.call('ROOMの反応数を確認しています');
      var batchIdx = 0;

      bool shouldAbort() {
        if (updated >= maxItems) {
          stopReason ??= 'updatedLimitReached';
          return true;
        }
        if (itemsChecked >= maxReactionChecks) {
          stopReason ??= 'maxCheckedItemsReached';
          return true;
        }
        if (swAll.elapsedMilliseconds >= maxReactionMs) {
          stopReason ??= 'maxDurationReached';
          return true;
        }
        return false;
      }

      for (final url in latestPageUrls) {
        if (shouldAbort()) break;
        batchIdx++;
        onProcessingHint?.call(
          '反応数を確認中 $updated / $maxItems（確認 $itemsChecked / $maxReactionChecks）',
        );
        onCheckingProgress?.call(batchIdx, maxItems);
        if (await tryUpdateReactions(url) == 1) {
          updated++;
          latestPageUpdated++;
        }
      }

      var resumeCursorUsed = false;
      String? collectsPrepareLastNextCursor;
      var exitedOnNoMoreData = false;

      if (!shouldAbort() &&
          numericUserId != null &&
          numericUserId.isNotEmpty &&
          userSeg.isNotEmpty) {
        final reactionResume = await _cursorRepo?.loadReactionCursor(profile);
        final resumeCurRaw = reactionResume?.nextReactionCursor?.trim();
        if (resumeCurRaw != null && resumeCurRaw.isNotEmpty) {
          resumeCursorUsed = true;
          final swCollect = Stopwatch()..start();
          final page = await _listingFetcher.fetchCollectsApiPage(
            numericUserId: numericUserId,
            roomUserSegment: userSeg,
            afterId: resumeCurRaw,
            limit: _collectsApiPageLimit,
          );
          swCollect.stop();
          reactionCollectsApiMs += swCollect.elapsedMilliseconds;
          if (page == null) {
            stopReason ??= 'error';
          } else {
            reactionCollectsPagesFetched++;
            reactionCollectsRowsListed += page.roomPageKeysOrdered.length;
            final nextRaw = page.nextAfterId?.trim();
            if (nextRaw != null && nextRaw.isNotEmpty) {
              collectsPrepareLastNextCursor = nextRaw;
            }
            for (final k in page.roomPageKeysOrdered) {
              if (shouldAbort()) break;
              final nk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(k);
              if (nk.isEmpty || !syncedRoomKeys.contains(nk)) continue;
              batchIdx++;
              onProcessingHint?.call(
                '反応数を確認中 $updated / $maxItems（確認 $itemsChecked / $maxReactionChecks）',
              );
              onCheckingProgress?.call(batchIdx, maxItems);
              if (await tryUpdateReactions(k) == 1) {
                updated++;
                resumedUpdated++;
              }
            }
            final nextCursor = page.nextAfterId;
            if (nextCursor == null ||
                nextCursor.trim().isEmpty ||
                page.rawItemCount == 0) {
              exitedOnNoMoreData = true;
              await _cursorRepo?.clearReactionCursor(
                profile,
                reason: 'collectsNoMoreData',
              );
            }
          }
        }
      }

      stopReason ??= exitedOnNoMoreData ? 'noMoreCursor' : 'completed';

      String cursorAction = 'clear';
      String? nextOut;
      final resumeCur = collectsPrepareLastNextCursor?.trim();
      if (exitedOnNoMoreData) {
        cursorAction = 'clear';
      } else if (resumeCur != null && resumeCur.isNotEmpty) {
        cursorAction = 'save';
        nextOut = resumeCur;
        await _cursorRepo?.saveReactionCursor(
          RoomReactionSyncCursorState(
            roomProfileKey: profile,
            nextReactionCursor: nextOut,
            lastReactionSyncFinishedAt: DateTime.now().toUtc().toIso8601String(),
            lastUpdatedCount: updated,
            lastProcessedRoomKey: lastNormProcessed,
          ),
        );
      } else {
        await _cursorRepo?.clearReactionCursor(
          profile,
          reason: 'batchDoneNoResumeCursor',
        );
      }

      roomBatchFetchResultLog(
        'job=reactionSync pagesFetched=${reactionCollectsPagesFetched + (reactionListingHtmlMs > 0 ? 1 : 0)} '
        'itemsFetched=$reactionCollectsRowsListed '
        'durationMs=${reactionListingHtmlMs + reactionCollectsApiMs}',
      );
      roomReactionSyncStopLog(
        'reason=$stopReason pagesFetched=${reactionCollectsPagesFetched + (reactionListingHtmlMs > 0 ? 1 : 0)} '
        'itemsChecked=$itemsChecked updated=$updated durationMs=${swAll.elapsedMilliseconds} '
        'nextCursor=${collectsPrepareLastNextCursor ?? '-'}',
      );
      roomBatchCompareResultLog(
        'job=reactionSync fetchedItems=$reactionPersistAttempts '
        'existingMatches=0 newCandidates=0 '
        'reactionChanged=$updated unchanged=$unchangedItemsCount',
      );
      final reactionFlushSw = Stopwatch()..start();
      await _repository.flushSharedWorkingMutableList(workingManagedList);
      reactionFlushSw.stop();
      final reactionSkippedUnchanged =
          reactionPersistAttempts - updated;
      final topSorted = List<RoomReactionSyncTopProduct>.from(
        reactionTopCandidates,
      )..sort((a, b) {
          final sb = b.deltaLike + b.deltaComment;
          final sa = a.deltaLike + a.deltaComment;
          if (sb != sa) return sb.compareTo(sa);
          return b.deltaLike.compareTo(a.deltaLike);
        });
      final top3 = topSorted.take(3).toList(growable: false);
      final uiSummary = roomReactionSyncSnackBarSummary(
        checkedItems: itemsChecked,
        hasReactionItems: hasReactionItemsCount,
        commentedItems: commentedItemsCount,
        unchangedItems: unchangedItemsCount,
        stopReason: stopReason ?? '',
        hasNextCursor: nextOut != null && nextOut.trim().isNotEmpty,
      );
      roomReactionSyncUiSummaryLog(
        'checkedItems=$itemsChecked updatedItems=$updated '
        'hasReactionItems=$hasReactionItemsCount commentedItems=$commentedItemsCount '
        'unchangedItems=$unchangedItemsCount '
        'topReactedProductIds=${top3.map((e) => e.productId).join(',')} '
        'stopReason=${stopReason ?? '-'} hasNextCursor=${nextOut != null && nextOut.trim().isNotEmpty} '
        'message=${uiSummary.replaceAll('\n', ' ')}',
      );
      roomBatchSaveResultLog(
        'job=reactionSync saveTargets=$updated saved=$updated '
        'skippedUnchanged=$reactionSkippedUnchanged refreshListOnce=true '
        'durationMs=${reactionFlushSw.elapsedMilliseconds}',
      );

      return RoomReactionSyncBatchResult(
        updated: updated,
        latestPageUpdated: latestPageUpdated,
        resumedUpdated: resumedUpdated,
        nextCursor: nextOut,
        cursorAction: cursorAction,
        latestPageChecked: true,
        resumeCursorUsed: resumeCursorUsed,
        itemsChecked: itemsChecked,
        pagesFetched: reactionCollectsPagesFetched + (reactionListingHtmlMs > 0 ? 1 : 0),
        durationMs: swAll.elapsedMilliseconds,
        stopReason: stopReason,
        likeIncreasedItems: likeIncreasedItems,
        commentIncreasedItems: commentIncreasedItems,
        unchangedItems: unchangedItemsCount,
        hasReactionItems: hasReactionItemsCount,
        commentedItems: commentedItemsCount,
        topReactedProducts: top3,
        uiSummaryMessage: uiSummary,
      );
    } finally {
      _postedRoomReactionSyncInFlight = false;
    }
  }

  static String _roomUserSegment(String profile) {
    return RoomProfileUrlValidationService.extractRoomId(profile);
  }

  /// プロフィール URL を `/items` 付きの一覧 URL に揃える（同一なら null）。
  static Uri? _itemsListingUri(String profile) {
    try {
      final itemsUrl = RoomProfileUrlValidationService.buildItemsUrl(profile);
      if (itemsUrl.isEmpty) return null;
      return Uri.parse(itemsUrl);
    } catch (_) {
      return null;
    }
  }

  /// 同一 ROOM 一覧 URL の再 GET を避けるための比較用キー。
  static String _canonicalRoomListingUrl(String raw) {
    try {
      final u = Uri.parse(raw.trim());
      final path = u.path.endsWith('/') ? u.path.substring(0, u.path.length - 1) : u.path;
      return '${u.scheme}://${u.host.toLowerCase()}$path'.toLowerCase();
    } catch (_) {
      return raw.trim().toLowerCase();
    }
  }
}
