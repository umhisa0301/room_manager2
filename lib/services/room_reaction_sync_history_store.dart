import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_reaction_sync_history_entry.dart';

/// 反応同期結果の直近履歴（分析向け・端末ローカル）。
abstract final class RoomReactionSyncHistoryStore {
  static const String _key = 'room_reaction_sync_history_v1_json';
  static const int _maxEntries = 25;

  static Future<RoomReactionSyncHistoryEntry?> appendFromBatchResult(
    RoomReactionSyncBatchResult r,
  ) async {
    if (r.hasFatalError) return null;
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    final entry = RoomReactionSyncHistoryEntry(
      syncedAtIso: now,
      checkedItems: r.itemsChecked,
      updatedItems: r.updated,
      likeIncreasedItems: r.likeIncreasedItems,
      commentIncreasedItems: r.commentIncreasedItems,
      unchangedItems: r.unchangedItems,
      hasReactionItems: r.hasReactionItems,
      commentedItems: r.commentedItems,
      stopReason: r.stopReason ?? '',
      hasNextCursor: r.nextCursor != null && r.nextCursor!.trim().isNotEmpty,
      topReactedProducts: r.topReactedProducts,
    );
    final prev = await loadEntries();
    final next = <RoomReactionSyncHistoryEntry>[entry, ...prev];
    while (next.length > _maxEntries) {
      next.removeLast();
    }
    final lines = next.map((e) => jsonEncode(e.toJson())).toList();
    await p.setStringList(_key, lines);
    return entry;
  }

  static Future<RoomReactionSyncHistoryEntry?> loadLatest() async {
    final all = await loadEntries();
    return all.isEmpty ? null : all.first;
  }

  static Future<List<RoomReactionSyncHistoryEntry>> loadEntries() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key);
    if (raw == null || raw.isEmpty) return const [];
    final out = <RoomReactionSyncHistoryEntry>[];
    for (final line in raw) {
      try {
        final m = jsonDecode(line);
        if (m is! Map<String, dynamic>) continue;
        final e = RoomReactionSyncHistoryEntry.fromJson(m);
        if (e != null) out.add(e);
      } catch (_) {}
    }
    return out;
  }
}
