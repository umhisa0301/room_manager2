import 'package:flutter/services.dart';

import '../config/xpath_config.dart';

/// XPath 設定を assets から読み込む。
class XpathConfigLoader {
  static const String assetPath = 'assets/config/xpath_config.json';

  /// 解析に失敗した場合は null。
  Future<XpathConfig?> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return XpathConfig.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// 抽出に使う XPath 文字列（roomTargetUrl を優先、無ければ最初の xpath 型）。
  Future<String?> loadPrimaryXpathValue() async {
    final cfg = await load();
    if (cfg == null) return null;
    final named = cfg.byName('roomTargetUrl');
    if (named != null && named.type.toLowerCase() == 'xpath') {
      return named.value;
    }
    return cfg.firstXpath?.value;
  }
}
