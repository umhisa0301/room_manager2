import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/comment_template.dart';

/// コメントテンプレートと直近コピーコメントの永続化を担当するリポジトリ。
class CommentTemplateRepository {
  CommentTemplateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyTemplates = 'comment_templates';
  static const String _keyLastCopied = 'last_copied_comment';

  List<CommentTemplate> loadTemplates() {
    try {
      final jsonStr = _prefs.getString(_keyTemplates);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr);
      if (list is! List) return [];
      final result = <CommentTemplate>[];
      for (final item in list) {
        final tmpl =
            CommentTemplate.fromJson(item is Map<String, dynamic> ? item : null);
        if (tmpl != null) result.add(tmpl);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  void saveTemplates(List<CommentTemplate> templates) {
    try {
      final list = templates.map((t) => t.toJson()).toList();
      _prefs.setString(_keyTemplates, jsonEncode(list));
    } catch (_) {
      // 保存失敗時もクラッシュさせない
    }
  }

  String? loadLastCopiedComment() {
    try {
      final value = _prefs.getString(_keyLastCopied);
      return value?.isEmpty ?? true ? null : value;
    } catch (_) {
      return null;
    }
  }

  void saveLastCopiedComment(String? value) {
    try {
      if (value == null || value.isEmpty) {
        _prefs.remove(_keyLastCopied);
      } else {
        _prefs.setString(_keyLastCopied, value);
      }
    } catch (_) {
      // 失敗してもクラッシュさせない
    }
  }
}

