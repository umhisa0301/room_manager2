import '../models/product.dart';
import '../models/product_search_hit.dart';

/// 商品検索ロジックを集約するサービス。
/// UIから分離し、今後のスコアリングや類似判定へ拡張しやすくする。
class ProductSearchService {
  ProductSearchService._();

  static List<ProductSearchHit> search(
    List<Product> source,
    String query,
  ) {
    final raw = query.trim();
    if (raw.isEmpty) {
      return source
          .map((p) => ProductSearchHit(product: p, matchKinds: const []))
          .toList();
    }

    final qText = _normalizeText(raw);
    final qUrl = _normalizeUrl(raw);
    final qLooksLikeUrl = _looksLikeUrl(raw);
    final results = <ProductSearchHit>[];

    for (final p in source) {
      final kinds = <ProductMatchKind>{};

      final name = _normalizeText(p.productName);
      final memo = _normalizeText(p.memo ?? '');
      final quick = _normalizeText(p.quickComment ?? '');
      final tags = p.tags.map(_normalizeText).join(' ');

      final rawUrlLower = p.productUrl.trim().toLowerCase();
      final normalizedUrl = _normalizeUrl(p.productUrl);

      if (name.contains(qText)) kinds.add(ProductMatchKind.productName);
      if (memo.contains(qText)) kinds.add(ProductMatchKind.memo);
      if (quick.contains(qText)) kinds.add(ProductMatchKind.quickComment);
      if (tags.contains(qText)) kinds.add(ProductMatchKind.tags);
      if (rawUrlLower.contains(raw.toLowerCase()) || normalizedUrl.contains(qUrl)) {
        kinds.add(ProductMatchKind.productUrl);
      }

      if (qLooksLikeUrl && qUrl.isNotEmpty && normalizedUrl == qUrl) {
        kinds.add(ProductMatchKind.urlExact);
      }

      if (kinds.isNotEmpty) {
        // URL一致を先頭にして視認性を上げる
        final sorted = kinds.toList()
          ..sort((a, b) {
            if (a == ProductMatchKind.urlExact) return -1;
            if (b == ProductMatchKind.urlExact) return 1;
            return a.index.compareTo(b.index);
          });
        results.add(ProductSearchHit(product: p, matchKinds: sorted));
      }
    }

    return results;
  }

  /// 商品名など向けの軽量正規化（大小文字、全角空白、余分な空白を吸収）
  static String _normalizeText(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('\u3000', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// URL向けの軽量正規化（前後空白、末尾スラッシュ、大小文字差異を吸収）
  static String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    try {
      final uri = Uri.parse(trimmed);
      final scheme = uri.scheme.toLowerCase();
      final host = uri.host.toLowerCase();
      var path = uri.path;
      while (path.endsWith('/') && path.length > 1) {
        path = path.substring(0, path.length - 1);
      }
      final query = uri.query.isEmpty ? '' : '?${uri.query}';
      if (host.isEmpty) return trimmed.toLowerCase();
      return '$scheme://$host$path$query';
    } catch (_) {
      var text = trimmed.toLowerCase();
      while (text.endsWith('/') && text.length > 1) {
        text = text.substring(0, text.length - 1);
      }
      return text;
    }
  }

  static bool _looksLikeUrl(String input) {
    final v = input.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://') || v.contains('.jp/');
  }
}

