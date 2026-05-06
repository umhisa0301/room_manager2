import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';

void main() {
  group('ProductUrlResolver.resolveRakutenOpenUrl', () {
    test('affiliateUrl が最優先', () {
      final p = _p(
        affiliateUrl: 'https://hb.afl.rakuten.co.jp/hoge',
        itemUrl: 'https://item.rakuten.co.jp/a/b/',
        rakutenUrl: 'https://item.rakuten.co.jp/c/d/',
      );
      expect(ProductUrlResolver.resolveRakutenOpenUrl(p), p.affiliateUrl);
    });

    test('affiliateUrl が無ければ itemUrl', () {
      final p = _p(
        itemUrl: 'https://item.rakuten.co.jp/a/b/',
        rakutenUrl: 'https://item.rakuten.co.jp/c/d/',
      );
      expect(ProductUrlResolver.resolveRakutenOpenUrl(p), p.itemUrl);
    });

    test('affiliate と item が空なら rakutenUrl', () {
      final p = _p(
        itemUrl: '',
        rakutenUrl: 'https://item.rakuten.co.jp/c/d/',
      );
      expect(ProductUrlResolver.resolveRakutenOpenUrl(p), p.rakutenUrl);
    });
  });
}

RakutenManagedProduct _p({
  String? affiliateUrl,
  String itemUrl = '',
  String? rakutenUrl,
}) {
  final t = DateTime.parse('2024-06-01T12:00:00.000Z');
  return RakutenManagedProduct(
    productId: 'x:1',
    itemName: 'n',
    itemPrice: 0,
    itemUrl: itemUrl,
    affiliateUrl: affiliateUrl,
    rakutenUrl: rakutenUrl,
    imageUrl: '',
    shopName: '',
    shopCode: '',
    shopUrl: '',
    genreId: '',
    status: RakutenManagedProductStatus.candidate,
    createdAt: t,
    updatedAt: t,
    addedAt: t,
    extractedUrl: '',
    extractionStatus: RakutenUrlExtractionStatus.notStarted,
    extractionErrorMessage: '',
  );
}
