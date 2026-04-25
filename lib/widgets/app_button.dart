import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary CTA button. Brand pink is intentionally concentrated here.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: AppColors.textOnAccent,
          backgroundColor: AppColors.accentPrimary,
          disabledForegroundColor: AppColors.textOnAccent.withValues(
            alpha: 0.72,
          ),
          disabledBackgroundColor: AppColors.accentPrimary.withValues(
            alpha: 0.34,
          ),
          elevation: 1.2,
          shadowColor: AppColors.accentPrimary.withValues(alpha: 0.22),
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnAccent.withValues(alpha: 0.9),
                ),
              )
            : icon ?? const SizedBox.shrink(),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    return Semantics(button: true, label: label, child: button);
  }
}

/// Secondary action for navigation, filter chips, or helper actions.
/// It must not compete with the primary CTA.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 40,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(data: const IconThemeData(size: 16), child: icon!),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: AppColors.textTertiary,
          side: BorderSide(color: AppColors.divider.withValues(alpha: 0.82)),
          elevation: 0,
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        child: child,
      ),
    );

    return Semantics(button: true, label: label, child: button);
  }
}
