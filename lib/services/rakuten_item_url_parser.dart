/// 楽天商品ページURLから shopCode / パス2番目 を抽出する（正規表現ベース）。
///
/// iOS / Android 共通の [String]・[RegExp] のみで動作。
class RakutenItemUrlParseResult {
  const RakutenItemUrlParseResult({
    required this.shopCode,
    required this.itemPathSegment,
    required this.rakutenUrl,
  });

  /// URL 1つ目のパスセグメント（ショップコード）。
  final String shopCode;

  /// URL 2つ目のパスセグメント（通常は数値ID。スラッグURLもそのまま保持）。
  final String itemPathSegment;

  /// 正規化した商品ページURL（https・末尾 `/`）。
  final String rakutenUrl;

  /// [RakutenManagedProduct.productId] / 楽天API itemCode と同一形式。
  String get compositeProductId => '$shopCode:$itemPathSegment';
}

class RakutenItemUrlParser {
  RakutenItemUrlParser._();

  /// ユーザー指定パターンをベースに、HTML 埋め込みで属性境界へ食い込まないよう `"` 等を除外。
  static final RegExp itemRakutenUrlPattern = RegExp(
    r'https?:\/\/item\.rakuten\.co\.jp\/([^\/?#"\s<>]+)\/([^\/?#"\s<>]+)',
    caseSensitive: false,
  );

  static RakutenItemUrlParseResult? tryParse(String rawUrl) {
    final m = itemRakutenUrlPattern.firstMatch(rawUrl.trim());
    if (m == null) return null;
    final shop = (m.group(1) ?? '').trim();
    final seg = (m.group(2) ?? '').trim();
    if (shop.isEmpty || seg.isEmpty) return null;
    return RakutenItemUrlParseResult(
      shopCode: shop,
      itemPathSegment: seg,
      rakutenUrl: 'https://item.rakuten.co.jp/$shop/$seg/',
    );
  }

  /// [htmlOrText] 内の最初の一致から解析。見つからなければ null。
  static RakutenItemUrlParseResult? findFirstInText(String htmlOrText) {
    final best = _pickBest(findAllMatchesInText(htmlOrText));
    return best;
  }

  static List<RakutenItemUrlParseResult> findAllMatchesInText(String htmlOrText) {
    final out = <RakutenItemUrlParseResult>[];
    for (final m in itemRakutenUrlPattern.allMatches(htmlOrText)) {
      final s = m.group(0);
      if (s == null) continue;
      final p = tryParse(s);
      if (p != null) out.add(p);
    }
    return out;
  }

  static RakutenItemUrlParseResult? _pickBest(List<RakutenItemUrlParseResult> list) {
    if (list.isEmpty) return null;
    for (final e in list) {
      if (RegExp(r'^[0-9]+$').hasMatch(e.itemPathSegment)) return e;
    }
    return list.first;
  }
}
