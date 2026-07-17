import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/theme/app_motion.dart';
import 'package:flutter/material.dart';

void main() {
  group('AppMotion constants', () {
    test('defines expected durations and curves', () {
      expect(AppMotion.fast, const Duration(milliseconds: 160));
      expect(AppMotion.normal, const Duration(milliseconds: 240));
      expect(AppMotion.emphasized, const Duration(milliseconds: 360));
      expect(AppMotion.standard, Curves.easeOutCubic);
      expect(AppMotion.emphasizedCurve, Curves.easeInOutCubic);
    });
  });
}
