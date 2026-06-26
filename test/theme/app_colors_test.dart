import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('主要アクセントはピンク系ではなくティール系', () {
      expect(AppColors.accentPrimary, const Color(0xFF0F766E));
      expect(AppColors.accentPrimary, isNot(const Color(0xFFE91E63)));
      expect(AppColors.accentPrimary, isNot(const Color(0xFFE91E8C)));
    });

    test('アクセント薄色はピンク系ではない', () {
      expect(AppColors.accentLight, const Color(0xFFEAFBF7));
      expect(AppColors.accentLightest, const Color(0xFFF0FDF9));
    });

    test('サブアクセントもピンク系ではない', () {
      expect(AppColors.accentSecondary, const Color(0xFF0E7490));
      expect(AppColors.accentSecondary, isNot(const Color(0xFFFF6090)));
    });
  });
}
