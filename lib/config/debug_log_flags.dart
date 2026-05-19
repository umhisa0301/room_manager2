/// アプリ由来の詳細ログ ON/OFF（通常デバッグはサマリのみ）。
abstract final class DebugLogFlags {
  static const bool enableVerboseRakutenUrlLog = false;
  static const bool enableVerboseGenreResolveLog = false;
  static const bool enableVerboseProductCardAuditLog = false;
  static const bool enableVerboseSearchStateLog = false;
  static const bool enableVerboseRoomImportImageLog = true;
  static const bool enableVerboseReactionButtonRenderLog = false;
  static const bool enableVerboseShopCodeUiAuditLog = false;
  static const bool enableVerboseRoomColleDiagnosticLog = false;
}
