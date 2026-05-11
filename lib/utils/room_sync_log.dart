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
  }) {
    if (!kDebugMode) return;
    if (!_sessionOpened) return;
    final itemCount = result?.processedCount ?? 0;
    final added = result?.newlyCollectedCount ?? 0;
    final updated = result?.roomUrlAddedCount ?? 0;
    final skipped = result?.skippedCount ?? 0;
    final failed = result?.failedCount ?? 0;
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
        'enrichmentCalls=$enrichmentCalls '
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

void roomImportApiLog(String message) {
  final line = '[ROOM_IMPORT_API] $message';
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
