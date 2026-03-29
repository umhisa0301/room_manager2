import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/xpath_selector_config.dart';

/// XPath 等のセレクタ設定を assets から読み込む。
class XPathConfigRepository {
  XPathConfigRepository._();

  static const String _assetPath = 'assets/config/xpath_config.json';

  /// 読み込み失敗時は例外を投げる。
  static Future<List<XPathSelectorConfig>> loadSelectors() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('xpath_config.json のルートがオブジェクトではありません');
    }
    final list = decoded['selectors'];
    if (list is! List) {
      throw FormatException('xpath_config.json に selectors 配列がありません');
    }
    final out = <XPathSelectorConfig>[];
    for (final entry in list) {
      final map = entry is Map<String, dynamic> ? entry : null;
      final sel = XPathSelectorConfig.fromJson(map);
      if (sel != null) out.add(sel);
    }
    if (out.isEmpty) {
      throw FormatException('xpath_config.json に有効な selectors がありません');
    }
    return out;
  }

  /// [name] に一致する最初のセレクタ（なければ null）。
  static Future<XPathSelectorConfig?> loadSelectorNamed(String name) async {
    final all = await loadSelectors();
    final n = name.trim();
    for (final s in all) {
      if (s.name == n) return s;
    }
    return null;
  }
}
