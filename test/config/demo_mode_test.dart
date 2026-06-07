import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/demo_mode.dart';

void main() {
  group('showUrlAddEntryPoint', () {
    test('requires kDebugMode and dart-define', () {
      expect(
        showUrlAddEntryPoint,
        kDebugMode && kShowUrlAddEntryPointDartDefineEnabled,
      );
    });

    test('is false when dart-define is not set (default test run)', () {
      if (kShowUrlAddEntryPointDartDefineEnabled) return;
      expect(showUrlAddEntryPoint, isFalse);
    });
  });
}
