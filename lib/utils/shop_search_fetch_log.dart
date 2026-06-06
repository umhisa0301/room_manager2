import 'app_debug_log.dart';

/// ショップ検索の取得計画（`CATALOG_AUDIT_LOGS=true` のときのみ）。
void shopSearchFetchPlanLog(String message) {
  catalogAuditLog('[SHOP_SEARCH_FETCH_PLAN] $message');
}

/// ショップ検索の API 呼び出しトレース（`CATALOG_AUDIT_LOGS=true` のときのみ）。
void shopSearchApiCallLog(String message) {
  catalogAuditLog('[SHOP_SEARCH_API_CALL] $message');
}

/// ショップ検索の取得結果サマリ（`CATALOG_AUDIT_LOGS=true` のときのみ）。
void shopSearchFetchResultLog(String message) {
  catalogAuditLog('[SHOP_SEARCH_FETCH_RESULT] $message');
}

/// ショップ検索の部分失敗（debug ビルド向け重要ログ）。
void shopSearchPartialFailureLog(String message) {
  importantDebugLog('[SHOP_SEARCH_PARTIAL_FAILURE] $message');
}
