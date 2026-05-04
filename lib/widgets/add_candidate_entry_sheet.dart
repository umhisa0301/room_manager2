import 'package:flutter/material.dart';

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
      final mq = MediaQuery.of(sheetContext);
      final keyboardBottom = mq.viewInsets.bottom;
      final viewHeight = mq.size.height;
      final topBlocking = mq.padding.top;
      final availBody = (viewHeight - keyboardBottom - topBlocking).clamp(
        240.0,
        viewHeight,
      );
      final sheetHeight = (availBody * 0.78).clamp(280.0, availBody * 0.85);

      return AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardBottom),
        child: SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: RakutenSearchScreenUi.addCandidateSheetContentPadding,
              child: AddCandidateEntrySheetBody(
                onTapRakutenProductSearch: () =>
                    onTapRakutenProductSearch(sheetContext),
                onTapGenreSearch: () => onTapGenreSearch(sheetContext),
                onTapSavedShops: () => onTapSavedShops(sheetContext),
                onTapAddFromUrl: () => onTapAddFromUrl(sheetContext),
                onTapShopDiscovery: () => onTapShopDiscovery(sheetContext),
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
    required this.onTapRakutenProductSearch,
    required this.onTapGenreSearch,
    required this.onTapSavedShops,
    required this.onTapAddFromUrl,
    required this.onTapShopDiscovery,
  });

  final VoidCallback onTapRakutenProductSearch;
  final VoidCallback onTapGenreSearch;
  final VoidCallback onTapSavedShops;
  final VoidCallback onTapAddFromUrl;
  final VoidCallback onTapShopDiscovery;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '探すグループ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: HomeScreenColors.footnoteMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs / 2),
        Text(
          '候補を追加',
          style: RakutenSearchScreenUi.sectionHeadingAccent(context),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          '追加方法を選ぶと、既存の画面へ移動します',
          style: RakutenSearchScreenUi.bodyCaption(context),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.travel_explore_rounded,
          title: '楽天で商品を探す',
          description: 'キーワード検索から候補を追加します',
          onTap: onTapRakutenProductSearch,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.category_rounded,
          title: 'ジャンルから探す',
          description: 'ジャンル指定の一覧から候補を追加します',
          onTap: onTapGenreSearch,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.storefront_rounded,
          title: '保存ショップから探す',
          description: '登録済みショップの商品一覧から探します',
          onTap: onTapSavedShops,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.link_rounded,
          title: 'URLから追加',
          description: '楽天市場のURLからコードを読み取り検索します',
          onTap: onTapAddFromUrl,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.hiking_rounded,
          title: 'ショップ発掘',
          description: '新しいショップを探して候補追加につなげます',
          onTap: onTapShopDiscovery,
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
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
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
