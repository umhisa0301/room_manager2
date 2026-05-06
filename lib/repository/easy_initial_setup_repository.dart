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

  bool get isDismissed => _prefs.getBool(dismissedKey) ?? false;

  /// アップデート済みユーザーがウィザードを毎回見ないよう、初回のみ規約同意済みなら省略する。
  void _migrateLegacyInstall() {
    if (_prefs.containsKey(dismissedKey)) return;
    final accepted = _prefs.getBool(LegalConsentRepository.acceptedKey) ?? false;
    if (accepted) {
      _prefs.setBool(dismissedKey, true);
    }
  }

  Future<void> dismiss() async {
    await _prefs.setBool(dismissedKey, true);
    notifyListeners();
  }
}
