import 'package:shared_preferences/shared_preferences.dart';

/// コレ済タブの注意書きを「今後表示しない」で永続的に隠すための設定。
class DoneTabNoticeRepository {
  DoneTabNoticeRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keySuppress = 'room_done_tab_notice_suppress_v1';

  /// `true` のときコレ済タブ上部の注意 UI を出さない。
  bool get isSuppressed => _prefs.getBool(_keySuppress) ?? false;

  Future<void> suppressForever() async {
    await _prefs.setBool(_keySuppress, true);
  }
}
