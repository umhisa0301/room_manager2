import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/dev_automation_config.dart';

void main() {
  group('DevAutomationFlags', () {
    test('isEnabled requires kDebugMode and dart-define', () {
      expect(
        DevAutomationFlags.isEnabled,
        kDebugMode && DevAutomationConfig.kDevAutomationDartDefineEnabled,
      );
    });

    test('ensureDevAutomationAvailable throws when disabled', () {
      if (DevAutomationFlags.isEnabled) return;
      expect(ensureDevAutomationAvailable, throwsStateError);
    });

    test('ensureDevAutomationAvailable succeeds when enabled', () {
      if (!DevAutomationFlags.isEnabled) return;
      expect(ensureDevAutomationAvailable, returnsNormally);
    });
  });
}
