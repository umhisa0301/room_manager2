import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 活動のプレースホルダー画面。
class ActivityPlaceholderScreen extends StatelessWidget {
  const ActivityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: AppDimensions.iconPlaceholder,
                  color: AppColors.accentPrimary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  '活動',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  '活動ログ・分析はここに表示されます',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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
