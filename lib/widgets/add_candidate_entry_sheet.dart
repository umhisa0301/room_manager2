import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../state/bulk_operation_state_controller.dart';
import '../utils/room_sync_log.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';

/// シート内 [BuildContext]（通常は `showModalBottomSheet` の builder 引数）を渡すアクション。
typedef AddCandidateEntrySheetAction =
    Future<void> Function(BuildContext sheetContext);

/// 「候補を追加」入口5件のモーダルボトムシート（見た目・文言のみ共通化）。
///
/// 各アクションは呼び出し元で定義する（シートを閉じる・遷移する等の挙動は共通化しない）。
Future<void> showAddCandidateEntryBottomSheet({
  required BuildContext context,
  required AddCandidateEntrySheetAction onTapRakutenProductSearch,
  required AddCandidateEntrySheetAction onTapGenreSearch,
  required AddCandidateEntrySheetAction onTapSavedShops,
  required AddCandidateEntrySheetAction onTapAddFromUrl,
  required AddCandidateEntrySheetAction onTapShopDiscovery,
}) {
  if (!showUrlAddEntryPoint) {
    urlAddEntryVisibilityLog(
      visible: false,
      reason: 'temporarilyHiddenByUxPolicy',
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final keyboardBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardBottom),
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HomeScreenColors.homeCardFill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusCard),
              ),
              border: Border.all(color: HomeScreenColors.homeCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(0, -2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: SingleChildScrollView(
              key: const Key('add_candidate_sheet'),
              padding: RakutenSearchScreenUi.addCandidateSheetContentPadding,
              child: Consumer<BulkOperationStateController>(
                builder: (context, bulk, _) {
                  final blocked = bulk.isRoomTourSearchBlocking;
                  return AddCandidateEntrySheetBody(
                    roomTourSearchBlocked: blocked,
                    onTapRakutenProductSearch: () =>
                        onTapRakutenProductSearch(sheetContext),
                    onTapGenreSearch: () => onTapGenreSearch(sheetContext),
                    onTapSavedShops: () => onTapSavedShops(sheetContext),
                    onTapAddFromUrl: () => onTapAddFromUrl(sheetContext),
                    onTapShopDiscovery: () => onTapShopDiscovery(sheetContext),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 入口5件の本文（タイトル・説明・5行）。シートの外枠は [showAddCandidateEntryBottomSheet] 側。
class AddCandidateEntrySheetBody extends StatelessWidget {
  const AddCandidateEntrySheetBody({
    super.key,
    required this.roomTourSearchBlocked,
    required this.onTapRakutenProductSearch,
    required this.onTapGenreSearch,
    required this.onTapSavedShops,
    required this.onTapAddFromUrl,
    required this.onTapShopDiscovery,
  });

  final bool roomTourSearchBlocked;
  final VoidCallback onTapRakutenProductSearch;
  final VoidCallback onTapGenreSearch;
  final VoidCallback onTapSavedShops;
  final VoidCallback onTapAddFromUrl;
  final VoidCallback onTapShopDiscovery;

  bool _blockIfRoomTourBusy(BuildContext context, String blockedAction) {
    if (!roomTourSearchBlocked) return false;
    final bulk = context.read<BulkOperationStateController>();
    roomSyncUiGuardLog(
      'blockedAction=$blockedAction currentJob=${bulk.roomTourBlockingJobLabel} '
      'message=searchPaused',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          BulkOperationStateController.roomTourSearchBlockedUserMessage,
        ),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (roomTourSearchBlocked) ...[
          Text(
            'ROOM同期中です。新しい商品検索は同期完了後に利用できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.titlePrimary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        Text(
          '候補を追加',
          style: RakutenSearchScreenUi.screenTitleStyle(context),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          '探したい方法を選んでください',
          style: RakutenSearchScreenUi.screenSubtitleStyle(context),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Opacity(
          opacity: roomTourSearchBlocked ? 0.45 : 1,
          child: AddCandidateEntrySheetMenuItem(
            key: const Key('add_candidate_rakuten_product'),
            icon: Icons.travel_explore_rounded,
            title: '楽天で商品を探す',
            description: 'キーワードで商品を検索',
            isPrimaryEntry: true,
            onTap: () {
              if (_blockIfRoomTourBusy(context, 'search')) return;
              onTapRakutenProductSearch();
            },
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Opacity(
          opacity: roomTourSearchBlocked ? 0.45 : 1,
          child: AddCandidateEntrySheetMenuItem(
            icon: Icons.category_rounded,
            title: 'ジャンルから探す',
            description: 'ジャンル指定の一覧から候補を追加します',
            onTap: () {
              if (_blockIfRoomTourBusy(context, 'search')) return;
              onTapGenreSearch();
            },
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Opacity(
          opacity: roomTourSearchBlocked ? 0.45 : 1,
          child: AddCandidateEntrySheetMenuItem(
            icon: Icons.storefront_rounded,
            title: '保存ショップで探す',
            description: '保存したショップを選び、その店内だけをキーワード検索します',
            onTap: () {
              if (_blockIfRoomTourBusy(context, 'search')) return;
              onTapSavedShops();
            },
          ),
        ),
        if (showUrlAddEntryPoint) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          Opacity(
            opacity: roomTourSearchBlocked ? 0.45 : 1,
            child: AddCandidateEntrySheetMenuItem(
              key: const Key('add_candidate_from_url'),
              icon: Icons.link_rounded,
              title: 'URLから追加',
              description: '商品ページのURLから検索します',
              onTap: () {
                if (_blockIfRoomTourBusy(context, 'urlAdd')) return;
                onTapAddFromUrl();
              },
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.spacingSm),
        Opacity(
          opacity: roomTourSearchBlocked ? 0.45 : 1,
          child: AddCandidateEntrySheetMenuItem(
            icon: Icons.hiking_rounded,
            title: 'ショップ発掘',
            description: '新しいショップを見つけて保存します（店内検索の材料になります）',
            onTap: () {
              if (_blockIfRoomTourBusy(context, 'search')) return;
              onTapShopDiscovery();
            },
          ),
        ),
      ],
    );
  }
}

class AddCandidateEntrySheetMenuItem extends StatelessWidget {
  const AddCandidateEntrySheetMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isPrimaryEntry = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isPrimaryEntry;

  @override
  Widget build(BuildContext context) {
    final accent = HomeScreenColors.homeAccentTeal;
    if (isPrimaryEntry) {
      return Material(
        color: accent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Padding(
            padding: RakutenSearchScreenUi.addCandidateSheetItemPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: HomeScreenColors.homeCardBorder),
          ),
          child: Padding(
          padding: RakutenSearchScreenUi.addCandidateSheetItemPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HomeScreenColors.homeAccentTealLight,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusButton,
                  ),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: HomeScreenColors.homeTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: HomeScreenColors.homeTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: HomeScreenColors.homeTextSecondary,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
