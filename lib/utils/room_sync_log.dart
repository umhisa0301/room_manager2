import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/debug_log_flags.dart';
import '../models/room_sync_result.dart';
import 'app_debug_log.dart';

bool _roomImportDetailLogsEnabled() =>
    kDebugMode &&
    (DebugLogFlags.kRoomAuditLogsEnabled || debugVerboseRoomImport);

void _emitRoomImportDetailLine(String line) {
  if (!_roomImportDetailLogsEnabled()) return;
  debugPrint(line);
  RoomImportDebugLogBuffer.add(line);
}

/// URL一覧・HTMLプレビューなどROOM取り込みの詳細ログ。通常は false。
bool debugVerboseRoomImport = false;

/// kDebugMode のみ有効。ROOM取り込み1セッション分のログをメモリに蓄積し、後からコピー・表示する。
abstract final class RoomImportDebugLogBuffer {
  static const int maxLines = 1000;

  static final List<String> _lines = <String>[];

  /// ROOM 一覧系 HTTP/API（一覧ページ GET / collects 等）の完了回数。
  static int roomListCalls = 0;

  /// ROOM 商品ページ HTTP 完了回数。
  static int roomPageCalls = 0;

  /// 同期ループ内の楽天商品検索 API（補完用）呼び出し回数。
  static int rakutenItemCalls = 0;

  /// バッチ後メタデータ補完での楽天 API 呼び出し回数。
  static int enrichmentCalls = 0;

  /// 1同期セッション内の楽天商品検索API（ROOM同期ループ）レポート用。
  static int apiSkippedCount = 0;
  static int apiExecutedCount = 0;
  static int fallbackRecoveredCount = 0;
  static int apiRateLimitedCount = 0;
  static int apiHttp400Count = 0;

  static bool _capturing = false;
  static bool _sessionOpened = false;
  static int _prepareMs = -1;
  static int _totalMs = -1;

  /// 取り込み開始時: 行をクリアし、カウンタをリセットし、以降の蓄積を開始する。
  static void clear() {
    if (!kDebugMode) return;
    _lines.clear();
    roomListCalls = 0;
    roomPageCalls = 0;
    rakutenItemCalls = 0;
    enrichmentCalls = 0;
    apiSkippedCount = 0;
    apiExecutedCount = 0;
    fallbackRecoveredCount = 0;
    apiRateLimitedCount = 0;
    apiHttp400Count = 0;
    _prepareMs = -1;
    _totalMs = -1;
    _capturing = true;
    _sessionOpened = true;
  }

  static void startImportSession() => clear();

  static bool get isCapturing => kDebugMode && _capturing;

  static void notePrepareMs(int ms) {
    if (!kDebugMode) return;
    _prepareMs = ms;
  }

  static void noteTotalMs(int ms) {
    if (!kDebugMode) return;
    _totalMs = ms;
  }

  static void incRoomList() {
    if (!kDebugMode || !_capturing) return;
    roomListCalls++;
  }

  static void incRoomPage() {
    if (!kDebugMode || !_capturing) return;
    roomPageCalls++;
  }

  static void incRakutenItemFromSync() {
    if (!kDebugMode || !_capturing) return;
    rakutenItemCalls++;
  }

  static void incEnrichment() {
    if (!kDebugMode || !_capturing) return;
    enrichmentCalls++;
  }

  static void incApiSkipped() {
    if (!kDebugMode || !_capturing) return;
    apiSkippedCount++;
  }

  static void incApiExecuted() {
    if (!kDebugMode || !_capturing) return;
    apiExecutedCount++;
  }

  static void incFallbackRecovered() {
    if (!kDebugMode || !_capturing) return;
    fallbackRecoveredCount++;
  }

  static void incApiRateLimited() {
    if (!kDebugMode || !_capturing) return;
    apiRateLimitedCount++;
  }

  static void incApiHttp400() {
    if (!kDebugMode || !_capturing) return;
    apiHttp400Count++;
  }

  static void add(String line) {
    if (!kDebugMode || !_capturing) return;
    _append(line);
  }

  static void _append(String line) {
    while (_lines.length >= maxLines) {
      _lines.removeAt(0);
    }
    _lines.add(line);
  }

  /// 同期終了後・補完後にまとめて1行追加し、蓄積モードを終了する。
  static void emitImportSummary({
    required RoomSyncResult? result,
    required int enrichmentBatchMs,
    required int enrichmentUpdated,
    int enrichmentProductAttempts = 0,
  }) {
    if (!kDebugMode) return;
    if (!_sessionOpened) return;
    final itemCount = result?.processedCount ?? 0;
    final added = result?.newlyCollectedCount ?? 0;
    final updated = result?.roomUrlAddedCount ?? 0;
    final skipped = result?.skippedCount ?? 0;
    final failed = result?.failedCount ?? 0;
    final bufferEnrichmentCalls = enrichmentCalls;
    final enrichCallsForSummary = enrichmentProductAttempts > 0
        ? enrichmentProductAttempts
        : bufferEnrichmentCalls;
    final line =
        '[ROOM_IMPORT_SUMMARY] '
        'totalMs=${_totalMs < 0 ? 'unknown' : _totalMs} '
        'prepareMs=${_prepareMs < 0 ? 'unknown' : _prepareMs} '
        'itemCount=$itemCount '
        'added=$added '
        'updated=$updated '
        'skipped=$skipped '
        'failed=$failed '
        'roomListCalls=$roomListCalls '
        'roomPageCalls=$roomPageCalls '
        'rakutenItemCalls=$rakutenItemCalls '
        'enrichmentCalls=$enrichCallsForSummary '
        'enrichmentBatchMs=$enrichmentBatchMs '
        'enrichmentUpdated=$enrichmentUpdated';
    debugPrint(line);
    _append(line);
    _capturing = false;
    _sessionOpened = false;
  }

  static String dump() {
    if (!kDebugMode) return '';
    final now = DateTime.now().toUtc().toIso8601String();
    final header =
        '==== ROOM IMPORT DEBUG LOG ====\n'
        'createdAt=$now\n'
        'appMode=debug\n'
        'lineCount=${_lines.length}\n'
        '================================\n';
    if (_lines.isEmpty) {
      return '$header(no lines)\n';
    }
    return '$header\n${_lines.join('\n')}\n';
  }

  static Future<void> copyToClipboard() async {
    if (!kDebugMode) return;
    await Clipboard.setData(ClipboardData(text: dump()));
  }
}

/// 通常開発時に残すサマリーのみ（開始・件数・完了・エラー）。
void roomSyncSummaryLog(String message) {
  if (kDebugMode) {
    debugPrint('[ROOM_SYNC] $message');
  }
}

/// [debugVerboseRoomImport] が true のときだけの ROOM 反応数パース調査ログ。
void roomImportReactionVerboseLog(String message) {
  if (kDebugMode && debugVerboseRoomImport) {
    debugPrint('[ROOM_IMPORT] $message');
  }
}

/// [debugVerboseRoomImport] が true のときだけの詳細ログ。
void roomSyncVerboseLog(String message) {
  if (kDebugMode && debugVerboseRoomImport) {
    debugPrint('[ROOM_SYNC][VERBOSE] $message');
  }
}

/// 後方互換：従来の [roomSyncLog] は詳細扱いに寄せ、通常は出さない。
void roomSyncLog(String message) => roomSyncVerboseLog(message);

void roomSyncWarn(String message) {
  if (kDebugMode) {
    final line = '[ROOM_SYNC][WARN] $message';
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomSyncError(String message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    final head = '[ROOM_SYNC][ERROR] $message';
    debugPrint(head);
    RoomImportDebugLogBuffer.add(head);
    if (error != null) {
      roomSyncChunked('exception', error.toString());
    }
    if (stackTrace != null) {
      roomSyncChunked('stackTrace', stackTrace.toString(), chunkSize: 1200);
    }
  }
}

/// 長文は分割して出力（debugPrint の省略対策）。
void roomSyncPreview(String label, String text, {int maxLength = 800}) {
  if (!kDebugMode || !debugVerboseRoomImport) return;
  debugPrint('[ROOM_SYNC] $label length: ${text.length}');
  if (text.isEmpty) {
    debugPrint('[ROOM_SYNC] $label preview: (empty)');
    return;
  }
  final clipped = text.length > maxLength ? text.substring(0, maxLength) : text;
  roomSyncChunked('$label preview', clipped, chunkSize: maxLength);
}

void roomSyncChunked(String label, String text, {int chunkSize = 800}) {
  if (!kDebugMode) return;
  if (text.isEmpty) {
    debugPrint('[ROOM_SYNC] $label: (empty)');
    return;
  }
  var start = 0;
  var part = 0;
  while (start < text.length) {
    part++;
    final end = start + chunkSize > text.length
        ? text.length
        : start + chunkSize;
    final chunk = text.substring(start, end);
    final line = '[ROOM_SYNC] $label part$part: $chunk';
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
    start = end;
  }
}

void roomImportPerfLog(String message) {
  final line = '[ROOM_IMPORT_PERF] $message';
  _emitRoomImportDetailLine(line);
}

/// 取り込み UX／責務分離の経路ログ（開始・分岐のサマリ）。
void roomImportFlowLog(String message) {
  debugSummaryLog('[ROOM_IMPORT_FLOW] $message');
}

/// 取り込み後の自動補完を起動するかの判定ログ（debug のみ）。
void roomImportDeferredEnrichDecisionLog(String message) {
  final line = '[ROOM_IMPORT_DEFERRED_ENRICH_DECISION] $message';
  _emitRoomImportDetailLine(line);
}

/// マイページ手動「商品情報補完」の開始ログ（debug のみ）。
void roomImportManualEnrichStartLog(String message) {
  final line = '[ROOM_IMPORT_MANUAL_ENRICH_START] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportApiLog(String message) {
  final line = '[ROOM_IMPORT_API] $message';
  _emitRoomImportDetailLine(line);
}

/// ROOM 取り込み永続化の整合性（価格・画像の preserve 等）。
///
/// `changedPrice` 等は **DB が実際に書き換わったか**ではなく、
/// 「マージ結果として値が変わったか」のフラグ（誤って保存失敗と読まない）。
void roomImportSaveLog(String message) {
  final line = '[ROOM_IMPORT_SAVE] $message';
  _emitRoomImportDetailLine(line);
}

/// 通常補完の keyword+shopCode フォールバック結果（URL照合の成功／失敗）。
void roomImportEnrichFallbackResultLog(Map<String, String> fields) {
  if (!kDebugMode) return;
  final sb = StringBuffer('[ROOM_IMPORT_ENRICH_FALLBACK_RESULT]\n');
  for (final e in fields.entries) {
    final v = e.value.replaceAll('\n', ' ').trim();
    sb.writeln('${e.key}=$v');
  }
  final text = sb.toString().trimRight();
  debugPrint(text);
  RoomImportDebugLogBuffer.add(text.replaceAll('\n', ' | '));
}

/// keyword + shopCode フォールバック／タイトル検索向けキーワードの正規化結果。
void roomImportEnrichFallbackKeywordLog(Map<String, String> fields) {
  _roomImportEnrichFallbackTaggedBlockLog(
    'ROOM_IMPORT_ENRICH_FALLBACK_KEYWORD',
    fields,
  );
}

/// 補完反映と一覧の先頭表示が一致しないときの切り分け用。
void roomImportEnrichUiReflectLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_UI_REFLECT] $message';
  _emitRoomImportDetailLine(line);
}

void _roomImportEnrichFallbackTaggedBlockLog(
  String tag,
  Map<String, String> fields,
) {
  if (!kDebugMode) return;
  final sb = StringBuffer('[$tag]\n');
  for (final e in fields.entries) {
    final v = e.value.replaceAll('\n', ' ').trim();
    sb.writeln('${e.key}=$v');
  }
  final text = sb.toString().trimRight();
  debugPrint(text);
  RoomImportDebugLogBuffer.add(text.replaceAll('\n', ' | '));
}

/// 起動時: `ROOM_IMPORT_ENRICH_VERIFY` の有無（実機で検証モード混入を切り分け）。
void roomImportEnrichModeLog(bool verifyMode) {
  debugSummaryLog('[ROOM_IMPORT_ENRICH_MODE] verifyMode=$verifyMode');
}

/// shopItem 経路のフォールバック系列ログ開始（通常補完・検証フラグの記録用）。
void roomImportEnrichFallbackStartLog(Map<String, String> fields) {
  _roomImportEnrichFallbackTaggedBlockLog(
    'ROOM_IMPORT_ENRICH_FALLBACK_START',
    fields,
  );
}

/// itemCode 無効などで keyword+shopCode に進む直前。
void roomImportEnrichFallbackTriggeredLog(Map<String, String> fields) {
  _roomImportEnrichFallbackTaggedBlockLog(
    'ROOM_IMPORT_ENRICH_FALLBACK_TRIGGERED',
    fields,
  );
}

void roomImportSkipApiLog(String message) {
  final line = '[ROOM_IMPORT_SKIP_API] $message';
  _emitRoomImportDetailLine(line);
}

/// ROOM同期の既存行照合結果（APIスキップ・再同期判定用）。
void roomImportExistingMatchLog(String message) {
  final line = '[ROOM_IMPORT_EXISTING_MATCH] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportSameItemDifferentRoomLog(String message) {
  final line = '[ROOM_IMPORT_SAME_ITEM_DIFF_ROOM] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportFallbackLog(String message) {
  final line = '[ROOM_IMPORT_FALLBACK] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportItemCodeDiagLog(String message) {
  final line = '[ROOM_IMPORT_ITEMCODE] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportItemApiParamsLog(String message) {
  final line = '[ROOM_IMPORT_ITEM_API_PARAMS] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportItemApiBlockedLog(String message) {
  final line = '[ROOM_IMPORT_ITEM_API_BLOCKED] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportItemApiSuccessLog(String message) {
  final line = '[ROOM_IMPORT_ITEM_API_SUCCESS] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichTargetLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_TARGET] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichApiLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_API] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichPausedLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_PAUSED] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichSuccessLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_SUCCESS] $message';
  _emitRoomImportDetailLine(line);
}

/// ROOM 取り込みメタ補完の **検証モード**（`ROOM_IMPORT_ENRICH_VERIFY`）専用ログ。
void roomImportVerifyLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_VERIFY] $message';
  _emitRoomImportDetailLine(line);
}

/// 検証モード終了時の **1ブロック**サマリー（成功／失敗どちらでも必ず1回）。
///
/// [fields] のキー順がログ行順になる（挿入順を保持するため `LinkedHashMap` 推奨）。
void roomImportEnrichVerifyResultLog(Map<String, String> fields) {
  if (!kDebugMode) return;
  final sb = StringBuffer('[ROOM_IMPORT_ENRICH_VERIFY_RESULT]\n');
  for (final e in fields.entries) {
    final v = e.value.replaceAll('\n', ' ').trim();
    sb.writeln('${e.key}=$v');
  }
  final text = sb.toString().trimRight();
  debugPrint(text);
  RoomImportDebugLogBuffer.add(text.replaceAll('\n', ' | '));
}

void roomImportEnrichPickLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_PICK] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichMethodLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_METHOD] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichFailLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_FAIL] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichQueueLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_QUEUE] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichCooldownLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_COOLDOWN] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichRequestLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_REQUEST] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichSkipLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_SKIP] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichSummaryLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_SUMMARY] $message';
  _emitRoomImportDetailLine(line);
}

/// 楽天 itemCode 補完APIの HTTP・プロキシ・レスポンス先頭の診断用。
void roomImportItemCodeApiDiagLog(String message) {
  final line = '[ROOM_IMPORT_ITEMCODE_API_DIAG] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportApiSummaryLog(String message) {
  final line = '[ROOM_IMPORT_API_SUMMARY] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportUiLog(String message) {
  final line = '[ROOM_IMPORT_UI] $message';
  _emitRoomImportDetailLine(line);
}

/// ROOM 取り込み prepare フェーズの内訳（計測用）。
void roomImportPrepareDetailLog(String field, int ms) {
  final line = '[ROOM_IMPORT_PREPARE_DETAIL] $field=${ms}ms';
  _emitRoomImportDetailLine(line);
}

/// ROOM 一覧・collects の取得経路（ページング理由の切り分け用）。
void roomImportListingLog(String message) {
  final line = '[ROOM_IMPORT_LISTING] $message';
  _emitRoomImportDetailLine(line);
}

/// rat-redirect 1件分の詳細抽出（dest 多段デコード・URLパス・event 分解）。
void roomRatRedirectExtractLog(String message) {
  final line = '[ROOM_RAT_REDIRECT_EXTRACT] $message';
  _emitRoomImportDetailLine(line);
}

/// rat-redirect `event` / `dest` 解析結果（採用1件分）。
void roomRedirectParseLog(String message) {
  final line = '[ROOM_REDIRECT_PARSE] $message';
  _emitRoomImportDetailLine(line);
}

void roomRedirectParseSourceLog(String message) {
  final line = '[ROOM_REDIRECT_PARSE_SOURCE] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportSourceDecisionLog(String message) {
  final line = '[ROOM_IMPORT_SOURCE_DECISION] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportSourceDecisionDetailLog(String message) {
  final line = '[ROOM_IMPORT_SOURCE_DECISION_DETAIL] $message';
  _emitRoomImportDetailLine(line);
}

void roomHtmlImageFallbackLog(String message) {
  final line = '[ROOM_HTML_IMAGE_FALLBACK] $message';
  _emitRoomImportDetailLine(line);
}

void roomReactionSyncStopLog(String message) {
  final line = '[ROOM_REACTION_SYNC_STOP] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichApiCodeLearnedLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_API_CODE_LEARNED] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichDetailFetchForRedirectLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_DETAIL_FETCH_FOR_REDIRECT] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEnrichDetailFetchResultLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_DETAIL_FETCH_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportInitialEnrichStopLog(String message) {
  final line = '[ROOM_IMPORT_INITIAL_ENRICH_STOP] $message';
  _emitRoomImportDetailLine(line);
}

/// 初回補完で direct itemCode か keyword かの分岐。
void roomImportEnrichSourceDecisionLog(Map<String, String> fields) {
  _roomImportEnrichFallbackTaggedBlockLog(
    'ROOM_IMPORT_ENRICH_SOURCE_DECISION',
    fields,
  );
}

/// URL スラッグ型のため direct itemCode を送らないとき。
void roomImportEnrichDirectSkipLog(Map<String, String> fields) {
  _roomImportEnrichFallbackTaggedBlockLog(
    'ROOM_IMPORT_ENRICH_DIRECT_SKIP',
    fields,
  );
}

void roomImportCollectsPolicyLog(String message) {
  final line = '[ROOM_IMPORT_COLLECTS_POLICY] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportCollectsProgressLog(String message) {
  final line = '[ROOM_IMPORT_COLLECTS_PROGRESS] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportCollectsStopLog(String message) {
  final line = '[ROOM_IMPORT_COLLECTS_STOP] $message';
  _emitRoomImportDetailLine(line);
}

/// ROOM 取り込み後のメタ補完（enrichment）の打ち切り理由。
void roomImportEnrichStopLog(String reason) {
  final line = '[ROOM_IMPORT_ENRICH] stop reason=$reason';
  _emitRoomImportDetailLine(line);
}

/// 一覧HTML／collects 由来の楽天URL高速解決（ROOM 商品ページ GET 省略）の1件ログ。
void roomFastPathLog(String message) {
  final line = '[ROOM_FASTPATH] $message';
  _emitRoomImportDetailLine(line);
}

/// 1バッチあとの高速パス集計（比較用）。
void roomFastPathSummaryLog(String message) {
  final line = '[ROOM_FASTPATH_SUMMARY] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportCursorLog(String message) {
  final line = '[ROOM_IMPORT_CURSOR] $message';
  _emitRoomImportDetailLine(line);
}

void roomReactionSyncCursorLog(String message) {
  final line = '[ROOM_REACTION_SYNC_CURSOR] $message';
  _emitRoomImportDetailLine(line);
}

void roomSyncJobLockLog(String message) {
  final line = '[ROOM_SYNC_JOB_LOCK] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportBatchStartLog(String message) {
  final line = '[ROOM_IMPORT_BATCH_START] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportBatchResultLog(String message) {
  final line = '[ROOM_IMPORT_BATCH_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

/// 新規取り込み1件ごとの ROOM 一覧／商品ページから拾えた画像・価格ヒント。
void roomImportListingMetadataLog(String message) {
  final line = '[ROOM_IMPORT_LISTING_METADATA] $message';
  _emitRoomImportDetailLine(line);
}

/// ROOM 取り込み時に ROOM 側から直接取得したメタ（collects / 詳細HTML / rat-redirect）。
void roomImportRoomMetadataLog(String message) {
  final line = '[ROOM_IMPORT_ROOM_METADATA] $message';
  _emitRoomImportDetailLine(line);
}

/// 楽天API補完: shopCode + 価格帯 + keyword 検索の条件ログ。
void roomImportApiSearchByPriceLog(String message) {
  final line = '[ROOM_IMPORT_API_SEARCH_BY_PRICE] $message';
  _emitRoomImportDetailLine(line);
}

/// 楽天API補完: 候補1件の同一商品判定ログ。
void roomImportApiCandidateMatchLog(String message) {
  final line = '[ROOM_IMPORT_API_CANDIDATE_MATCH] $message';
  _emitRoomImportDetailLine(line);
}

/// 楽天API補完: マージ成功時の保存内容ログ。
void roomImportApiSupplementSuccessLog(String message) {
  final line = '[ROOM_IMPORT_API_SUPPLEMENT_SUCCESS] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportInitialEnrichStartLog(String message) {
  final line = '[ROOM_IMPORT_INITIAL_ENRICH_START] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportInitialEnrichResultLog(String message) {
  final line = '[ROOM_IMPORT_INITIAL_ENRICH_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

void roomReactionSyncStartLog(String message) {
  final line = '[ROOM_REACTION_SYNC_START] $message';
  _emitRoomImportDetailLine(line);
}

void roomSyncButtonVisibilityLog(String message) {
  roomAuditLog('[ROOM_SYNC_BUTTON_VISIBILITY] $message');
}

void roomSyncButtonRenderDecisionLog(String message) {
  roomAuditLog('[ROOM_SYNC_BUTTON_RENDER_DECISION] $message');
}

void roomSyncMaintenanceVisibilityLog(String message) {
  roomAuditLog('[ROOM_SYNC_MAINTENANCE_VISIBILITY] $message');
}

void roomImportResultSheetCopyLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_SHEET_COPY] $message';
  _emitRoomImportDetailLine(line);
}

void analyticsCountSourceLog(String message) {
  analyticsAuditLog('[ANALYTICS_COUNT_SOURCE] $message');
}

void analyticsDailyBarLog(String message) {
  analyticsAuditLog('[ANALYTICS_DAILY_BAR] $message');
}

void roomImportEventCreateLog(String message) {
  final line = '[ROOM_IMPORT_EVENT_CREATE] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportEventSummaryLog(String message) {
  final line = '[ROOM_IMPORT_EVENT_SUMMARY] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportAnalyticsSeparationLog(String message) {
  analyticsAuditLog('[ROOM_IMPORT_ANALYTICS_SEPARATION] $message');
}

void reactionStatusSaveLog(String message) {
  final line = '[REACTION_STATUS_SAVE] $message';
  _emitRoomImportDetailLine(line);
}

void reactionStatusRenderLog(String message) {
  verboseItemLog('[REACTION_STATUS_RENDER] $message');
}

void roomImportImageSourceLog(String message) {
  final line = '[ROOM_IMPORT_IMAGE_SOURCE] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportResultImageRefreshLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_IMAGE_REFRESH] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportResultSheetRefreshLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_SHEET_REFRESH] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportResultSheetItemLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_SHEET_ITEM] $message';
  _emitRoomImportDetailLine(line);
}

void roomReactionSyncUiSummaryLog(String message) {
  final line = '[ROOM_REACTION_SYNC_UI_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

void roomReactionSyncResultLog(String message) {
  final line = '[ROOM_REACTION_SYNC_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

void roomBatchFetchPlanLog(String message) {
  final line = '[ROOM_BATCH_FETCH_PLAN] $message';
  _emitRoomImportDetailLine(line);
}

void roomBatchFetchResultLog(String message) {
  final line = '[ROOM_BATCH_FETCH_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

void roomBatchCompareResultLog(String message) {
  final line = '[ROOM_BATCH_COMPARE_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

void roomBatchSaveResultLog(String message) {
  final line = '[ROOM_BATCH_SAVE_RESULT] $message';
  _emitRoomImportDetailLine(line);
}

/// URL検索の入口〜API 戦略トレース（kDebugMode のみ）。
void urlSearchTraceLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[URL_SEARCH_TRACE] $message');
}

/// URL検索の成否サマリー（kDebugMode のみ）。
void urlSearchResultLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[URL_SEARCH_RESULT] $message');
}

/// ROOM 取り込み補完の戦略トレース（kDebugMode のみ）。
void roomImportEnrichTraceLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[ROOM_IMPORT_ENRICH_TRACE] $message');
}

/// ROOM 取り込み補完の1件結果（kDebugMode のみ）。
void roomImportEnrichResultLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[ROOM_IMPORT_ENRICH_RESULT] $message');
}

void roomSyncUiGuardLog(String message) {
  final line = '[ROOM_SYNC_UI_GUARD] $message';
  _emitRoomImportDetailLine(line);
}

void roomImportPhaseUiLog({
  required String phase,
  required String label,
  required double progress,
}) {
  final line =
      '[ROOM_IMPORT_PHASE_UI] phase=$phase label=$label progress=$progress';
  _emitRoomImportDetailLine(line);
}

void roomImportProductInfoPendingReasonLog({
  required String productId,
  required String title,
  required String shopCode,
  required String urlProductCode,
  required bool hasRoomTitle,
  required bool hasRoomImage,
  required bool hasRoomPrice,
  required bool hasRoomUrl,
  required bool apiSearchTried,
  required String apiSearchReason,
  required String pendingFields,
  required String reason,
}) {
  final line =
      '[ROOM_IMPORT_PRODUCT_INFO_PENDING_REASON] productId=$productId '
      'title=${title.trim().isEmpty ? '(empty)' : title.trim()} '
      'shopCode=${shopCode.trim()} urlProductCode=${urlProductCode.trim()} '
      'hasRoomTitle=$hasRoomTitle hasRoomImage=$hasRoomImage '
      'hasRoomPrice=$hasRoomPrice hasRoomUrl=$hasRoomUrl '
      'apiSearchTried=$apiSearchTried apiSearchReason=${apiSearchReason.trim()} '
      'pendingFields=$pendingFields reason=$reason';
  _emitRoomImportDetailLine(line);
}

void roomImportResultSheetSimplifiedLog({
  required int added,
  required int productInfoConfirmed,
  required int productInfoPending,
  required int reactionItems,
  bool debugDetailsHidden = true,
}) {
  final line =
      '[ROOM_IMPORT_RESULT_SHEET_SIMPLIFIED] added=$added '
      'productInfoConfirmed=$productInfoConfirmed '
      'productInfoPending=$productInfoPending reactionItems=$reactionItems '
      'debugDetailsHidden=$debugDetailsHidden';
  _emitRoomImportDetailLine(line);
}

void unknownFloatingButtonAuditLog({
  required String screen,
  required String widget,
  required String file,
  required bool visible,
  required String reason,
}) {
  roomAuditLog(
    '[UNKNOWN_FLOATING_BUTTON_AUDIT] screen=$screen widget=$widget '
    'file=$file visible=$visible reason=$reason',
  );
}

void unknownFloatingButtonHideLog({
  required String screen,
  required String widget,
  required String reason,
}) {
  roomAuditLog(
    '[UNKNOWN_FLOATING_BUTTON_HIDE] screen=$screen widget=$widget reason=$reason',
  );
}

void homeSectionOrderLog(String order) {
  roomAuditLog('[HOME_SECTION_ORDER] order=$order');
}

void roomSyncCardUxRenderLog({
  required String state,
  required bool showImportButton,
  required bool showReactionButton,
  required bool showAnalysisCta,
  String hiddenDisabledButtons = 'none',
}) {
  roomAuditLog(
    '[ROOM_SYNC_CARD_UX_RENDER] state=$state '
    'showImportButton=$showImportButton showReactionButton=$showReactionButton '
    'showAnalysisCta=$showAnalysisCta hiddenDisabledButtons=$hiddenDisabledButtons',
  );
}

void roomSyncReactionButtonStyleLog(String message) {
  final line = '[ROOM_SYNC_REACTION_BUTTON_STYLE] $message';
  _emitRoomImportDetailLine(line);
}

void roomSyncEmptyButtonAuditLog({
  required String screen,
  String widget = 'none',
  String button = 'unknown',
  required bool visible,
  bool enabled = false,
  String label = '',
  required String reason,
}) {
  roomAuditLog(
    '[ROOM_SYNC_EMPTY_BUTTON_AUDIT] screen=$screen widget=$widget '
    'button=$button visible=$visible enabled=$enabled label=$label '
    'reason=$reason',
  );
}

void roomImportActivityVisibilityLog({
  required String screen,
  required bool visible,
  required String reason,
}) {
  roomAuditLog(
    '[ROOM_IMPORT_ACTIVITY_VISIBILITY] screen=$screen visible=$visible reason=$reason',
  );
}

void searchValidationErrorLog({
  required String screen,
  required String field,
  required String message,
  bool shownInSheet = true,
  bool shownNearField = false,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[SEARCH_VALIDATION_ERROR] screen=$screen field=$field '
    'message=$message shownInSheet=$shownInSheet '
    'shownNearField=$shownNearField',
  );
}

void searchFilterSheetLayoutLog({
  bool hasFixedHeader = true,
  bool hasFixedFooter = true,
  bool keyboardAware = true,
}) {
  searchAuditLog(
    '[SEARCH_FILTER_SHEET_LAYOUT] hasFixedHeader=$hasFixedHeader '
    'hasFixedFooter=$hasFixedFooter keyboardAware=$keyboardAware',
  );
}

void searchFilterSheetOverflowGuardLog({
  bool hasFixedHeader = true,
  bool hasScrollableBody = true,
  bool hasFixedFooter = true,
  double keyboardInset = 0,
  String reason = 'preventRenderFlexOverflow',
}) {
  searchAuditLog(
    '[SEARCH_FILTER_SHEET_OVERFLOW_GUARD] hasFixedHeader=$hasFixedHeader '
    'hasScrollableBody=$hasScrollableBody hasFixedFooter=$hasFixedFooter '
    'keyboardInset=$keyboardInset reason=$reason',
  );
}

void urlAddEntryVisibilityLog({
  required bool visible,
  required String reason,
  bool codeKept = true,
}) {
  searchAuditLog(
    '[URL_ADD_ENTRY_VISIBILITY] visible=$visible reason=$reason '
    'codeKept=$codeKept',
  );
}

void bulkRegisterStartLog({
  required String mode,
  required int selectedCount,
  required String sourceScreen,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[BULK_REGISTER_START] mode=$mode selectedCount=$selectedCount '
    'sourceScreen=$sourceScreen',
  );
}

void bulkRegisterItemResultLog({
  required int index,
  required String productId,
  required String title,
  required bool success,
  required bool skipped,
  required String reason,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[BULK_REGISTER_ITEM_RESULT] index=$index productId=$productId '
    'title=$title success=$success skipped=$skipped reason=$reason',
  );
}

void bulkRegisterResultLog({
  required int selected,
  required int success,
  required int skipped,
  required int failed,
  required int alreadyExists,
  required int safetyBlocked,
  required int limitReached,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[BULK_REGISTER_RESULT] selected=$selected success=$success '
    'skipped=$skipped failed=$failed alreadyExists=$alreadyExists '
    'safetyBlocked=$safetyBlocked limitReached=$limitReached',
  );
}
