import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../models/catalog_product.dart';

/// 検索画面 UI 監査ログ（`SEARCH_AUDIT_LOGS=true` のときのみ）。
void searchAuditLog(String message) {
  if (!kDebugMode || !DebugLogFlags.kSearchAuditLogsEnabled) return;
  debugPrint(message);
}

/// ROOM 同期・取り込み UI 監査ログ（`ROOM_AUDIT_LOGS=true` のときのみ）。
void roomAuditLog(String message) {
  if (!kDebugMode || !DebugLogFlags.kRoomAuditLogsEnabled) return;
  debugPrint(message);
}

/// 分析画面監査ログ（`ANALYTICS_AUDIT_LOGS=true` のときのみ）。
void analyticsAuditLog(String message) {
  if (!kDebugMode || !DebugLogFlags.kAnalyticsAuditLogsEnabled) return;
  debugPrint(message);
}

/// 商品・カード・保存単位の詳細ログ（`VERBOSE_ITEM_LOGS=true` のときのみ）。
void verboseItemLog(String message) {
  if (!kDebugMode || !DebugLogFlags.kVerboseItemLogsEnabled) return;
  debugPrint(message);
}

/// 今日のおすすめ生成の監査ログ（`RECOMMEND_AUDIT_LOGS=true` または `VERBOSE_ITEM_LOGS=true`）。
void recommendAuditLog(String message) {
  if (!kDebugMode || !DebugLogFlags.recommendVerboseLogsEnabled) return;
  debugPrint(message);
}

/// デバッグビルド向けの重要ログ（失敗・例外・検索実行トレース等）。
void importantDebugLog(String message) {
  if (!kDebugMode) return;
  debugPrint(message);
}

/// デバッグ時サマリ1行（`DEBUG_LOG_SUMMARY`、既定 true）。
void debugSummaryLog(String message) {
  if (!kDebugMode || !DebugLogFlags.kDebugLogSummaryEnabled) return;
  debugPrint(message);
}

/// 共通商品カタログ監査ログ（`CATALOG_AUDIT_LOGS=true` のときのみ）。
void catalogAuditLog(String message) {
  if (!kDebugMode || !DebugLogFlags.kCatalogAuditLogsEnabled) return;
  debugPrint(message);
}

/// 共通ショップカタログ監査ログ（`CATALOG_AUDIT_LOGS=true` のときのみ）。
void shopCatalogAuditLog(String message) {
  catalogAuditLog(message);
}

/// CATALOG / ROOM のいずれか有効時に1回だけ出す監査ログ。
void catalogOrRoomAuditLog(String message) {
  if (!kDebugMode) return;
  if (!DebugLogFlags.kCatalogAuditLogsEnabled &&
      !DebugLogFlags.kRoomAuditLogsEnabled) {
    return;
  }
  debugPrint(message);
}

/// ProductCatalog 集計 ShopPool サマリ（`CATALOG_AUDIT_LOGS=true` のときのみ）。
void shopPoolSummaryLog(String details) {
  catalogAuditLog('[SHOP_POOL_SUMMARY] $details');
}

/// カタログ走査の stale 判定サマリ（`CATALOG_AUDIT_LOGS=true` で1行。
/// 商品単位は `VERBOSE_ITEM_LOGS=true` のときのみ）。
void productCatalogStaleBatchSummaryLog({
  required String source,
  required Iterable<CatalogProduct> products,
  DateTime? now,
}) {
  if (!kDebugMode || !DebugLogFlags.kCatalogAuditLogsEnabled) return;

  final t = now ?? DateTime.now();
  var total = 0;
  var staleCount = 0;
  var freshCount = 0;
  int? minAgeSeconds;
  int? maxAgeSeconds;
  int? ttlSeconds;

  for (final product in products) {
    total++;
    final ageSeconds = t.difference(product.lastValidatedAt).inSeconds;
    final ttl = product.cacheTtlSeconds;
    ttlSeconds ??= ttl;
    final isProductStale = ageSeconds > ttl;
    if (isProductStale) {
      staleCount++;
    } else {
      freshCount++;
    }
    if (minAgeSeconds == null || ageSeconds < minAgeSeconds) {
      minAgeSeconds = ageSeconds;
    }
    if (maxAgeSeconds == null || ageSeconds > maxAgeSeconds) {
      maxAgeSeconds = ageSeconds;
    }

    if (DebugLogFlags.kVerboseItemLogsEnabled) {
      verboseItemLog(
        '[PRODUCT_CATALOG_STALE_SUMMARY] canonicalId=${product.canonicalId} '
        'ageSeconds=$ageSeconds ttl=$ttl stale=$isProductStale',
      );
    }
  }

  if (total == 0) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_STALE_SUMMARY] source=$source total=0 fresh=0 stale=0 '
      'minAgeSeconds=- maxAgeSeconds=- ttlSeconds=-',
    );
    return;
  }

  catalogAuditLog(
    '[PRODUCT_CATALOG_STALE_SUMMARY] source=$source total=$total '
    'fresh=$freshCount stale=$staleCount '
    'minAgeSeconds=$minAgeSeconds maxAgeSeconds=$maxAgeSeconds '
    'ttlSeconds=$ttlSeconds',
  );
}

/// 同一キー・同一内容の監査ログ重複を抑止（build 連打対策）。
final class AuditLogDeduper {
  AuditLogDeduper._();

  static final Map<String, String> _lastByKey = <String, String>{};

  static void logOnce(
    String key,
    String message,
    void Function(String message) emit,
  ) {
    if (_lastByKey[key] == message) return;
    _lastByKey[key] = message;
    emit(message);
  }

  static void reset([String? key]) {
    if (key == null) {
      _lastByKey.clear();
    } else {
      _lastByKey.remove(key);
    }
  }
}
