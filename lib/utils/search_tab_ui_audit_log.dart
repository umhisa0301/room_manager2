import 'package:flutter/foundation.dart';

void searchTabUiAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_TAB_UI_AUDIT] $message');
}

void selectionUiAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SELECTION_UI_AUDIT] $message');
}

void selectionToggleAllLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SELECTION_TOGGLE_ALL] $message');
}

void genreUiAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[GENRE_UI_AUDIT] $message');
}

void shopDiscoveryGenreTreeOpenLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_DISCOVERY_GENRE_TREE_OPEN] $message');
}

void shopDiscoveryGenreTreeSelectLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_DISCOVERY_GENRE_TREE_SELECT] $message');
}

void shopDiscoverySearchParamsLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_DISCOVERY_SEARCH_PARAMS] $message');
}
