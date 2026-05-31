/// アプリ由来の詳細ログ ON/OFF（`--dart-define` で上書き可能）。
abstract final class DebugLogFlags {
  /// 検索画面 UI 監査（ヘッダー・レイアウト・セグメント等）。
  static const bool kSearchAuditLogsEnabled = bool.fromEnvironment(
    'SEARCH_AUDIT_LOGS',
    defaultValue: false,
  );

  /// ROOM 同期ボタン・取り込み経路の監査ログ。
  static const bool kRoomAuditLogsEnabled = bool.fromEnvironment(
    'ROOM_AUDIT_LOGS',
    defaultValue: false,
  );

  /// 分析タブ・日次バー等の監査ログ。
  static const bool kAnalyticsAuditLogsEnabled = bool.fromEnvironment(
    'ANALYTICS_AUDIT_LOGS',
    defaultValue: false,
  );

  /// 商品・保存・カード単位の詳細ログ。
  static const bool kVerboseItemLogsEnabled = bool.fromEnvironment(
    'VERBOSE_ITEM_LOGS',
    defaultValue: false,
  );

  /// 今日のおすすめ生成の監査ログ（プラン/API/商品単位トレース等）。
  static const bool kRecommendAuditLogsEnabled = bool.fromEnvironment(
    'RECOMMEND_AUDIT_LOGS',
    defaultValue: false,
  );

  /// おすすめ詳細ログ（監査 or 商品詳細）が有効か。
  static bool get recommendVerboseLogsEnabled =>
      kRecommendAuditLogsEnabled || kVerboseItemLogsEnabled;

  /// デバッグ時のサマリ1行ログ（開始/完了/件数）を出す。
  static const bool kDebugLogSummaryEnabled = bool.fromEnvironment(
    'DEBUG_LOG_SUMMARY',
    defaultValue: true,
  );

  // --- 後方互換（コード内 const 参照用・dart-define 非対応） ---

  static const bool enableVerboseRakutenUrlLog = false;
  static const bool enableVerboseGenreResolveLog = false;
  static const bool enableVerboseProductCardAuditLog = false;
  static const bool enableVerboseSearchStateLog = false;
  static const bool enableVerboseRoomImportImageLog = false;
  static const bool enableVerboseReactionButtonRenderLog = false;
  static const bool enableVerboseShopCodeUiAuditLog = false;
  static const bool enableVerboseRoomColleDiagnosticLog = false;
}
