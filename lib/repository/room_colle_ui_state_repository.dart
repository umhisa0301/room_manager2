import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ROOMコレ画面の UI 状態（タブ・フィルタ）を永続化する。破損時はデフォルトへフォールバック。
class RoomColleUiStateRepository {
  RoomColleUiStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'room_colle_ui_state_v1';
  static const int _maxSearchLen = 512;

  /// 読み込みと検証。失敗時は [RoomColleUiStateSnapshot.defaults] を返し、必要なら永続を削除。
  RoomColleUiStateSnapshot loadSanitized() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) {
        return RoomColleUiStateSnapshot.defaults();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _logInitFailure('root_not_map');
        unawaited(clearPersisted());
        return RoomColleUiStateSnapshot.defaults();
      }
      final map = Map<String, dynamic>.from(decoded);
      final tabRaw = map['tabIndex'];
      var tabIndex = 0;
      if (tabRaw is int) {
        tabIndex = tabRaw;
      } else if (tabRaw is num) {
        tabIndex = tabRaw.toInt();
      }
      if (tabIndex < 0 || tabIndex > 1) {
        _logInitFailure('bad_tabIndex=$tabIndex');
        tabIndex = 0;
      }

      final excludeRaw = map['excludeUrlNotReady'];
      final excludeUrlNotReady = excludeRaw is bool ? excludeRaw : false;

      var searchQuery = '';
      final q = map['searchQuery'];
      if (q is String) {
        searchQuery = _sanitizeSearchQuery(q);
      }

      DateTime? doneLocalDay;
      final d = map['doneLocalDay'];
      if (d is String && d.isNotEmpty) {
        try {
          final parsed = DateTime.parse(d);
          final y = parsed.year;
          if (y >= 1900 && y <= 2100) {
            doneLocalDay = DateTime(parsed.year, parsed.month, parsed.day);
          } else {
            _logInitFailure('done_day_year_out_of_range');
          }
        } catch (_) {
          _logInitFailure('done_day_parse_failed');
        }
      }

      return RoomColleUiStateSnapshot(
        tabIndex: tabIndex,
        searchQuery: searchQuery,
        excludeUrlNotReady: excludeUrlNotReady,
        doneLocalDay: doneLocalDay,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomColleUiState] loadSanitized exception: $e\n$st');
      }
      unawaited(clearPersisted());
      return RoomColleUiStateSnapshot.defaults();
    }
  }

  Future<void> saveSanitized(RoomColleUiStateSnapshot snap) async {
    try {
      final map = <String, dynamic>{
        'tabIndex': snap.tabIndex.clamp(0, 1),
        'searchQuery': _sanitizeSearchQuery(snap.searchQuery),
        'excludeUrlNotReady': snap.excludeUrlNotReady,
        'doneLocalDay': snap.doneLocalDay?.toIso8601String(),
      };
      await _prefs.setString(_key, jsonEncode(map));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomColleUiState] saveSanitized failed: $e\n$st');
      }
    }
  }

  Future<void> clearPersisted() async {
    try {
      await _prefs.remove(_key);
      if (kDebugMode) {
        debugPrint('[RoomColleUiState] clearPersisted: key removed');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomColleUiState] clearPersisted failed: $e\n$st');
      }
    }
  }

  String _sanitizeSearchQuery(String q) {
    final t = q.replaceAll('\u0000', '').trim();
    if (t.length <= _maxSearchLen) return t;
    return t.substring(0, _maxSearchLen);
  }

  void _logInitFailure(String reason) {
    if (kDebugMode) {
      debugPrint('[RoomColleUiState] loadSanitized fallback: $reason');
    }
  }
}

/// ROOMコレ画面上部のユーザー操作状態（一覧データとは別）。
class RoomColleUiStateSnapshot {
  const RoomColleUiStateSnapshot({
    required this.tabIndex,
    required this.searchQuery,
    required this.excludeUrlNotReady,
    this.doneLocalDay,
  });

  final int tabIndex;
  final String searchQuery;
  final bool excludeUrlNotReady;
  final DateTime? doneLocalDay;

  static RoomColleUiStateSnapshot defaults() => const RoomColleUiStateSnapshot(
        tabIndex: 0,
        searchQuery: '',
        excludeUrlNotReady: false,
        doneLocalDay: null,
      );
}
