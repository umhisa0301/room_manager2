import '../config/debug_log_flags.dart';
import 'app_debug_log.dart';

/// shopDiscovery ProductCatalog upsert の非同期タイミング追跡（監査用）。
abstract final class ProductCatalogUpsertTimingRegistry {
  static DateTime? shopDiscoveryScheduledAt;
  static DateTime? shopDiscoveryCompletedAt;
  static int? shopDiscoveryCatalogCountBefore;
  static int? shopDiscoveryCatalogCountAfter;
  static int? shopDiscoveryDurationMs;

  static void markShopDiscoveryScheduled({required int catalogCountBefore}) {
    shopDiscoveryScheduledAt = DateTime.now();
    shopDiscoveryCatalogCountBefore = catalogCountBefore;
    shopDiscoveryCompletedAt = null;
    shopDiscoveryCatalogCountAfter = null;
    shopDiscoveryDurationMs = null;
  }

  static void markShopDiscoveryCompleted({required int catalogCountAfter}) {
    final scheduled = shopDiscoveryScheduledAt;
    shopDiscoveryCompletedAt = DateTime.now();
    shopDiscoveryCatalogCountAfter = catalogCountAfter;
    if (scheduled != null) {
      shopDiscoveryDurationMs =
          shopDiscoveryCompletedAt!.difference(scheduled).inMilliseconds;
    }
  }

  static bool readUsesFreshCatalog(DateTime readAt) {
    final scheduled = shopDiscoveryScheduledAt;
    final completed = shopDiscoveryCompletedAt;
    if (scheduled == null) return true;
    if (completed == null) return false;
    return !readAt.isBefore(completed);
  }

  static void logUpsertTimingIfEnabled() {
    if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
    final scheduled = shopDiscoveryScheduledAt;
    final completed = shopDiscoveryCompletedAt;
    catalogAuditLog(
      '[PRODUCT_CATALOG_UPSERT_TIMING] phase=shopDiscovery '
      'scheduledAt=${scheduled?.toIso8601String() ?? '-'} '
      'completedAt=${completed?.toIso8601String() ?? '-'} '
      'durationMs=${shopDiscoveryDurationMs ?? '-'} '
      'catalogCountBefore=${shopDiscoveryCatalogCountBefore ?? '-'} '
      'catalogCountAfter=${shopDiscoveryCatalogCountAfter ?? '-'}',
    );
  }

  static void logReadTimingIfEnabled({
    required String phase,
    required int catalogCountAtRead,
  }) {
    if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
    final readAt = DateTime.now();
    final completed = shopDiscoveryCompletedAt;
    catalogAuditLog(
      '[SHOP_POOL_READ_TIMING] phase=$phase '
      'readAt=${readAt.toIso8601String()} '
      'catalogCountAtRead=$catalogCountAtRead '
      'lastShopDiscoveryUpsertCompleted=${completed?.toIso8601String() ?? '-'} '
      'usesFreshCatalog=${readUsesFreshCatalog(readAt)}',
    );
  }

  /// テスト用リセット。
  static void resetForTest() {
    shopDiscoveryScheduledAt = null;
    shopDiscoveryCompletedAt = null;
    shopDiscoveryCatalogCountBefore = null;
    shopDiscoveryCatalogCountAfter = null;
    shopDiscoveryDurationMs = null;
  }
}
