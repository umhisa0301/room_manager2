import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/room_recommendation_profile.dart';

class RoomRecommendationProfileRepository {
  RoomRecommendationProfileRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'room_recommendation_profile_v1';
  static const String _diagnosisPromptSkippedKey =
      'room_diagnosis_prompt_skipped_v1';

  RoomRecommendationProfile? load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      return RoomRecommendationProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RoomRecommendationProfile profile) async {
    await _prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    await _prefs.remove(_diagnosisPromptSkippedKey);
  }

  /// 「診断せずに見る」選択後は、診断完了までBottomSheetを再表示しない。
  bool isDiagnosisPromptSkipped() =>
      _prefs.getBool(_diagnosisPromptSkippedKey) ?? false;

  Future<void> setDiagnosisPromptSkipped(bool skipped) async {
    if (skipped) {
      await _prefs.setBool(_diagnosisPromptSkippedKey, true);
    } else {
      await _prefs.remove(_diagnosisPromptSkippedKey);
    }
  }
}
