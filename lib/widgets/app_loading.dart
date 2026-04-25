import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small loading view. Loading must confirm progress, not dominate the screen.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    this.message = '読み込み中',
    this.inline = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final String message;
  final bool inline;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: inline ? 18 : 26,
      height: inline ? 18 : 26,
      child: const CircularProgressIndicator(
        strokeWidth: 2.2,
        color: AppColors.accentPrimary,
      ),
    );

    final text = Text(
      message,
      maxLines: inline ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      textAlign: inline ? TextAlign.start : TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );

    if (inline) {
      return Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(width: 8),
            Flexible(child: text),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [spinner, const SizedBox(height: 10), text],
      ),
    );
  }
}
