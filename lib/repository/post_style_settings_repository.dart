import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_style_settings.dart';

class PostStyleSettingsRepository {
  PostStyleSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'post_style_settings_v1';

  PostStyleSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return PostStyleSettings.defaults();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      return PostStyleSettings.fromJson(map);
    } catch (_) {
      return PostStyleSettings.defaults();
    }
  }

  Future<void> save(PostStyleSettings settings) async {
    await _prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
