import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/debug_log_flags.dart';
import 'package:room_manager2/utils/app_debug_log.dart';

void main() {
  group('app_debug_log emission gates', () {
    test('shouldEmitImportantDebugLog は debug ビルドでのみ true', () {
      expect(shouldEmitImportantDebugLog(), kDebugMode);
    });

    test('shouldEmitCatalogAuditLog は CATALOG_AUDIT_LOGS と debug の両方が必要', () {
      expect(
        shouldEmitCatalogAuditLog(),
        kDebugMode && DebugLogFlags.kCatalogAuditLogsEnabled,
      );
    });

    test('catalogAuditLog はフラグ無効時に no-op（例外なし）', () {
      if (DebugLogFlags.kCatalogAuditLogsEnabled) return;
      expect(() => catalogAuditLog('[TEST_CATALOG_AUDIT] noop'), returnsNormally);
    });

    test('shopDiscoveryUserActionLog は debug ビルドで no-op 例外なし', () {
      expect(
        () => shopDiscoveryUserActionLog('[TEST_USER_ACTION] noop'),
        returnsNormally,
      );
    });

    test('importantDebugLog は debug ビルドで no-op 例外なし', () {
      expect(() => importantDebugLog('[TEST_IMPORTANT] noop'), returnsNormally);
    });
  });
}
