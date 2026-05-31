import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';

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
