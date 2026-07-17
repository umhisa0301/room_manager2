import 'package:flutter/material.dart';

/// アプリ共通のモーション定義（Duration / Curve / reduce motion）。
///
/// AnimationController やグローバル状態は持たない。Implicit Animation 向けの
/// 共通定数と、[MediaQuery.disableAnimationsOf] を考慮した duration 解決のみ。
abstract final class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;

  /// reduce motion 設定時は [Duration.zero] を返す。
  static Duration durationOf(BuildContext context, Duration duration) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return duration;
  }

  /// reduce motion 設定時は true。
  static bool reduceMotionOf(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }
}
