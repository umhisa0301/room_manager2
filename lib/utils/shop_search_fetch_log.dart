import 'package:flutter/foundation.dart';

void shopSearchFetchPlanLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_SEARCH_FETCH_PLAN] $message');
}

void shopSearchApiCallLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_SEARCH_API_CALL] $message');
}

void shopSearchFetchResultLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_SEARCH_FETCH_RESULT] $message');
}

void shopSearchPartialFailureLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_SEARCH_PARTIAL_FAILURE] $message');
}
