import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/room_sync_result.dart';

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
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 取り込み UX／責務分離の経路ログ（debug のみ）。
void roomImportFlowLog(String message) {
  final line = '[ROOM_IMPORT_FLOW] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 取り込み後の自動補完を起動するかの判定ログ（debug のみ）。
void roomImportDeferredEnrichDecisionLog(String message) {
  final line = '[ROOM_IMPORT_DEFERRED_ENRICH_DECISION] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// マイページ手動「商品情報補完」の開始ログ（debug のみ）。
void roomImportManualEnrichStartLog(String message) {
  final line = '[ROOM_IMPORT_MANUAL_ENRICH_START] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportApiLog(String message) {
  final line = '[ROOM_IMPORT_API] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM 取り込み永続化の整合性（価格・画像の preserve 等）。
///
/// `changedPrice` 等は **DB が実際に書き換わったか**ではなく、
/// 「マージ結果として値が変わったか」のフラグ（誤って保存失敗と読まない）。
void roomImportSaveLog(String message) {
  final line = '[ROOM_IMPORT_SAVE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
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
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
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
  _roomImportEnrichFallbackTaggedBlockLog('ROOM_IMPORT_ENRICH_MODE', {
    'verifyMode': '$verifyMode',
  });
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
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM同期の既存行照合結果（APIスキップ・再同期判定用）。
void roomImportExistingMatchLog(String message) {
  final line = '[ROOM_IMPORT_EXISTING_MATCH] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportSameItemDifferentRoomLog(String message) {
  final line = '[ROOM_IMPORT_SAME_ITEM_DIFF_ROOM] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportFallbackLog(String message) {
  final line = '[ROOM_IMPORT_FALLBACK] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportItemCodeDiagLog(String message) {
  final line = '[ROOM_IMPORT_ITEMCODE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportItemApiParamsLog(String message) {
  final line = '[ROOM_IMPORT_ITEM_API_PARAMS] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportItemApiBlockedLog(String message) {
  final line = '[ROOM_IMPORT_ITEM_API_BLOCKED] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportItemApiSuccessLog(String message) {
  final line = '[ROOM_IMPORT_ITEM_API_SUCCESS] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichTargetLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_TARGET] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichApiLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_API] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichPausedLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_PAUSED] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichSuccessLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_SUCCESS] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM 取り込みメタ補完の **検証モード**（`ROOM_IMPORT_ENRICH_VERIFY`）専用ログ。
void roomImportVerifyLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_VERIFY] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
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
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichMethodLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_METHOD] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichFailLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_FAIL] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichQueueLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_QUEUE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichCooldownLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_COOLDOWN] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichRequestLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_REQUEST] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichSkipLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_SKIP] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichSummaryLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_SUMMARY] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 楽天 itemCode 補完APIの HTTP・プロキシ・レスポンス先頭の診断用。
void roomImportItemCodeApiDiagLog(String message) {
  final line = '[ROOM_IMPORT_ITEMCODE_API_DIAG] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportApiSummaryLog(String message) {
  final line = '[ROOM_IMPORT_API_SUMMARY] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportUiLog(String message) {
  final line = '[ROOM_IMPORT_UI] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM 取り込み prepare フェーズの内訳（計測用）。
void roomImportPrepareDetailLog(String field, int ms) {
  final line = '[ROOM_IMPORT_PREPARE_DETAIL] $field=${ms}ms';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM 一覧・collects の取得経路（ページング理由の切り分け用）。
void roomImportListingLog(String message) {
  final line = '[ROOM_IMPORT_LISTING] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// rat-redirect 1件分の詳細抽出（dest 多段デコード・URLパス・event 分解）。
void roomRatRedirectExtractLog(String message) {
  final line = '[ROOM_RAT_REDIRECT_EXTRACT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// rat-redirect `event` / `dest` 解析結果（採用1件分）。
void roomRedirectParseLog(String message) {
  final line = '[ROOM_REDIRECT_PARSE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomRedirectParseSourceLog(String message) {
  final line = '[ROOM_REDIRECT_PARSE_SOURCE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportSourceDecisionLog(String message) {
  final line = '[ROOM_IMPORT_SOURCE_DECISION] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomReactionSyncStopLog(String message) {
  final line = '[ROOM_REACTION_SYNC_STOP] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichApiCodeLearnedLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_API_CODE_LEARNED] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichDetailFetchForRedirectLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_DETAIL_FETCH_FOR_REDIRECT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportEnrichDetailFetchResultLog(String message) {
  final line = '[ROOM_IMPORT_ENRICH_DETAIL_FETCH_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportInitialEnrichStopLog(String message) {
  final line = '[ROOM_IMPORT_INITIAL_ENRICH_STOP] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
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
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportCollectsProgressLog(String message) {
  final line = '[ROOM_IMPORT_COLLECTS_PROGRESS] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportCollectsStopLog(String message) {
  final line = '[ROOM_IMPORT_COLLECTS_STOP] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM 取り込み後のメタ補完（enrichment）の打ち切り理由。
void roomImportEnrichStopLog(String reason) {
  final line = '[ROOM_IMPORT_ENRICH] stop reason=$reason';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 一覧HTML／collects 由来の楽天URL高速解決（ROOM 商品ページ GET 省略）の1件ログ。
void roomFastPathLog(String message) {
  final line = '[ROOM_FASTPATH] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 1バッチあとの高速パス集計（比較用）。
void roomFastPathSummaryLog(String message) {
  final line = '[ROOM_FASTPATH_SUMMARY] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportCursorLog(String message) {
  final line = '[ROOM_IMPORT_CURSOR] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomReactionSyncCursorLog(String message) {
  final line = '[ROOM_REACTION_SYNC_CURSOR] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomSyncJobLockLog(String message) {
  final line = '[ROOM_SYNC_JOB_LOCK] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportBatchStartLog(String message) {
  final line = '[ROOM_IMPORT_BATCH_START] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportBatchResultLog(String message) {
  final line = '[ROOM_IMPORT_BATCH_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 新規取り込み1件ごとの ROOM 一覧／商品ページから拾えた画像・価格ヒント。
void roomImportListingMetadataLog(String message) {
  final line = '[ROOM_IMPORT_LISTING_METADATA] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// ROOM 取り込み時に ROOM 側から直接取得したメタ（collects / 詳細HTML / rat-redirect）。
void roomImportRoomMetadataLog(String message) {
  final line = '[ROOM_IMPORT_ROOM_METADATA] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 楽天API補完: shopCode + 価格帯 + keyword 検索の条件ログ。
void roomImportApiSearchByPriceLog(String message) {
  final line = '[ROOM_IMPORT_API_SEARCH_BY_PRICE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 楽天API補完: 候補1件の同一商品判定ログ。
void roomImportApiCandidateMatchLog(String message) {
  final line = '[ROOM_IMPORT_API_CANDIDATE_MATCH] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

/// 楽天API補完: マージ成功時の保存内容ログ。
void roomImportApiSupplementSuccessLog(String message) {
  final line = '[ROOM_IMPORT_API_SUPPLEMENT_SUCCESS] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportInitialEnrichStartLog(String message) {
  final line = '[ROOM_IMPORT_INITIAL_ENRICH_START] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportInitialEnrichResultLog(String message) {
  final line = '[ROOM_IMPORT_INITIAL_ENRICH_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomReactionSyncStartLog(String message) {
  final line = '[ROOM_REACTION_SYNC_START] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomSyncButtonVisibilityLog(String message) {
  final line = '[ROOM_SYNC_BUTTON_VISIBILITY] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomSyncButtonRenderDecisionLog(String message) {
  final line = '[ROOM_SYNC_BUTTON_RENDER_DECISION] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportResultSheetCopyLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_SHEET_COPY] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void analyticsCountSourceLog(String message) {
  final line = '[ANALYTICS_COUNT_SOURCE] $message';
  if (kDebugMode) {
    debugPrint(line);
  }
}

void analyticsDailyBarLog(String message) {
  final line = '[ANALYTICS_DAILY_BAR] $message';
  if (kDebugMode) {
    debugPrint(line);
  }
}

void reactionStatusSaveLog(String message) {
  final line = '[REACTION_STATUS_SAVE] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void reactionStatusRenderLog(String message) {
  final line = '[REACTION_STATUS_RENDER] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportResultSheetRefreshLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_SHEET_REFRESH] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomImportResultSheetItemLog(String message) {
  final line = '[ROOM_IMPORT_RESULT_SHEET_ITEM] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomReactionSyncUiSummaryLog(String message) {
  final line = '[ROOM_REACTION_SYNC_UI_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomReactionSyncResultLog(String message) {
  final line = '[ROOM_REACTION_SYNC_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomBatchFetchPlanLog(String message) {
  final line = '[ROOM_BATCH_FETCH_PLAN] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomBatchFetchResultLog(String message) {
  final line = '[ROOM_BATCH_FETCH_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomBatchCompareResultLog(String message) {
  final line = '[ROOM_BATCH_COMPARE_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomBatchSaveResultLog(String message) {
  final line = '[ROOM_BATCH_SAVE_RESULT] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}

void roomSyncUiGuardLog(String message) {
  final line = '[ROOM_SYNC_UI_GUARD] $message';
  if (kDebugMode) {
    debugPrint(line);
    RoomImportDebugLogBuffer.add(line);
  }
}
