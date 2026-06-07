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
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusCard),
      ),
    ),
    builder: (sheetContext) {
      final keyboardBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardBottom),
        child: SafeArea(
          top: false,
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
          '探すグループ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: HomeScreenColors.footnoteMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs / 2),
        Text(
          '候補を追加（探す）',
          style: RakutenSearchScreenUi.sectionHeadingAccent(context),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          '目的に合わせて画面へ移動します（保存ショップで探す／ショップ発掘など）。',
          style: RakutenSearchScreenUi.bodyCaption(context),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Opacity(
          opacity: roomTourSearchBlocked ? 0.45 : 1,
          child: AddCandidateEntrySheetMenuItem(
            key: const Key('add_candidate_rakuten_product'),
            icon: Icons.travel_explore_rounded,
            title: '楽天で商品を探す',
            description: 'キーワード検索から候補を追加します',
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
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: RakutenSearchScreenUi.addCandidateSheetItemPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusButton,
                  ),
                ),
                child: Icon(icon, color: AppColors.accentPrimary),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      softWrap: true,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
