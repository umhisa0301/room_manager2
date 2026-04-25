import 'package:flutter/material.dart';

import 'app_button.dart';

/// ホームの主CTAの強調度。[hero] は最優先導線（楽天で検索）向け。
enum HomePrimaryActionEmphasis { standard, hero }

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

  static const double height = 48;
  static const double heightHero = 52;
  static const double iconSize = 22;
  static const double iconSizeHero = 24;

  double get _height =>
      emphasis == HomePrimaryActionEmphasis.hero ? heightHero : height;

  double get _iconSize =>
      emphasis == HomePrimaryActionEmphasis.hero ? iconSizeHero : iconSize;

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: Icon(icon, size: _iconSize),
      height: _height,
    );
  }
}
