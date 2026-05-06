import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legal_consent_repository.dart';

/// 「かんたん初期設定」ウィザードを自動表示しないようにするフラグ（スキップ／完了／あとで）。
class EasyInitialSetupRepository extends ChangeNotifier {
  EasyInitialSetupRepository(this._prefs) {
    _migrateLegacyInstall();
  }

  final SharedPreferences _prefs;

  static const dismissedKey = 'easy_initial_setup_dismissed_v1';

  /// ウィザードを最後まで完了した（「はじめる」）とき true。
  static const completedKey = 'easy_initial_setup_flow_completed_v1';

  /// スキップ／「あとで設定する」で閉じたとき true。
  static const skippedKey = 'easy_initial_setup_flow_skipped_v1';

  bool get isDismissed => _prefs.getBool(dismissedKey) ?? false;

  bool get initialSetupCompleted => _prefs.getBool(completedKey) ?? false;

  bool get initialSetupSkipped => _prefs.getBool(skippedKey) ?? false;

  /// 端末に既に利用データがある（アップデート相当）ときだけウィザードを自動スキップする。
  static bool legacyAppUsageSignals(SharedPreferences prefs) {
    final rawList = prefs.getString('rakuten_room_managed_products_v1');
    if (rawList != null && rawList.trim().length > 2) {
      try {
        final decoded = jsonDecode(rawList);
        if (decoded is List && decoded.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }
    final prof = prefs.getString('user_profile_v1');
    if (prof != null && prof.trim().isNotEmpty) {
      try {
        final map = jsonDecode(prof) as Map<String, dynamic>?;
        final url = (map?['roomUrl'] as String?) ?? '';
        if (url.trim().isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }
    final shops = prefs.getString('saved_shops_v1');
    if (shops != null && shops.trim().length > 2) {
      try {
        final decoded = jsonDecode(shops);
        if (decoded is List && decoded.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// アップデート済みユーザーがウィザードを毎回見ないよう、**既存利用の痕跡がある**規約同意済みのみ省略する。
  void _migrateLegacyInstall() {
    if (_prefs.containsKey(dismissedKey)) return;
    final accepted = _prefs.getBool(LegalConsentRepository.acceptedKey) ?? false;
    if (!accepted) return;
    if (legacyAppUsageSignals(_prefs)) {
      _prefs.setBool(dismissedKey, true);
    }
  }

  Future<void> dismiss({
    bool markFlowCompleted = false,
    bool markFlowSkipped = false,
  }) async {
    if (markFlowCompleted) {
      await _prefs.setBool(completedKey, true);
      await _prefs.setBool(skippedKey, false);
    } else if (markFlowSkipped) {
      await _prefs.setBool(skippedKey, true);
    }
    await _prefs.setBool(dismissedKey, true);
    notifyListeners();
  }
}
