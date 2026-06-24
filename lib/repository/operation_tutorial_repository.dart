import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/operation_tutorial_id.dart';

/// 操作ガイド（チュートリアル）の完了・スキップ状態。
/// [EasyInitialSetupRepository] とはキーを完全に分離する。
class OperationTutorialRepository extends ChangeNotifier {
  OperationTutorialRepository(this._prefs);

  final SharedPreferences _prefs;

  static const profileDismissedKey = 'operation_tutorial_profile_dismissed_v1';
  static const profileCompletedKey = 'operation_tutorial_profile_completed_v1';
  static const profileSkippedKey = 'operation_tutorial_profile_skipped_v1';

  bool isDismissed(OperationTutorialId id) {
    switch (id) {
      case OperationTutorialId.profile:
        return _prefs.getBool(profileDismissedKey) ?? false;
    }
  }

  bool isCompleted(OperationTutorialId id) {
    switch (id) {
      case OperationTutorialId.profile:
        return _prefs.getBool(profileCompletedKey) ?? false;
    }
  }

  bool isSkipped(OperationTutorialId id) {
    switch (id) {
      case OperationTutorialId.profile:
        return _prefs.getBool(profileSkippedKey) ?? false;
    }
  }

  Future<void> dismiss({
    required OperationTutorialId id,
    bool markCompleted = false,
    bool markSkipped = false,
  }) async {
    switch (id) {
      case OperationTutorialId.profile:
        if (markCompleted) {
          await _prefs.setBool(profileCompletedKey, true);
          await _prefs.setBool(profileSkippedKey, false);
        } else if (markSkipped) {
          await _prefs.setBool(profileCompletedKey, false);
          await _prefs.setBool(profileSkippedKey, true);
        }
        await _prefs.setBool(profileDismissedKey, true);
        break;
    }
    notifyListeners();
  }
}
