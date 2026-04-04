import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/room_activity_event.dart';

/// 活動イベントをローカルに蓄積（後でリモートに差し替え可能な境界）。
class RoomActivityEventRepository {
  RoomActivityEventRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'room_activity_events_v1';
  static const int _maxEvents = 12000;

  List<RoomActivityEvent> loadAll() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <RoomActivityEvent>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final ev = RoomActivityEvent.fromJson(Map<String, dynamic>.from(e));
        if (ev != null) out.add(ev);
      }
      return out;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomActivityEventRepository] loadAll failed: $e\n$st');
      }
      return [];
    }
  }

  Future<void> append(RoomActivityEvent event) async {
    final list = loadAll()..add(event);
    if (list.length > _maxEvents) {
      list.removeRange(0, list.length - _maxEvents);
    }
    await _saveAll(list);
  }

  Future<void> _saveAll(List<RoomActivityEvent> list) async {
    final encoded = jsonEncode(
      list.map((e) => e.toJson()).toList(growable: false),
    );
    final ok = await _prefs.setString(_key, encoded);
    if (!ok) {
      throw Exception('活動ログの保存に失敗しました');
    }
  }
}
