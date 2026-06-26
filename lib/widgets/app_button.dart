import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary CTA button. Brand teal is intentionally concentrated here.
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
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    );

    return Semantics(button: true, label: label, child: button);
  }
}

/// 外部ブラウザ起動など、主CTAと並ぶアウトライン（高さ・角丸は [AppPrimaryButton] に揃える）。
class AppOutlineButton extends StatelessWidget {
  const AppOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: AppColors.textTertiary,
          side: BorderSide(
            color: enabled
                ? AppColors.accentPrimary.withValues(alpha: 0.75)
                : AppColors.divider,
          ),
          elevation: 0,
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
            color: AppColors.accentPrimary,
          ),
        ),
        icon: icon ?? const SizedBox.shrink(),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: AppTextStyles.button.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              color: enabled ? AppColors.accentPrimary : AppColors.textTertiary,
            ),
          ),
        ),
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
