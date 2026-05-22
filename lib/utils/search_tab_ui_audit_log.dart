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

void searchResultViewportAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_RESULT_VIEWPORT_AUDIT] $message');
}

void searchBottomSpaceAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_BOTTOM_SPACE_AUDIT] $message');
}

void shopDetailResultViewportAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_DETAIL_RESULT_VIEWPORT_AUDIT] $message');
}

void shopDetailExternalButtonCopyAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_DETAIL_EXTERNAL_BUTTON_COPY_AUDIT] $message');
}

void registeredLabelCopyAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[REGISTERED_LABEL_COPY_AUDIT] $message');
}

void shopDiscoveryButtonCopyAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SHOP_DISCOVERY_BUTTON_COPY_AUDIT] $message');
}

void searchResultParentConstraintAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_RESULT_PARENT_CONSTRAINT_AUDIT] $message');
}

void searchResultBlankAreaAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_RESULT_BLANK_AREA_AUDIT] $message');
}

void searchConditionSheetContextAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_CONDITION_SHEET_CONTEXT_AUDIT] $message');
}

void searchTransientErrorAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_TRANSIENT_ERROR_AUDIT] $message');
}

void searchPhaseTransitionAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_PHASE_TRANSITION_AUDIT] $message');
}

void searchResultWidgetTreeAuditLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SEARCH_RESULT_WIDGET_TREE_AUDIT] $message');
}
