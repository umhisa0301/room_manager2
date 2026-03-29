import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 「コレする」後に外部へ遷移したあと、管理アプリ復帰時に一度だけ出すメッセージ用キュー。
/// 保持するのは商品名のみ（表示文言は UI 側で組み立て）。
class PendingCollectNoticeRepository {
  PendingCollectNoticeRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'pending_collect_notice_item_names_v1';

  Future<void> enqueuePendingCollectNotice(String itemName) async {
    final name = itemName.trim();
    if (name.isEmpty) return;
    final list = _readAll();
    list.add(name);
    await _prefs.setString(_key, jsonEncode(list));
  }

  /// 保存済みの商品名をすべて取り出してストレージから削除する（冪等）。
  Future<List<String>> consumeAllPendingItemNames() async {
    final list = _readAll();
    await _prefs.remove(_key);
    return list;
  }

  List<String> _readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
