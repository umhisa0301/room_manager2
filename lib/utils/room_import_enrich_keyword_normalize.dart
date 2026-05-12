/// ROOM 取り込みメタ補完の楽天キーワード検索向けにタイトル由来文字列を短く安定させる。
abstract final class RoomImportEnrichKeywordNormalize {
  /// 検索 API に渡すキーワードの最大長（文字）。
  static const int maxKeywordChars = 36;

  /// [raw] を装飾・販促語を落として短くする。
  static String normalize(String raw) {
    var s = raw.replaceAll('\u3000', ' ');
    s = s.replaceAll(RegExp(r'[\r\n\t\f\v]+'), ' ');
    s = s.replaceAll(RegExp(r'【[^】]*】'), ' ');
    s = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    s = s.replaceAll(RegExp(r'（[^）]*）'), ' ');
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    for (final p in _promoLiterals) {
      s = s.replaceAll(p, ' ');
    }
    s = s.replaceAll(
      RegExp(r'\d+\s*[％%]\s*OFF', caseSensitive: false),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length <= maxKeywordChars) return s;
    return _truncatePreservingTokens(s, maxKeywordChars);
  }

  static const List<String> _promoLiterals = <String>[
    '送料無料',
    '送料 無料',
    'SALE',
    'sale',
    'Sale',
    'クーポン',
    'ランキング',
    '即日発送',
    'タイムセール',
    'タイム SALE',
    'セール',
  ];

  /// 空白区切りトークンを積み上げ、[maxChars] 付近で切る。
  static String _truncatePreservingTokens(String s, int maxChars) {
    if (s.length <= maxChars) return s;
    final parts = s.split(' ');
    final buf = StringBuffer();
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (buf.isEmpty) {
        buf.write(t);
        continue;
      }
      if (buf.length + 1 + t.length > maxChars) break;
      buf.write(' ');
      buf.write(t);
    }
    var out = buf.toString().trim();
    if (out.length > maxChars) {
      out = out.substring(0, maxChars).trim();
    }
    if (out.isEmpty) {
      out = s.substring(0, maxChars > s.length ? s.length : maxChars).trim();
    }
    return out;
  }
}
