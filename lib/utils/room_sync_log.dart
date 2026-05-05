import 'package:flutter/foundation.dart';

/// URL一覧・HTMLプレビューなどROOM取り込みの詳細ログ。通常は false。
bool debugVerboseRoomImport = false;

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
    debugPrint('[ROOM_SYNC][WARN] $message');
  }
}

void roomSyncError(String message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('[ROOM_SYNC][ERROR] $message');
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
    debugPrint('[ROOM_SYNC] $label part$part: ${text.substring(start, end)}');
    start = end;
  }
}
