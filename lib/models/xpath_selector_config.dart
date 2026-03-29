/// XPath 設定ファイル（assets/config/xpath_config.json）の1要素。
class XPathSelectorConfig {
  const XPathSelectorConfig({
    required this.name,
    required this.type,
    required this.value,
  });

  final String name;
  final String type;
  final String value;

  static XPathSelectorConfig? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = (json['name'] ?? '').toString().trim();
    final type = (json['type'] ?? '').toString().trim();
    final value = (json['value'] ?? '').toString();
    if (name.isEmpty || type.isEmpty || value.trim().isEmpty) return null;
    return XPathSelectorConfig(name: name, type: type, value: value);
  }
}
