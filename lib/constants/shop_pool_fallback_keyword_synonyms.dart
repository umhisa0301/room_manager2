/// ShopPool fallback 用の検索キーワード同義語（小さく保ち、後で拡張しやすい形）。
abstract final class ShopPoolFallbackKeywordSynonyms {
  ShopPoolFallbackKeywordSynonyms._();

  static const Map<String, List<String>> byKeyword = <String, List<String>>{
    '水筒': <String>[
      '水筒',
      'ボトル',
      'マグボトル',
      'タンブラー',
      'ステンレスボトル',
      '保温',
      '保冷',
    ],
    'コーヒー': <String>[
      'コーヒー',
      '珈琲',
      'カフェ',
      'ドリップ',
      '豆',
      '焙煎',
    ],
    'ベビー': <String>[
      'ベビー',
      '赤ちゃん',
      '新生児',
      'キッズ',
      '子供',
      '子ども',
      'マタニティ',
    ],
  };

  /// 正規化キー（trim + 小文字）から同義語リストを返す。未定義は [keyword] のみ。
  static List<String> tokensFor(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const <String>[];
    final normalized = trimmed.toLowerCase();
    for (final entry in byKeyword.entries) {
      if (entry.key.toLowerCase() == normalized) {
        return List<String>.from(entry.value, growable: false);
      }
    }
    return <String>[trimmed];
  }
}
