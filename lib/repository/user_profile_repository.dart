import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'user_profile_v1';

  UserProfile load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const UserProfile();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      return UserProfile.fromJson(map);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> save(UserProfile profile) async {
    await _prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}
