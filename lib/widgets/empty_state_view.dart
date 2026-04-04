import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// リストが空のときに表示する共通の空状態UI。
/// アイコン・メッセージ・補足文を指定でき、商品管理・コメント等で再利用可能。
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.message,
    this.detail,
    this.icon,
    this.iconColor,
  });

  /// メインの案内文（例:「まだ商品がありません」）
  final String message;

  /// 補足文（例:「右下ボタンから追加」）
  final String? detail;

  /// 中央に表示するアイコン（未指定時は Icons.inbox_outlined）
  final IconData? icon;

  /// アイコンの色（未指定時はアクセントの薄い色）
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = icon ?? Icons.inbox_outlined;
    final effectiveColor =
        iconColor ?? AppColors.accentPrimary.withValues(alpha: 0.6);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.screenPaddingH * 1.5,
          vertical: AppDimensions.screenPaddingV * 2,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              effectiveIcon,
              size: AppDimensions.iconPlaceholder,
              color: effectiveColor,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
