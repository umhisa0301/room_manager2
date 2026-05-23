import 'app_debug_log.dart';

void searchTabUiAuditLog(String message) {
  searchAuditLog('[SEARCH_TAB_UI_AUDIT] $message');
}

void selectionUiAuditLog(String message) {
  searchAuditLog('[SELECTION_UI_AUDIT] $message');
}

void selectionToggleAllLog(String message) {
  searchAuditLog('[SELECTION_TOGGLE_ALL] $message');
}

void genreUiAuditLog(String message) {
  searchAuditLog('[GENRE_UI_AUDIT] $message');
}

void shopDiscoveryGenreTreeOpenLog(String message) {
  searchAuditLog('[SHOP_DISCOVERY_GENRE_TREE_OPEN] $message');
}

void shopDiscoveryGenreTreeSelectLog(String message) {
  searchAuditLog('[SHOP_DISCOVERY_GENRE_TREE_SELECT] $message');
}

void shopDiscoverySearchParamsLog(String message) {
  searchAuditLog('[SHOP_DISCOVERY_SEARCH_PARAMS] $message');
}

void searchResultViewportAuditLog(String message) {
  searchAuditLog('[SEARCH_RESULT_VIEWPORT_AUDIT] $message');
}

void searchBottomSpaceAuditLog(String message) {
  searchAuditLog('[SEARCH_BOTTOM_SPACE_AUDIT] $message');
}

void shopDetailResultViewportAuditLog(String message) {
  searchAuditLog('[SHOP_DETAIL_RESULT_VIEWPORT_AUDIT] $message');
}

void shopDetailExternalButtonCopyAuditLog(String message) {
  searchAuditLog('[SHOP_DETAIL_EXTERNAL_BUTTON_COPY_AUDIT] $message');
}

void registeredLabelCopyAuditLog(String message) {
  searchAuditLog('[REGISTERED_LABEL_COPY_AUDIT] $message');
}

void shopDiscoveryButtonCopyAuditLog(String message) {
  searchAuditLog('[SHOP_DISCOVERY_BUTTON_COPY_AUDIT] $message');
}

void searchResultParentConstraintAuditLog(String message) {
  searchAuditLog('[SEARCH_RESULT_PARENT_CONSTRAINT_AUDIT] $message');
}

void searchResultBlankAreaAuditLog(String message) {
  searchAuditLog('[SEARCH_RESULT_BLANK_AREA_AUDIT] $message');
}

void searchConditionSheetContextAuditLog(String message) {
  searchAuditLog('[SEARCH_CONDITION_SHEET_CONTEXT_AUDIT] $message');
}

void searchTransientErrorAuditLog(String message) {
  importantDebugLog('[SEARCH_TRANSIENT_ERROR_AUDIT] $message');
}

void searchPhaseTransitionAuditLog(String message) {
  searchAuditLog('[SEARCH_PHASE_TRANSITION_AUDIT] $message');
}

void searchResultWidgetTreeAuditLog(String message) {
  searchAuditLog('[SEARCH_RESULT_WIDGET_TREE_AUDIT] $message');
}
