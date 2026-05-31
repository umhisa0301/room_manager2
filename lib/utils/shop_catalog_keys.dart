/// 共通ショップカタログの ID・alias 生成。
abstract final class ShopCatalogKeys {
  static String? normalizeShopCode(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty || t.length > 64) return null;
    return t;
  }

  static String normalizeShopUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return '';
    var path = u.path;
    if (!path.endsWith('/') && path.isNotEmpty) {
      path = '$path/';
    }
    return '${u.scheme}://${u.host.toLowerCase()}$path';
  }

  static List<String> buildAliases({
    required String shopCode,
    String? shopUrl,
    List<String> extra = const [],
  }) {
    return mergeAliases(extra, [
      shopCode,
      if (normalizeShopUrl(shopUrl ?? '').isNotEmpty)
        normalizeShopUrl(shopUrl!),
    ]);
  }

  static List<String> mergeAliases(
    Iterable<String> a,
    Iterable<String> b,
  ) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in [...a, ...b]) {
      final t = raw.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
    }
    return out;
  }
}
