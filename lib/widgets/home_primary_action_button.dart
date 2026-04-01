import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// ホームの主CTAの強調度。[hero] は最優先導線（楽天で検索）向け。
enum HomePrimaryActionEmphasis {
  standard,
  hero,
}

/// ホーム画面の主要導線用ボタン。
class HomePrimaryActionButton extends StatelessWidget {
  const HomePrimaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasis = HomePrimaryActionEmphasis.standard,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final HomePrimaryActionEmphasis emphasis;

  static const double height = 50;
  static const double heightHero = 54;
  static const double iconSize = 22;
  static const double iconSizeHero = 24;
  static const double iconLabelGap = 8;

  double get _height =>
      emphasis == HomePrimaryActionEmphasis.hero ? heightHero : height;

  double get _iconSize =>
      emphasis == HomePrimaryActionEmphasis.hero ? iconSizeHero : iconSize;

  double get _fontSize =>
      emphasis == HomePrimaryActionEmphasis.hero ? 17 : 16;

  double get _elevation =>
      emphasis == HomePrimaryActionEmphasis.hero ? 2 : 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: emphasis == HomePrimaryActionEmphasis.hero
              ? HomeScreenColors.heroCtaBackground
              : AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
          elevation: _elevation,
          shadowColor: emphasis == HomePrimaryActionEmphasis.hero
              ? HomeScreenColors.heroCtaShadow
              : AppColors.accentPrimary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: Size(double.infinity, _height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _iconSize),
            SizedBox(width: iconLabelGap),
            Text(
              label,
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
