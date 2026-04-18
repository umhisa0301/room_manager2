import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// シート内 [BuildContext]（通常は `showModalBottomSheet` の builder 引数）を渡すアクション。
typedef AddCandidateEntrySheetAction =
    Future<void> Function(BuildContext sheetContext);

/// 「候補を追加」入口3択のモーダルボトムシート（見た目・文言のみ共通化）。
///
/// 各アクションは呼び出し元で定義する（シートを閉じる・遷移する等の挙動は共通化しない）。
Future<void> showAddCandidateEntryBottomSheet({
  required BuildContext context,
  required AddCandidateEntrySheetAction onTapRakutenProductSearch,
  required AddCandidateEntrySheetAction onTapSavedShops,
  required AddCandidateEntrySheetAction onTapShopDiscovery,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: false,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusCard),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingMd,
              AppDimensions.spacingSm,
              AppDimensions.spacingMd,
              AppDimensions.spacingMd,
            ),
            child: AddCandidateEntrySheetBody(
              onTapRakutenProductSearch: () =>
                  onTapRakutenProductSearch(sheetContext),
              onTapSavedShops: () => onTapSavedShops(sheetContext),
              onTapShopDiscovery: () => onTapShopDiscovery(sheetContext),
            ),
          ),
        ),
      );
    },
  );
}

/// 入口3択の本文（タイトル・説明・3行）。シートの外枠は [showAddCandidateEntryBottomSheet] 側。
class AddCandidateEntrySheetBody extends StatelessWidget {
  const AddCandidateEntrySheetBody({
    super.key,
    required this.onTapRakutenProductSearch,
    required this.onTapSavedShops,
    required this.onTapShopDiscovery,
  });

  final VoidCallback onTapRakutenProductSearch;
  final VoidCallback onTapSavedShops;
  final VoidCallback onTapShopDiscovery;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('候補を追加', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          '追加方法を選ぶと、既存の画面へ移動します',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.travel_explore_rounded,
          title: '楽天で商品を探す',
          description: '楽天検索から候補を追加します',
          onTap: onTapRakutenProductSearch,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.storefront_rounded,
          title: '保存ショップから探す',
          description: '登録済みショップから候補を探します',
          onTap: onTapSavedShops,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AddCandidateEntrySheetMenuItem(
          icon: Icons.hiking_rounded,
          title: 'ショップ発掘を開く',
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingMd,
          ),
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
