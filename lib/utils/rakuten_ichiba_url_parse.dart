/// 楽天市場系URLから検索に使うヒントを抽出する（完全一致を保障しない）。
///
/// [itemCode] は楽天商品検索APIが解釈できる ** `shopCode:数字ID` ** 形式のときのみ設定する。
/// item.rakuten の第2パスセグメント（スラッグ）は [itemPath] に入れる。
class RakutenIchibaUrlHints {
  const RakutenIchibaUrlHints({
    this.shopCode,
    this.itemCode,
    this.itemPath,
  });

  final String? shopCode;

  /// Ichiba Item Search の入力用。`shop:12345` のような **API出力と同型** のときのみ。
  final String? itemCode;

  /// `item.rakuten.co.jp/{shop}/{ここ}/` のスラッグ。単独ではAPIの itemCode にはしない。
  final String? itemPath;

  bool get isEmpty =>
      (shopCode == null || shopCode!.isEmpty) &&
      (itemCode == null || itemCode!.isEmpty) &&
      (itemPath == null || itemPath!.isEmpty);
}

/// 公式ドキュメント上の itemCode 例は `shop:1234`（コロン＋数値ID）。
bool rakutenIchibaUrlLooksLikeApiItemCode(String value) {
  final t = value.trim();
  return RegExp(r'^[^:\s]+:[0-9]+$').hasMatch(t);
}

String? _pickQuery(Uri uri, List<String> keys) {
  for (final k in keys) {
    final v = uri.queryParameters[k];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  for (final e in uri.queryParameters.entries) {
    if (keys.any((k) => k.toLowerCase() == e.key.toLowerCase())) {
      final v = e.value.trim();
      if (v.isNotEmpty) return v;
    }
  }
  return null;
}

bool _looksLikeItemPathSegment(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 160) return false;
  return RegExp(r'^[0-9A-Za-z\-_%]+$').hasMatch(t);
}

String? _keywordGuessFromUrlText(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  try {
    final u = Uri.parse(t);
    final nonEmpty = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return null;
    final last = nonEmpty.last;
    if (last.length >= 2 && _looksLikeItemPathSegment(last)) {
      return last;
    }
  } catch (_) {}
  return null;
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
  String? apiItemCode;
  String? itemPath;

  final qItem = _pickQuery(uri, [
    'itemcode',
    'itemCode',
    'item_id',
    'itemId',
    'iid',
  ]);
  if (qItem != null && rakutenIchibaUrlLooksLikeApiItemCode(qItem)) {
    apiItemCode = qItem;
  }

  if (qItem != null && apiItemCode == null && _looksLikeItemPathSegment(qItem)) {
    itemPath ??= qItem;
  }

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
    if (_looksLikeItemPathSegment(seg1)) {
      itemPath ??= seg1;
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
    itemCode: apiItemCode?.trim().isEmpty ?? true ? null : apiItemCode!.trim(),
    itemPath: itemPath?.trim().isEmpty ?? true ? null : itemPath!.trim(),
  );
}

/// 優先順位4向け：パス末尾などからキーワード候補。
String? rakutenIchibaKeywordFallbackFromRawUrl(String raw) =>
    _keywordGuessFromUrlText(raw);
