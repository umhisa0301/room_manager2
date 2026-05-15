import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../config/room_import_enrichment_verify_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_sync_result.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/room_sync_cursor_repository.dart';
import '../services/app_action_service.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_enrichment_cooldown_store.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/room_sync_service.dart';
import '../state/bulk_operation_state_controller.dart';
import '../utils/room_reaction_status_display.dart';
import '../utils/room_sync_log.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
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
      final svc = RoomImportMetadataEnrichmentService(
        searchRepository: searchRepo,
        productRepository: productRepo,
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
            child: Text(result.fatalErrorMessage!.trim()),
          ),
          actions: [
            if (kDebugMode) ...[
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
    if (!context.mounted) return;
    if (result.postImportEnrichSuccessCount != null) {
      final suc = result.postImportEnrichSuccessCount ?? 0;
      final fail = result.postImportEnrichFailCount ?? 0;
      final pendingAll =
          RoomImportMetadataEnrichmentService.countPendingEnrichment(
            context.read<RakutenManagedProductProvider>().items,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '取り込みが完了しました：成功$suc件 / 失敗$fail件\nショップ名・ジャンル未確認：$pendingAll件',
          ),
        ),
      );
    }
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

    final repo = context.read<RakutenManagedProductRepository>();
    final cursorRepo = context.read<RoomSyncCursorRepository>();
    final service = RoomSyncService(
      repository: repo,
      roomSyncCursorRepository: cursorRepo,
    );
    final limit = RoomImportLimitPolicy.effectiveBatchLimit();

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
    final service = RoomSyncService(
      repository: repo,
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
    roomImportResultSheetRefreshLog(
      'newlyImportedProductIds=${ids.join(',')} refetchedCount=${rows.length} '
      'withImageCount=$withImage withPriceCount=$withPrice '
      'displayProductIds=${display.map((e) => e.productId).join(',')}',
    );
    for (final p in display) {
      roomImportResultSheetItemLog(
        'productId=${p.productId} title=${p.itemName.trim().isEmpty ? '(empty)' : p.itemName.trim()} '
        'hasImage=${p.imageUrl.trim().isNotEmpty} price=${p.itemPrice} '
        'formattedPrice=${p.itemPrice > 0 ? RoomColleProductListCardLayout.formatPriceYen(p.itemPrice) : '-'} '
        'shopName=${p.shopName.trim()} genreName=${p.genreName.trim()}',
      );
    }
    return display;
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
        final pendingEnrich =
            RoomImportMetadataEnrichmentService.countPendingEnrichment(
              ctx.read<RakutenManagedProductProvider>().items,
            );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '取り込み結果',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  result.newlyCollectedCount > 0
                      ? '${result.newlyCollectedCount}件追加しました'
                      : _heroOutcomeLine(result),
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  result.postImportEnrichSuccessCount != null
                      ? '新しい商品をコレ済に追加し、商品情報の初回取得を行いました。'
                      : '新しい商品をコレ済に追加しました。初回の商品情報取得はバッチ完了後に続けて行われます。',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (result.postImportEnrichSuccessCount != null &&
                    result.newlyCollectedCount > 0) ...[
                  const SizedBox(height: 12),
                  ..._importSheetEnrichUserLines(ctx, result),
                ],
                const SizedBox(height: 22),
                if (kDebugMode)
                  LayoutBuilder(
                    builder: (context, constraints) {
                    const spacing = 12.0;
                    final w = constraints.maxWidth;
                    final half = w > spacing ? (w - spacing) / 2 : w;
                    Widget cell(_SummaryMiniCard c) =>
                        SizedBox(width: half, child: c);
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        cell(
                          _SummaryMiniCard(
                            label: '新しく追加',
                            value: result.newlyCollectedCount,
                            emphasize: result.newlyCollectedCount > 0,
                          ),
                        ),
                        cell(
                          _SummaryMiniCard(
                            label: '確認済み',
                            value: result.listingCheckedCount,
                          ),
                        ),
                        cell(
                          _SummaryMiniCard(
                            label: 'すでに登録済み',
                            value: result.listingSyncedSkipCount,
                          ),
                        ),
                        cell(
                          _SummaryMiniCard(
                            label: '失敗',
                            value: result.failedCount,
                            emphasize: result.failedCount > 0,
                            emphasizeColor: AppColors.error,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (result.roomUrlAddedCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ROOMページ紐付け：${result.roomUrlAddedCount}件',
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '※ROOM本体の投稿数には加算しません',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.35,
                  ),
                ),
                if (result.collectsPagesFetched > 0 ||
                    result.collectsIncompleteExplore ||
                    (result.collectsStopReason != null &&
                        result.collectsStopReason!.trim().isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ROOM投稿の探索（collects API）',
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '探索ページ：${result.collectsPagesFetched}ページ · '
                            'モード：${result.collectsExploreModeLabel == 'deep' ? '深掘り' : '通常'}',
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (result.collectsStopReason != null &&
                              result.collectsStopReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '終了理由：${result.collectsStopReason}',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                          if (result.collectsIncompleteExplore) ...[
                            const SizedBox(height: 8),
                            Text(
                              '未取り込みの投稿がまだ残っている可能性があります。'
                              '古い投稿をさらに探す場合は、マイページの'
                              '「さらに古い投稿を探す」から実行できます。',
                              style: Theme.of(ctx).textTheme.bodyMedium
                                  ?.copyWith(
                                    height: 1.45,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (pendingEnrich > 0) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '商品情報（楽天API）',
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ショップ名・ジャンル未確認が $pendingEnrich 件あります。'
                            'ホームまたはマイページの「ショップ名・ジャンルを再確認」から実行できます。',
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (displayImported.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    '今回追加した商品（一部）',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '最新3件のみ表示しています。すべて見る場合はコレ済一覧へ。',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
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
                if (result.reactionHighlightSamples.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    '反応があった商品',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'いいね・コメントが付いていた商品です（最大3件）',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...result.reactionHighlightSamples
                      .take(3)
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ImportedProductPreviewTile(product: p),
                        ),
                      ),
                ],
                if (result.failedCount > 0 &&
                    result.failedRoomUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '取り込めなかったROOMページ（先頭3件）',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...result.failedRoomUrls
                      .take(3)
                      .map(
                        (u) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            u,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    '開発用（debug のみ）',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _copyRoomImportDebugLog(navigatorContext),
                    child: const Text('デバッグログをコピー'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _showRoomImportDebugLogDialog(ctx),
                    child: const Text('デバッグログを表示'),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: AppColors.accentPrimary,
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
                    'コレ済をすべて見る',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                if (startDeepCollectsBatch != null &&
                    result.collectsIncompleteExplore) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: AppColors.accentPrimary,
                    ),
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
                    icon: const Icon(Icons.manage_search_rounded, size: 20),
                    label: const Text('さらに古い投稿を探す（時間がかかります）'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: AppColors.accentPrimary,
                  ),
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
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  label: Text('もう${RoomImportLimitPolicy.freeBatchLimit}件取り込む'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
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

  static List<Widget> _importSheetEnrichUserLines(
    BuildContext ctx,
    RoomSyncResult r,
  ) {
    final succ = r.postImportEnrichSuccessCount!;
    final fail = r.postImportEnrichFailCount ?? 0;
    final rem = r.postImportEnrichRemainingImportedPending ?? 0;
    final unclear = fail + rem;
    final secondary = Theme.of(ctx).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        );
    if (unclear == 0) {
      return [
        Text(
          'すべての商品情報を確認できました',
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
        ),
      ];
    }
    if (succ <= 0) {
      return [
        Text(
          '$unclear件は商品情報をこの場では確認できませんでした',
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '未確認の商品は「ショップ名・ジャンルを再確認」から再確認できます',
          textAlign: TextAlign.center,
          style: secondary,
        ),
      ];
    }
    return [
      Text(
        '$succ件は商品情報まで確認できました',
        textAlign: TextAlign.center,
        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
      ),
      const SizedBox(height: 6),
      Text(
        '$unclear件はあとで再確認できます',
        textAlign: TextAlign.center,
        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        '未確認の商品は「ショップ名・ジャンルを再確認」から再確認できます',
        textAlign: TextAlign.center,
        style: secondary,
      ),
    ];
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

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.emphasizeColor,
  });

  final String label;
  final int value;
  final bool emphasize;
  final Color? emphasizeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: emphasize
          ? (emphasizeColor ?? AppColors.accentPrimary)
          : AppColors.textPrimary,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text('$value', style: valueStyle),
          ],
        ),
      ),
    );
  }
}

class _ImportedProductPreviewTile extends StatelessWidget {
  const _ImportedProductPreviewTile({required this.product});

  static const Color _roomReactionPink = Color(0xFFE91E63);

  final RakutenManagedProduct product;

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
                    child: product.imageUrl.trim().isNotEmpty
                        ? Image.network(
                            product.imageUrl.trim(),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (product.itemPrice > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          RoomColleProductListCardLayout.formatPriceYen(
                            product.itemPrice,
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
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
                                  ? _roomReactionPink
                                  : (chip == '未確認'
                                        ? AppColors.textTertiary
                                        : const Color(0xFF1B5E20));
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
                                fontWeight: FontWeight.w800,
                                color: product.roomLikeCount! > 0
                                    ? _roomReactionPink
                                    : AppColors.textTertiary,
                              ),
                            ),
                          if (product.roomCommentCount != null)
                            Text(
                              '💬${product.roomCommentCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: product.roomCommentCount! > 0
                                    ? _roomReactionPink
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
            const SizedBox(height: 10),
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
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
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
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
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
