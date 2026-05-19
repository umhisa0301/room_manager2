import 'package:flutter/foundation.dart';

/// ROOM取り込み・API補完時のフィールドマージ（空値で既存を上書きしない）。
abstract final class RoomImportSafeMerge {
  static bool isPresentString(String? value) {
    final t = (value ?? '').trim();
    return t.isNotEmpty && t != '-';
  }

  static bool isValidPrice(int? price) => price != null && price > 0;

  static String mergeString({
    required String field,
    required String existing,
    required String incoming,
    String productId = '',
    bool log = true,
  }) {
    final oldPresent = isPresentString(existing);
    final newPresent = isPresentString(incoming);
    if (!newPresent) {
      if (log && kDebugMode && oldPresent) {
        _log(
          productId: productId,
          field: field,
          oldValuePresent: true,
          newValuePresent: false,
          accepted: false,
          reason: 'keepExistingBecauseIncomingEmpty',
        );
      }
      return existing;
    }
    if (incoming.trim() == existing.trim()) {
      return existing;
    }
    if (log && kDebugMode) {
      _log(
        productId: productId,
        field: field,
        oldValuePresent: oldPresent,
        newValuePresent: true,
        accepted: true,
        reason: oldPresent ? 'acceptedApiValue' : 'acceptedRoomValue',
      );
    }
    return incoming.trim();
  }

  static int mergePrice({
    required String field,
    required int existing,
    required int incoming,
    String productId = '',
    bool log = true,
  }) {
    final oldPresent = isValidPrice(existing);
    final newPresent = isValidPrice(incoming);
    if (!newPresent) {
      if (log && kDebugMode && oldPresent) {
        _log(
          productId: productId,
          field: field,
          oldValuePresent: true,
          newValuePresent: false,
          accepted: false,
          reason: 'keepExistingBecauseIncomingEmpty',
        );
      }
      return existing;
    }
    if (incoming == existing) return existing;
    if (log && kDebugMode) {
      _log(
        productId: productId,
        field: field,
        oldValuePresent: oldPresent,
        newValuePresent: true,
        accepted: true,
        reason: oldPresent ? 'acceptedApiValue' : 'acceptedRoomValue',
      );
    }
    return incoming;
  }

  static void logMergeDecision({
    required String productId,
    required String field,
    required bool beforePresent,
    required bool incomingPresent,
    required bool afterPresent,
    required bool keptExisting,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_ENRICH_MERGE_DECISION] productId=$productId '
      'field=$field before=${beforePresent ? 'present' : 'empty'} '
      'incoming=${incomingPresent ? 'present' : 'empty'} '
      'after=${afterPresent ? 'present' : 'empty'} '
      'keptExisting=$keptExisting reason=$reason',
    );
  }

  static void _log({
    required String productId,
    required String field,
    required bool oldValuePresent,
    required bool newValuePresent,
    required bool accepted,
    required String reason,
  }) {
    debugPrint(
      '[SAFE_MERGE_FIELD] productId=$productId field=$field '
      'oldValuePresent=$oldValuePresent newValuePresent=$newValuePresent '
      'accepted=$accepted reason=$reason',
    );
  }
}
