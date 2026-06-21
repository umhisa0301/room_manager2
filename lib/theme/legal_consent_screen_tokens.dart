import 'package:flutter/material.dart';

import 'mypage_screen_tokens.dart';

/// 初回同意画面「はじめる前に」の配色（マイページ系ティール基調）。
abstract final class LegalConsentScreenUi {
  LegalConsentScreenUi._();

  static const Color canvas = MyPageScreenUi.canvas;
  static const Color primary = MyPageScreenUi.primary;

  static ThemeData overlayTheme(ThemeData base) {
    return MyPageScreenUi.overlayTheme(base).copyWith(
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return null;
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: MyPageScreenUi.primaryButtonStyle(height: 52),
      ),
    );
  }
}
