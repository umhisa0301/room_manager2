import 'package:shared_preferences/shared_preferences.dart';

/// ROOM collects の `afterId` 再開位置（プロフィール単位・端末ローカル）。
///
/// [RoomImportCollectsExploreMode.deep] の先頭リクエスト、および通常モード終了時の更新に使用。
abstract final class RoomImportCollectsResumeStore {
  static String _key(String profileNormalized) =>
      'room_import_collects_afterId_${profileNormalized.trim().toLowerCase()}';

  static Future<String?> readAfterId(String profileNormalized) async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key(profileNormalized))?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  static Future<void> saveAfterId(
    String profileNormalized,
    String afterId,
  ) async {
    final v = afterId.trim();
    if (v.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(profileNormalized), v);
  }

  static Future<void> clearAfterId(String profileNormalized) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(profileNormalized));
  }
}
