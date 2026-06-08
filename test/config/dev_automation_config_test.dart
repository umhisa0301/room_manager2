import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/dev_automation_config.dart';

void main() {
  group('DevAutomationFlags', () {
    test('isEnabled combines debug path and internal release path', () {
      final debugPath =
          kDebugMode && DevAutomationConfig.kDevAutomationDartDefineEnabled;
      final internalReleasePath =
          DevAutomationConfig.kInternalReleaseAutomationEnabled;
      expect(DevAutomationFlags.isEnabled, debugPath || internalReleasePath);
    });

    test('debug path requires kDebugMode and DEV_AUTOMATION_ENABLED', () {
      if (!kDebugMode) {
        expect(
          kDebugMode && DevAutomationConfig.kDevAutomationDartDefineEnabled,
          isFalse,
        );
        return;
      }
      expect(
        kDebugMode && DevAutomationConfig.kDevAutomationDartDefineEnabled,
        DevAutomationConfig.kDevAutomationDartDefineEnabled,
      );
    });

    test('internal release path requires kReleaseMode', () {
      if (!kReleaseMode) {
        expect(DevAutomationConfig.kInternalReleaseAutomationEnabled, isFalse);
        return;
      }
      expect(
        DevAutomationConfig.kInternalReleaseAutomationEnabled,
        DevAutomationConfig.kInternalReleaseAutomationDartDefineEnabled &&
            DevAutomationConfig.kInternalReleaseAutomationToken ==
                DevAutomationConfig.expectedInternalReleaseAutomationToken,
      );
    });

    test(
      'internal release path is false when only INTERNAL_RELEASE_AUTOMATION_ENABLED is set',
      () {
        if (!kReleaseMode) return;
        if (!DevAutomationConfig.kInternalReleaseAutomationDartDefineEnabled) {
          return;
        }
        if (DevAutomationConfig.kInternalReleaseAutomationToken ==
            DevAutomationConfig.expectedInternalReleaseAutomationToken) {
          return;
        }
        expect(DevAutomationConfig.kInternalReleaseAutomationEnabled, isFalse);
      },
    );

    test(
      'internal release path is false when only INTERNAL_RELEASE_AUTOMATION_TOKEN is set',
      () {
        if (!kReleaseMode) return;
        if (DevAutomationConfig.kInternalReleaseAutomationDartDefineEnabled) {
          return;
        }
        if (DevAutomationConfig.kInternalReleaseAutomationToken.isEmpty) {
          return;
        }
        expect(DevAutomationConfig.kInternalReleaseAutomationEnabled, isFalse);
      },
    );

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
