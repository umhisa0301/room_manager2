import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// マイページのプレースホルダー画面。
class MypagePlaceholderScreen extends StatelessWidget {
  const MypagePlaceholderScreen({super.key});

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
                  Icons.person_outline,
                  size: AppDimensions.iconPlaceholder,
                  color: AppColors.accentPrimary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  'マイページ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  '設定・プロフィールはここに表示されます',
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
