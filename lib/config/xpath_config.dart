import 'dart:convert';

/// assets の XPath 設定（将来セレクタを差し替えやすい形）。
class XpathSelectorEntry {
  const XpathSelectorEntry({
    required this.name,
    required this.type,
    required this.value,
  });

  final String name;
  final String type;
  final String value;

  static XpathSelectorEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = (json['name'] ?? '').toString().trim();
    final type = (json['type'] ?? '').toString().trim();
    final value = (json['value'] ?? '').toString();
    if (name.isEmpty || type.isEmpty || value.trim().isEmpty) return null;
    return XpathSelectorEntry(name: name, type: type, value: value.trim());
  }
}

class XpathConfig {
  const XpathConfig({required this.selectors});

  final List<XpathSelectorEntry> selectors;

  /// [name] に一致する最初のセレクタ（無ければ null）。
  XpathSelectorEntry? byName(String name) {
    for (final s in selectors) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// type が xpath の最初のセレクタ。
  XpathSelectorEntry? get firstXpath {
    for (final s in selectors) {
      if (s.type.toLowerCase() == 'xpath') return s;
    }
    return null;
  }

  static XpathConfig? parse(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;
      final raw = decoded['selectors'];
      if (raw is! List) return null;
      final list = <XpathSelectorEntry>[];
      for (final e in raw) {
        final m = e is Map<String, dynamic> ? e : null;
        final s = XpathSelectorEntry.fromJson(m);
        if (s != null) list.add(s);
      }
      return XpathConfig(selectors: list);
    } catch (_) {
      return null;
    }
  }
}
