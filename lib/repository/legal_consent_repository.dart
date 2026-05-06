import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 利用規約・プライバシー同意のローカル永続化。
class LegalConsentRepository extends ChangeNotifier {
  LegalConsentRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String acceptedKey = 'legal_terms_accepted_v1';

  bool get isAccepted => _prefs.getBool(acceptedKey) ?? false;

  Future<void> setAccepted() async {
    await _prefs.setBool(acceptedKey, true);
    notifyListeners();
  }
}
