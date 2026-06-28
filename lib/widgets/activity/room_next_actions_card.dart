import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../navigation/rakuten_search_navigator.dart';
import '../../screens/today_recommendations_screen.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/bulk_operation_state_controller.dart';
import '../../state/room_import_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/activity_screen_tokens.dart';
import '../../utils/analytics_shop_search_launcher.dart';
import '../../utils/room_next_action_advisor.dart';
import '../../widgets/app_card.dart';
import '../../widgets/operation_confirm_dialog.dart';
import '../../widgets/room_post_import_flow.dart';
import 'activity_screen_layout.dart';

/// 分析タブ最上部の「次にやること」カード。
class RoomNextActionsCard extends StatelessWidget {
  const RoomNextActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final productItems = context.watch<RakutenManagedProductProvider>().items;
    final candidateCount = productItems
        .where((e) => e.status == RakutenManagedProductStatus.candidate)
        .length;
    final now = DateTime.now();
    final todayPosts = productItems.where((e) {
      if (e.status != RakutenManagedProductStatus.done) return false;
      final d = e.doneAt;
      if (d == null) return false;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final actions = RoomNextActionAdvisor.suggest(
      items: productItems,
      candidateCount: candidateCount,
      todayPostCount: todayPosts,
    );
    if (actions.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '次にやること',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ActionRow(action: actions[i]),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final RoomNextAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            action.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            action.reason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _onCta(context),
              style: ActivityScreenUi.compactOutlinedButtonStyle(
                theme: Theme.of(context),
              ),
              child: Text(action.ctaLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCta(BuildContext context) async {
    switch (action.type) {
      case RoomNextActionType.exploreSimilarProducts:
        final gid = action.genreId?.trim() ?? '';
        await openRakutenSearchScreen(
          context,
          initialMode: RakutenSearchInitialMode.genre,
          initialGenreId: gid.isNotEmpty ? gid : null,
        );
      case RoomNextActionType.exploreShopProducts:
        final sc = action.shopCode?.trim() ?? '';
        if (sc.isNotEmpty) {
          await AnalyticsShopSearchLauncher.launchShopSearch(
            context,
            shopCode: sc,
            shopName: action.shopName ?? '',
            screen: 'roomNextActionsCard',
          );
        } else {
          await AnalyticsShopSearchLauncher.launchTopShopSearch(
            context,
            items: context.read<RakutenManagedProductProvider>().items,
            screen: 'roomNextActionsCard',
          );
        }
      case RoomNextActionType.confirmProductMetadata:
        await RoomPostImportFlow.runManualPendingRoomImportMetadataEnrich(
          context,
        );
      case RoomNextActionType.openTodayRecommendations:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const TodayRecommendationsScreen(),
          ),
        );
      case RoomNextActionType.importRoomPosts:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ROOM投稿を取り込む'),
            content: const Text(
              'ROOM投稿を取り込みます。\n'
              '更新が終わるまで、探す・候補追加は一時停止します。\n'
              'よろしいですか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('開始する'),
              ),
            ],
          ),
        );
        if (ok != true || !context.mounted) return;
        if (kDebugMode) {
          debugPrint(
            '[OPERATION_CONFIRM_DIALOG] operation=roomImport shown=true accepted=true',
          );
        }
        final ctl = context.read<RoomImportController>();
        final result = await ctl.runImport(context);
        if (!context.mounted || result == null) return;
        await RoomPostImportFlow.presentPostImportUi(
          context,
          result,
          startBatch: () => ctl.runImport(context),
        );
      case RoomNextActionType.checkReactions:
        final ctl = context.read<RoomImportController>();
        final bulk = context.read<BulkOperationStateController>();
        final syncBusy = ctl.isRunning ||
            bulk.isMetadataEnriching ||
            bulk.isRoomReactionSyncRunning;
        if (syncBusy || bulk.isAnyBlockingOperationRunning) {
          if (kDebugMode) {
            debugPrint(
              '[ROOM_REACTION_SYNC_START_GUARD] screen=analytics '
              'blockedByBusy=true confirmed=false',
            );
          }
          return;
        }
        final confirmed = await showRoomReactionSyncConfirmDialog(
          context,
          screen: 'analytics',
        );
        if (kDebugMode) {
          debugPrint(
            '[ROOM_REACTION_SYNC_START_GUARD] screen=analytics '
            'blockedByBusy=false confirmed=$confirmed',
          );
        }
        if (!confirmed || !context.mounted) return;
        await ctl.runReactionSync(context);
    }
  }
}
