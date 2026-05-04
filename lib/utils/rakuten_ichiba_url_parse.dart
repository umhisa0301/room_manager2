/// 楽天市場系URLから [shopCode] / [itemCode] らしき値を軽量抽出する（完全一致を保障しない）。
class RakutenIchibaUrlHints {
  const RakutenIchibaUrlHints({this.shopCode, this.itemCode});

  final String? shopCode;
  final String? itemCode;

  bool get isEmpty =>
      (shopCode == null || shopCode!.isEmpty) &&
      (itemCode == null || itemCode!.isEmpty);
}

String? _pickQuery(Uri uri, List<String> keys) {
  for (final k in keys) {
    final v = uri.queryParameters[k];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

bool _looksLikeItemSegment(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 120) return false;
  if (t.contains('.')) return false;
  return RegExp(r'^[0-9A-Za-z\-_%]+$').hasMatch(t);
}

/// [raw] は `https://item.rakuten.co.jp/...` や検索結果URLなど。
RakutenIchibaUrlHints parseRakutenIchibaUrlHints(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const RakutenIchibaUrlHints();

  Uri? uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasAuthority) {
    return const RakutenIchibaUrlHints();
  }

  String? shop;
  String? item;

  item ??= _pickQuery(uri, [
    'itemcode',
    'itemCode',
    'item_id',
    'itemId',
    'iid',
  ]);
  shop ??= _pickQuery(uri, [
    'shopcode',
    'shopCode',
    'sid',
    'shop_id',
  ]);

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  if (host.contains('item.rakuten.co.jp') && segments.length >= 2) {
    shop ??= segments[0];
    final seg1 = segments[1];
    if (_looksLikeItemSegment(seg1)) {
      item ??= seg1;
    }
  } else if ((host == 'www.rakuten.co.jp' || host.endsWith('.rakuten.co.jp')) &&
      segments.isNotEmpty) {
    final head = segments.first.toLowerCase();
    const skip = {'item', 'search', 's', 'review', 'ranking', 'category'};
    if (!skip.contains(head) && shop == null) {
      shop = segments[0];
    }
  }

  return RakutenIchibaUrlHints(
    shopCode: shop?.trim().isEmpty ?? true ? null : shop!.trim(),
    itemCode: item?.trim().isEmpty ?? true ? null : item!.trim(),
  );
}
