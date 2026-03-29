/// XPath / CSS 等のセレクタ設定（assets/config/xpath_config.json）の1要素。
class XPathSelectorConfig {
  const XPathSelectorConfig({
    required this.name,
    required this.type,
    required this.value,
    this.postLoadDelayMs = 0,
  });

  final String name;

  /// `xpath` または `css`（[value] は CSS セレクタ文字列）。
  final String type;
  final String value;

  /// ページ表示後に DOM が遅延描画される場合、評価前に待つミリ秒（0 で無効）。
  final int postLoadDelayMs;

  static XPathSelectorConfig? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = (json['name'] ?? '').toString().trim();
    final type = (json['type'] ?? '').toString().trim();
    final value = (json['value'] ?? '').toString();
    if (name.isEmpty || type.isEmpty || value.trim().isEmpty) return null;
    final delayRaw = json['postLoadDelayMs'];
    var delay = 0;
    if (delayRaw != null) {
      final n = delayRaw is num
          ? delayRaw.toInt()
          : int.tryParse(delayRaw.toString());
      if (n != null) {
        delay = n < 0 ? 0 : (n > 30000 ? 30000 : n);
      }
    }
    return XPathSelectorConfig(
      name: name,
      type: type,
      value: value,
      postLoadDelayMs: delay,
    );
  }
}
