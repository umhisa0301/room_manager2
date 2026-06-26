import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../config/room_import_debug_ui_config.dart';
import '../config/room_import_enrichment_verify_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_sync_result.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/room_sync_cursor_repository.dart';
import '../services/app_action_service.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_enrichment_cooldown_store.dart';
import '../services/room_import_limit.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/room_sync_service.dart';
import '../state/bulk_operation_state_controller.dart';
import '../utils/product_image_resolve.dart';
import '../utils/room_import_pending_user_copy.dart';
import '../utils/room_reaction_status_display.dart';
import '../utils/room_sync_log.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import 'room_colle_product_list_card_layout.dart';

/// [RoomPostImportFlow.executeBatch] から通知される進捗。
typedef RoomPostImportProgressCallback =
    void Function({
      required bool busy,
      required int completed,
      required int total,
    });

/// ホーム / マイページ共通の ROOM 投稿取り込み（内部 API は [RoomSyncService] のまま）。
abstract final class RoomPostImportFlow {
  static Future<void> _copyRoomImportDebugLog(BuildContext context) async {
    await RoomImportDebugLogBuffer.copyToClipboard();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ROOM取り込みログをコピーしました')));
  }

  static void _showRoomImportDebugLogDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: const Text('ROOM取り込み デバッグログ'),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: SelectableText(
                  RoomImportDebugLogBuffer.dump(),
                  style: const TextStyle(fontSize: 11, height: 1.25),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  /// 未補完の ROOM 取り込み商品だけ楽天 API で再試行（ホーム・マイページの補助導線用）。
  static Future<void> runManualPendingRoomImportMetadataEnrich(
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final bulk = context.read<BulkOperationStateController>();
    if (kDemoModeEnabled) {
      messenger.showSnackBar(
        const SnackBar(content: Text('デモモードでは商品情報の補完は実行できません')),
      );
      return;
    }
    final inCooldown = await RoomImportEnrichmentCooldownStore.isInCooldown();
    if (!context.mounted) return;
    if (inCooldown) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '楽天APIの利用制限のため、'
            '約${RoomImportLimitPolicy.enrichCooldownAfter429Minutes}分後に補完を再開します。',
          ),
        ),
      );
      return;
    }
    if (bulk.isRoomTourSearchBlocking || bulk.isBulkCandidateRegistering) {
      bulk.guardBlockingOperations(context);
      return;
    }
    if (bulk.isMetadataEnriching) {
      roomImportManualEnrichStartLog(
        'maxPerRun=${RoomImportLimitPolicy.manualEnrichMaxProductsPerRun} '
        'manualPacing=true '
        'autoEnrichRunning=${RoomImportMetadataEnrichmentService.isEnrichmentSingleFlightHeld} '
        'action=blockedWithMessage',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('別の補完処理が実行中です。完了後にお試しください。')),
      );
      return;
    }
    roomImportManualEnrichStartLog(
      'maxPerRun=${RoomImportLimitPolicy.manualEnrichMaxProductsPerRun} '
      'manualPacing=true '
      'autoEnrichRunning=${RoomImportMetadataEnrichmentService.isEnrichmentSingleFlightHeld} '
      'action=started',
    );
    roomSyncJobLockLog('action=acquire job=enrichingMetadata currentJob=none');
    bulk.setMetadataEnriching(true);
    try {
      final searchRepo = context.read<RakutenSearchRepository>();
      final productRepo = context.read<RakutenManagedProductRepository>();
      final managedProv = context.read<RakutenManagedProductProvider>();
      final catalogRepo = context.read<ProductCatalogRepository>();
      final svc = RoomImportMetadataEnrichmentService(
        searchRepository: searchRepo,
        productRepository: productRepo,
        productCatalogRepository: catalogRepo,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('ショップ名・ジャンルを再確認しています…')),
      );
      final result = await svc.enrichRoomImportedProducts(
        limit: RoomImportLimitPolicy.manualEnrichMaxProductsPerRun,
        applyPostImportAutoCap: false,
        manualSessionPacing: true,
      );
      if (!context.mounted) return;
      await managedProv.refreshManagedProductList();
      if (!context.mounted) return;

      bulk.setManualEnrichSummary(
        success: result.updated,
        fail: result.failedInBatch,
        remaining: result.remainingPending,
        pausedByRateLimit: result.pausedByRateLimit,
      );
      if (result.successProductIds.isNotEmpty) {
        bulk.flashRoomImportEnrichedIds(result.successProductIds);
      }

      final topRoomDone =
          managedProv.items
              .where(
                (e) =>
                    e.status == RakutenManagedProductStatus.done &&
                    e.coredActivitySource ==
                        RakutenCoredActivitySource.roomImport,
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final visibleTop = topRoomDone
          .take(8)
          .map((e) => e.productId.trim())
          .join(',');
      roomImportEnrichUiReflectLog(
        'updatedProductIds=${result.successProductIds.join(',')} '
        'visibleTopProductIds=$visibleTop '
        'message=補完成功商品が現在の表示範囲にない場合、画面上では変化が見えないことがあります',
      );

      if (RoomImportEnrichmentVerifyConfig.enabled &&
          result.verifyUiMessage != null &&
          result.verifyUiMessage!.trim().isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(result.verifyUiMessage!.trim())),
        );
      } else if (result.duplicateSessionSkipped) {
        messenger.showSnackBar(
          const SnackBar(content: Text('別の補完処理が実行中です。完了後にお試しください。')),
        );
      } else if (result.skippedCooldown) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'しばらくしてから自動で補完を再開します'
              '（未確認が${result.remainingPending}件残っています）。',
            ),
          ),
        );
      } else if (result.pausedByRateLimit) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'API制限のため一時停止しました。少し時間をおいて再実行してください。'
              '成功 ${result.updated}件 / 残り ${result.remainingPending}件',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'ショップ名・ジャンルを確認しました：成功 ${result.updated}件 / 失敗 ${result.failedInBatch}件 / 残り ${result.remainingPending}件',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('商品情報の補完に失敗しました: $e')));
    } finally {
      bulk.setMetadataEnriching(false);
      roomSyncJobLockLog(
        'action=release job=enrichingMetadata currentJob=none',
      );
    }
  }

  /// 取り込み後のダイアログ・SnackBar・結果シート。
  static Future<void> presentPostImportUi(
    BuildContext context,
    RoomSyncResult? result, {
    required Future<RoomSyncResult?> Function() startBatch,
    Future<RoomSyncResult?> Function()? startDeepCollectsBatch,
  }) async {
    if (result == null) return;
    if (!context.mounted) return;

    if (result.hasFatalError) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ROOM同期'),
          content: SingleChildScrollView(
            key: const Key('room_import_error_message'),
            child: Text(result.fatalErrorMessage!.trim()),
          ),
          actions: [
            if (RoomImportDebugUiConfig.showDebugActions) ...[
              TextButton(
                onPressed: () async {
                  await RoomImportDebugLogBuffer.copyToClipboard();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ROOM取り込みログをコピーしました')),
                    );
                  }
                },
                child: const Text('デバッグログをコピー'),
              ),
              TextButton(
                onPressed: () {
                  _showRoomImportDebugLogDialog(ctx);
                },
                child: const Text('デバッグログを表示'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    var snackText = result.newlyCollectedCount > 0
        ? '${result.newlyCollectedCount}件を取り込みました'
        : (result.roomUrlAddedCount > 0
              ? 'ROOMページを${result.roomUrlAddedCount}件紐付けました'
              : 'ROOM投稿の確認が終わりました（追加なし）');
    if (result.collectsIncompleteExplore) {
      snackText += '。古い投稿に未取り込みが残っている可能性があります';
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(snackText)));

    if (!context.mounted) return;
    await showResultSheet(
      context,
      result: result,
      startBatch: startBatch,
      startDeepCollectsBatch: startDeepCollectsBatch,
    );
  }

  /// 1バッチ実行して結果を返す（ROOM URL 未登録時は null）。
  static Future<RoomSyncResult?> executeBatch(
    BuildContext context, {
    required RoomPostImportProgressCallback onProgress,
    void Function(String hint)? onProcessingHint,
    RoomImportCollectsExploreMode collectsExploreMode =
        RoomImportCollectsExploreMode.normal,
  }) async {
    final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
      context.read<UserProfileProvider>().profile.roomUrl,
    );
    if (profile.isEmpty) {
      return null;
    }

    final managedItems = context.read<RakutenManagedProductProvider>().items;
    final importAvailability = resolveRoomImportAvailabilityFromItems(
      items: managedItems,
    );
    if (!importAvailability.allowed) {
      roomImportUiLog('phase=blocked reason=room_import_limit_reached');
      return null;
    }
    final limit = resolveRoomImportBatchSize(importAvailability);
    if (limit <= 0) {
      roomImportUiLog('phase=blocked reason=room_import_batch_size_zero');
      return null;
    }

    final repo = context.read<RakutenManagedProductRepository>();
    final cursorRepo = context.read<RoomSyncCursorRepository>();
    final searchRepo = context.read<RakutenSearchRepository>();
    final catalogRepo = context.read<ProductCatalogRepository>();
    final service = RoomSyncService(
      repository: repo,
      searchRepository: searchRepo,
      productCatalogRepository: catalogRepo,
      roomSyncCursorRepository: cursorRepo,
    );

    var lastCompleted = 0;
    var lastTotal = 0;

    onProgress(busy: true, completed: 0, total: 0);
    roomImportUiLog('phase=preparing message=ROOM投稿を確認しています');

    final result = await service.syncPostedRoomProducts(
      userRoomProfileUrl: profile,
      maxItems: limit,
      collectsExploreMode: collectsExploreMode,
      onCheckingProgress: (current, total) {
        lastCompleted = current;
        lastTotal = total;
        onProgress(busy: true, completed: current, total: total);
        roomImportUiLog('phase=processing current=$current total=$total');
      },
      onProcessingHint: onProcessingHint,
    );

    onProgress(busy: false, completed: lastCompleted, total: lastTotal);
    return result;
  }

  /// 反応数のみ同期（楽天APIなし）。
  static Future<RoomReactionSyncBatchResult?> executeReactionSyncBatch(
    BuildContext context, {
    required RoomPostImportProgressCallback onProgress,
    void Function(String hint)? onProcessingHint,
  }) async {
    final profile = RoomProfileUrlValidationService.normalizeProfileUrl(
      context.read<UserProfileProvider>().profile.roomUrl,
    );
    if (profile.isEmpty) {
      return null;
    }

    final repo = context.read<RakutenManagedProductRepository>();
    final cursorRepo = context.read<RoomSyncCursorRepository>();
    final searchRepo = context.read<RakutenSearchRepository>();
    final catalogRepo = context.read<ProductCatalogRepository>();
    final service = RoomSyncService(
      repository: repo,
      searchRepository: searchRepo,
      productCatalogRepository: catalogRepo,
      roomSyncCursorRepository: cursorRepo,
    );
    final limit = RoomImportLimitPolicy.effectiveBatchLimit();

    var lastCompleted = 0;
    var lastTotal = 0;
    onProgress(busy: true, completed: 0, total: 0);

    roomReactionSyncStartLog('limit=$limit');

    final result = await service.syncPostedRoomReactionsOnly(
      userRoomProfileUrl: profile,
      maxItems: limit,
      onCheckingProgress: (c, t) {
        lastCompleted = c;
        lastTotal = t;
        onProgress(busy: true, completed: c, total: t);
      },
      onProcessingHint: onProcessingHint,
    );

    onProgress(busy: false, completed: lastCompleted, total: lastTotal);
    if (result != null) {
      roomReactionSyncResultLog(
        'updated=${result.updated} '
        'itemsChecked=${result.itemsChecked} '
        'latestPageUpdated=${result.latestPageUpdated} '
        'resumedUpdated=${result.resumedUpdated} '
        'nextCursor=${result.nextCursor ?? '-'} '
        'cursorAction=${result.cursorAction} '
        'stopReason=${result.stopReason ?? '-'} '
        'pagesFetched=${result.pagesFetched} '
        'durationMs=${result.durationMs} '
        'apiCallsToRakuten=0',
      );
    }
    return result;
  }

  /// 取り込み完了シート用に最新商品行を再取得し、表示優先度で並べ替える。
  static List<RakutenManagedProduct> refetchNewlyImportedForResultSheet({
    required RakutenManagedProductRepository repository,
    required RoomSyncResult result,
  }) {
    final ids = result.newlyImportedProductIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return List<RakutenManagedProduct>.from(result.newlyCollectedSamples);
    }
    final rows = <RakutenManagedProduct>[];
    for (final id in ids) {
      final row = repository.getByProductId(id);
      if (row != null) rows.add(row);
    }
    int priority(RakutenManagedProduct p) {
      final complete =
          !RoomImportMetadataEnrichmentService.needFlagsForProduct(p).willEnrich;
      final hasImg = p.imageUrl.trim().isNotEmpty;
      final hasPrice = p.itemPrice > 0;
      var score = 0;
      if (complete) score += 100;
      if (hasImg && hasPrice) {
        score += 40;
      } else if (hasImg) {
        score += 25;
      } else if (hasPrice) {
        score += 15;
      }
      return score;
    }

    rows.sort((a, b) => priority(b).compareTo(priority(a)));
    final display = rows.take(3).toList(growable: false);
    var withImage = 0;
    var withPrice = 0;
    for (final p in rows) {
      if (p.imageUrl.trim().isNotEmpty) withImage++;
      if (p.itemPrice > 0) withPrice++;
    }
    final withoutImageIds = <String>[];
    for (final p in rows) {
      if (ProductImageResolve.displayImageUrlForManaged(p).isEmpty) {
        withoutImageIds.add(p.productId);
      }
    }
    roomImportResultImageRefreshLog(
      'newlyImportedCount=${ids.length} refetchedCount=${rows.length} '
      'withImageCount=$withImage withoutImageCount=${withoutImageIds.length} '
      'withoutImageProductIds=${withoutImageIds.join(',')}',
    );
    roomImportResultSheetRefreshLog(
      'newlyImportedProductIds=${ids.join(',')} refetchedCount=${rows.length} '
      'withImageCount=$withImage withPriceCount=$withPrice '
      'displayProductIds=${display.map((e) => e.productId).join(',')}',
    );
    for (final p in display) {
      ProductImageResolve.logForScreen(
        product: p,
        screen: 'importResult',
      );
      roomImportResultSheetItemLog(
        'productId=${p.productId} title=${p.itemName.trim().isEmpty ? '(empty)' : p.itemName.trim()} '
        'hasImage=${ProductImageResolve.displayImageUrlForManaged(p).isNotEmpty} '
        'price=${p.itemPrice} '
        'formattedPrice=${p.itemPrice > 0 ? RoomColleProductListCardLayout.formatPriceYen(p.itemPrice) : '-'} '
        'shopName=${p.shopName.trim()} genreName=${p.genreName.trim()}',
      );
    }
    return display;
  }

  static List<RakutenManagedProduct> refetchReactionHighlightsForResultSheet({
    required RakutenManagedProductRepository repository,
    required RoomSyncResult result,
  }) {
    final ids = result.reactionHighlightSamples
        .map((e) => e.productId.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return List<RakutenManagedProduct>.from(result.reactionHighlightSamples);
    }
    final rows = <RakutenManagedProduct>[];
    for (final id in ids) {
      final row = repository.getByProductId(id);
      if (row != null) {
        rows.add(row);
        ProductImageResolve.logForScreen(
          product: row,
          screen: 'importResult',
        );
      }
    }
    return rows.take(3).toList(growable: false);
  }

  /// 取り込み結果を BottomSheet で表示。「もう10件」で続行コールバック。
  static Future<void> showResultSheet(
    BuildContext context, {
    required RoomSyncResult result,
    required Future<RoomSyncResult?> Function() startBatch,
    Future<RoomSyncResult?> Function()? startDeepCollectsBatch,
  }) async {
    final navigatorContext = context;
    final productRepo = context.read<RakutenManagedProductRepository>();
    final displayImported = refetchNewlyImportedForResultSheet(
      repository: productRepo,
      result: result,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        roomImportResultSheetCopyLog(_importResultSheetCopyLogLine(result));
        final displayReactions = refetchReactionHighlightsForResultSheet(
          repository: productRepo,
          result: result,
        );
        final added = result.newlyCollectedCount;
        final pendingImported =
            result.postImportEnrichRemainingImportedPending ?? 0;
        final confirmed = (added - pendingImported).clamp(0, added);
        final pending = pendingImported;
        final pendingProducts = displayImported
            .where(
              (p) =>
                  p.itemPrice <= 0 ||
                  p.imageUrl.trim().isEmpty ||
                  p.shopName.trim().isEmpty ||
                  RoomImportPendingUserCopy.classify(p) !=
                      RoomImportPendingReason.unknown,
            )
            .take(pending)
            .toList();
        for (final p in pendingProducts) {
          final reason = RoomImportPendingUserCopy.classify(p);
          RoomImportPendingUserCopy.logPendingProduct(
            product: p,
            reason: reason,
            pendingFields: [
              if (p.itemPrice <= 0) 'price',
              if (p.shopName.trim().isEmpty) 'shopName',
              if (p.genreName.trim().isEmpty) 'genreName',
              if (p.imageUrl.trim().isEmpty) 'image',
            ],
          );
        }
        final productInfoLine = added > 0
            ? RoomImportPendingUserCopy.buildResultSummary(
                added: added,
                confirmed: confirmed,
                pendingProducts: pendingProducts,
              )
            : '';
        final reactionCount = displayReactions.isNotEmpty
            ? displayReactions.length
            : result.reactionHighlightSamples.length;
        roomImportResultSheetSimplifiedLog(
          added: added,
          productInfoConfirmed: confirmed,
          productInfoPending: pending,
          reactionItems: reactionCount,
        );
        final bodySecondary = Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            );
        return SafeArea(
          key: const Key('room_import_result_area'),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '取り込み完了',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  added > 0
                      ? '$added件追加しました'
                      : _heroOutcomeLine(result),
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: HomeScreenColors.homeAccentTeal,
                    height: 1.15,
                  ),
                ),
                if (added > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '投稿済みの商品をコレ済に追加しました。',
                    key: const Key('room_import_result_subtitle'),
                    textAlign: TextAlign.center,
                    style: bodySecondary,
                  ),
                ],
                if (added > 0 && productInfoLine.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    productInfoLine,
                    textAlign: TextAlign.center,
                    style: bodySecondary,
                  ),
                ],
                if (reactionCount > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '反応あり：$reactionCount件',
                    textAlign: TextAlign.center,
                    style: bodySecondary,
                  ),
                ],
                if (displayImported.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    '今回追加した商品',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...displayImported.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ImportedProductPreviewTile(product: p),
                    ),
                  ),
                ],
                if (displayReactions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...displayReactions.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ImportedProductPreviewTile(product: p),
                    ),
                  ),
                ],
                if (RoomImportDebugUiConfig.showDebugActions) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _copyRoomImportDebugLog(navigatorContext),
                    child: const Text('デバッグログをコピー'),
                  ),
                  if (startDeepCollectsBatch != null &&
                      result.collectsIncompleteExplore) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final next = await startDeepCollectsBatch();
                        if (!navigatorContext.mounted || next == null) return;
                        await presentPostImportUi(
                          navigatorContext,
                          next,
                          startBatch: startBatch,
                          startDeepCollectsBatch: startDeepCollectsBatch,
                        );
                      },
                      child: const Text('さらに古い投稿を探す（debug）'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final next = await startBatch();
                      if (!navigatorContext.mounted || next == null) return;
                      await presentPostImportUi(
                        navigatorContext,
                        next,
                        startBatch: startBatch,
                        startDeepCollectsBatch: startDeepCollectsBatch,
                      );
                    },
                    child: Text(
                      'もう${RoomImportLimitPolicy.freeBatchLimit}件取り込む（debug）',
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: HomeScreenColors.homeAccentTeal,
                    foregroundColor: AppColors.textOnAccent,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!navigatorContext.mounted) return;
                      navigatorContext
                          .read<AppShellController>()
                          .openRoomCollect(initialTabIndex: 1);
                    });
                  },
                  icon: const Icon(Icons.task_alt_rounded, size: 22),
                  label: const Text(
                    'コレ済一覧を見る',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeScreenColors.homeAccentTeal,
                  ),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _importResultSheetCopyLogLine(RoomSyncResult r) {
    final imported = r.newlyCollectedCount;
    final succ = r.postImportEnrichSuccessCount;
    final fail = r.postImportEnrichFailCount ?? 0;
    final rem = r.postImportEnrichRemainingImportedPending ?? 0;
    final unclear = fail + rem;
    if (succ == null || imported <= 0) {
      return 'imported=$imported enrichSuccess=${succ ?? '-'} enrichFailed=$fail '
          'remaining=$rem userMessage=skippedEnrichCopy';
    }
    final userMessage = unclear == 0
        ? 'allEnriched'
        : (succ <= 0 ? 'noneEnriched' : 'partial_$succ');
    return 'imported=$imported enrichSuccess=$succ enrichFailed=$fail '
        'remaining=$rem userMessage=$userMessage';
  }

  static String _heroOutcomeLine(RoomSyncResult r) {
    final n = r.newlyCollectedCount;
    final add = r.roomUrlAddedCount;
    if (n > 0) return '$n件を取り込みました';
    if (add > 0) return 'ROOMページを$add件紐付けました';
    if (r.failedCount > 0 && r.processedCount == 0) {
      return '追加できませんでした';
    }
    if (r.processedCount == 0) {
      return '新しい投稿は見つかりませんでした';
    }
    return '追加はありませんでした';
  }
}

String _importPreviewPriceLabel(RakutenManagedProduct product) {
  if (product.itemPrice > 0) {
    return RoomColleProductListCardLayout.formatPriceYen(product.itemPrice);
  }
  return '価格：売り切れ／販売停止の可能性';
}

class _ImportedProductPreviewTile extends StatelessWidget {
  const _ImportedProductPreviewTile({required this.product});

  final RakutenManagedProduct product;

  static ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeAccentTeal,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: HomeScreenColors.homeAccentTeal.withValues(alpha: 0.85),
        width: 1.2,
      ),
      elevation: 0,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = product.itemName.trim().isEmpty
        ? '（タイトル未取得）'
        : product.itemName.trim();
    final provider = context.read<RakutenManagedProductProvider>();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.65)),
        color: AppColors.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: ProductImageResolve.displayImageUrlForManaged(
                              product,
                            ).isNotEmpty
                        ? Image.network(
                            ProductImageResolve.displayImageUrlForManaged(
                              product,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _thumbPlaceholder(theme),
                          )
                        : _thumbPlaceholder(theme),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _importPreviewPriceLabel(product),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: product.itemPrice > 0
                              ? HomeScreenColors.homeAccentTeal
                              : AppColors.textSecondary,
                          fontSize: product.itemPrice > 0 ? null : 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              final chip = RoomReactionStatusDisplay.chipLabelForProduct(
                                product,
                              );
                              final isReaction = chip == '反応あり';
                              final color = isReaction
                                  ? HomeScreenColors.homeAccentTeal
                                  : (chip == '未確認'
                                        ? AppColors.textTertiary
                                        : HomeScreenColors.homeSuccess);
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    chip,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (product.roomLikeCount != null)
                            Text(
                              '♡${product.roomLikeCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: product.roomLikeCount! > 0
                                    ? HomeScreenColors.homeAccentTeal
                                    : AppColors.textTertiary,
                              ),
                            ),
                          if (product.roomCommentCount != null)
                            Text(
                              '💬${product.roomCommentCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: product.roomCommentCount! > 0
                                    ? HomeScreenColors.homeAccentTeal
                                    : AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: product.roomUrl.trim().isEmpty
                      ? null
                      : () => AppActionService.openUrl(
                          context,
                          url: product.roomUrl.trim(),
                        ),
                  style: _outlineButtonStyle(),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: HomeScreenColors.homeAccentTeal,
                  ),
                  label: const Text('ROOMで見る'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final err = await provider.openRakutenItemPage(
                      context,
                      product.productId,
                    );
                    if (!context.mounted || err == null) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err)));
                  },
                  style: _outlineButtonStyle(),
                  icon: Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: HomeScreenColors.homeAccentTeal,
                  ),
                  label: const Text('楽天で見る'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _thumbPlaceholder(ThemeData theme) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textTertiary,
        size: 26,
      ),
    );
  }
}
