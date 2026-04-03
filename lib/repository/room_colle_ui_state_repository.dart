import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/room_colle_list_filters.dart';

/// ROOMコレ画面の UI 状態（タブ・フィルタ）を永続化する。破損時はデフォルトへフォールバック。
class RoomColleUiStateRepository {
  RoomColleUiStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'room_colle_ui_state_v1';
  static const int _maxSearchLen = 512;
  static const int _schemaV2 = 2;
  static const int _schemaV3 = 3;

  /// 読み込みと検証。失敗時は [RoomColleUiStateSnapshot.defaults] を返し、必要なら永続を削除。
  RoomColleUiStateSnapshot loadSanitized() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) {
        return RoomColleUiStateSnapshot.defaults;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _logInitFailure('root_not_map');
        unawaited(clearPersisted());
        return RoomColleUiStateSnapshot.defaults;
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

      final schemaRaw = map['schema'];
      final schemaNum = schemaRaw is int
          ? schemaRaw
          : schemaRaw is num
              ? schemaRaw.toInt()
              : 0;

      final hasV3 = schemaNum == _schemaV3 ||
          (map['candidateListFilters'] is Map && map['doneListFilters'] is Map);

      if (hasV3) {
        final exRaw = map['candidateExcludeUrlNotReady'];
        final exclude = exRaw is bool ? exRaw : false;
        var cFilters = RoomColleListFilterCriteria.fromJson(
          map['candidateListFilters'],
        );
        var dFilters =
            RoomColleListFilterCriteria.fromJson(map['doneListFilters']);

        void legacyHydrateKeyword() {
          var candidateQ = '';
          final cq = map['candidateSearchQuery'];
          if (cq is String) {
            candidateQ = _sanitizeSearchQuery(cq);
          }
          var doneQ = '';
          final dq = map['doneSearchQuery'];
          if (dq is String) {
            doneQ = _sanitizeSearchQuery(dq);
          }
          if (candidateQ.isNotEmpty && cFilters.keyword.isEmpty) {
            cFilters = cFilters.copyWith(keyword: candidateQ);
          }
          if (doneQ.isNotEmpty && dFilters.keyword.isEmpty) {
            dFilters = dFilters.copyWith(keyword: doneQ);
          }
        }

        if (schemaNum != _schemaV3) {
          legacyHydrateKeyword();
        }

        cFilters = _sanitizeFilterCriteriaKeywords(cFilters);
        dFilters = _sanitizeFilterCriteriaKeywords(dFilters);

        final pileBannerRaw = map['staleCandidatePileBannerDismissed'];
        final pileBannerDismissed =
            pileBannerRaw is bool ? pileBannerRaw : false;

        return RoomColleUiStateSnapshot(
          tabIndex: tabIndex,
          candidateListFilters: cFilters,
          doneListFilters: dFilters,
          candidateExcludeUrlNotReady: exclude,
          doneLocalDay: doneLocalDay,
          staleCandidatePileBannerDismissed: pileBannerDismissed,
        );
      }

      final hasV2 = schemaRaw == _schemaV2 ||
          map['candidateSearchQuery'] != null ||
          map['doneSearchQuery'] != null;

      if (hasV2) {
        var candidateQ = '';
        final cq = map['candidateSearchQuery'];
        if (cq is String) {
          candidateQ = _sanitizeSearchQuery(cq);
        }
        var doneQ = '';
        final dq = map['doneSearchQuery'];
        if (dq is String) {
          doneQ = _sanitizeSearchQuery(dq);
        }
        final exRaw = map['candidateExcludeUrlNotReady'];
        final exclude =
            exRaw is bool ? exRaw : false;

        return RoomColleUiStateSnapshot(
          tabIndex: tabIndex,
          candidateListFilters:
              RoomColleListFilterCriteria(keyword: candidateQ),
          doneListFilters: RoomColleListFilterCriteria(keyword: doneQ),
          candidateExcludeUrlNotReady: exclude,
          doneLocalDay: doneLocalDay,
        );
      }

      /// 旧スキーマ（1本の searchQuery・excludeUrlNotReady）
      final excludeRaw = map['excludeUrlNotReady'];
      final excludeUrlNotReady = excludeRaw is bool ? excludeRaw : false;
      var legacyQ = '';
      final q = map['searchQuery'];
      if (q is String) {
        legacyQ = _sanitizeSearchQuery(q);
      }

      return RoomColleUiStateSnapshot(
        tabIndex: tabIndex,
        candidateListFilters: RoomColleListFilterCriteria(keyword: legacyQ),
        doneListFilters: RoomColleListFilterCriteria(keyword: legacyQ),
        candidateExcludeUrlNotReady: excludeUrlNotReady,
        doneLocalDay: doneLocalDay,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomColleUiState] loadSanitized exception: $e\n$st');
      }
      unawaited(clearPersisted());
      return RoomColleUiStateSnapshot.defaults;
    }
  }

  Future<void> saveSanitized(RoomColleUiStateSnapshot snap) async {
    try {
      final cSan = _sanitizeFilterCriteriaKeywords(snap.candidateListFilters);
      final dSan = _sanitizeFilterCriteriaKeywords(snap.doneListFilters);
      final map = <String, dynamic>{
        'schema': _schemaV3,
        'tabIndex': snap.tabIndex.clamp(0, 1),
        'candidateSearchQuery': _sanitizeSearchQuery(cSan.keyword),
        'doneSearchQuery': _sanitizeSearchQuery(dSan.keyword),
        'candidateListFilters': cSan.toJson(),
        'doneListFilters': dSan.toJson(),
        'candidateExcludeUrlNotReady': snap.candidateExcludeUrlNotReady,
        'doneLocalDay': snap.doneLocalDay?.toIso8601String(),
        'staleCandidatePileBannerDismissed':
            snap.staleCandidatePileBannerDismissed,
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

  RoomColleListFilterCriteria _sanitizeFilterCriteriaKeywords(
    RoomColleListFilterCriteria c,
  ) {
    return c.copyWith(keyword: _sanitizeSearchQuery(c.keyword));
  }

  void _logInitFailure(String reason) {
    if (kDebugMode) {
      debugPrint('[RoomColleUiState] loadSanitized fallback: $reason');
    }
  }
}

/// ROOMコレ画面上部のユーザー操作状態（一覧データとは別）。
/// 候補タブ用・コレ済タブ用の [RoomColleListFilterCriteria] と URL 除外を分離して保存する。
class RoomColleUiStateSnapshot {
  const RoomColleUiStateSnapshot({
    required this.tabIndex,
    required this.candidateListFilters,
    required this.doneListFilters,
    required this.candidateExcludeUrlNotReady,
    this.doneLocalDay,
    this.staleCandidatePileBannerDismissed = false,
  });

  final int tabIndex;

  /// コレ候補タブの絞り込み（キーワード＋拡張条件）。
  final RoomColleListFilterCriteria candidateListFilters;

  /// コレ済タブの絞り込み。
  final RoomColleListFilterCriteria doneListFilters;

  final bool candidateExcludeUrlNotReady;
  final DateTime? doneLocalDay;

  /// 7日超候補が5件以上のときのナッジバナーをユーザーが閉じたか（候補タブ用）。
  final bool staleCandidatePileBannerDismissed;

  /// 永続 v2 / UI 互換用。常に [candidateListFilters.keyword] と一致。
  String get candidateSearchQuery => candidateListFilters.keyword;

  /// 永続 v2 / UI 互換用。常に [doneListFilters.keyword] と一致。
  String get doneSearchQuery => doneListFilters.keyword;

  static const RoomColleUiStateSnapshot defaults = RoomColleUiStateSnapshot(
    tabIndex: 0,
    candidateListFilters: RoomColleListFilterCriteria.defaults,
    doneListFilters: RoomColleListFilterCriteria.defaults,
    candidateExcludeUrlNotReady: false,
    doneLocalDay: null,
    staleCandidatePileBannerDismissed: false,
  );
}
