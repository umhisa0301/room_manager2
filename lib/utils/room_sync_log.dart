import 'package:flutter/foundation.dart';

/// ROOM 同期の詳細トレース（デバッグビルドのみ）。
void roomSyncLog(String message) {
  if (kDebugMode) {
    debugPrint('[ROOM_SYNC] $message');
  }
}

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
  if (!kDebugMode) return;
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
    final end =
        start + chunkSize > text.length ? text.length : start + chunkSize;
    debugPrint('[ROOM_SYNC] $label part$part: ${text.substring(start, end)}');
    start = end;
  }
}
