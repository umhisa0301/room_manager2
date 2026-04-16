import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/demo_mode.dart';
import '../data/demo_mode_data.dart';
import '../models/today_recommendation.dart';

class TodayRecommendationRepository {
  TodayRecommendationRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'today_recommendation_bundle_v1';

  TodayRecommendationBundle? load() {
    if (kDemoModeEnabled) {
      return DemoModeData.todayRecommendationBundle();
    }
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return TodayRecommendationBundle.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(TodayRecommendationBundle bundle) async {
    if (kDemoModeEnabled) {
      return;
    }
    await _prefs.setString(_key, jsonEncode(bundle.toJson()));
  }
}
