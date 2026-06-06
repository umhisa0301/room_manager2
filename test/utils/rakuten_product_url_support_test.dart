import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/rakuten_product_url_support.dart';

void main() {
  group('RakutenProductUrlSupport.detectUnsupported', () {
    test('item.rakuten.co.jp は対象外にならない', () {
      expect(
        RakutenProductUrlSupport.detectUnsupported(
          'https://item.rakuten.co.jp/soukaidrink/4901085161999/',
        ),
        isNull,
      );
    });

    test('楽天BOOKS URL は unsupportedRakutenService', () {
      final d = RakutenProductUrlSupport.detectUnsupported(
        'https://books.rakuten.co.jp/rb/1234567890/',
      );
      expect(d, isNotNull);
      expect(d!.reason, RakutenProductUrlSupport.unsupportedReasonTag);
      expect(d.host, 'books.rakuten.co.jp');
      expect(d.serviceTag, 'books');
    });

    test('楽天ファッション brandavenue は unsupportedRakutenService', () {
      final d = RakutenProductUrlSupport.detectUnsupported(
        'https://brandavenue.rakuten.co.jp/item/abc123/',
      );
      expect(d, isNotNull);
      expect(d!.reason, RakutenProductUrlSupport.unsupportedReasonTag);
      expect(d.host, 'brandavenue.rakuten.co.jp');
      expect(d.serviceTag, 'fashion');
    });

    test('fashion.rakuten.co.jp は unsupportedRakutenService', () {
      final d = RakutenProductUrlSupport.detectUnsupported(
        'https://fashion.rakuten.co.jp/item/xyz/',
      );
      expect(d, isNotNull);
      expect(d!.serviceTag, 'fashion');
    });

    test('affiliate の pc= が BOOKS を指す場合も対象外', () {
      const booksUrl = 'https://books.rakuten.co.jp/rb/999/';
      final affiliate =
          'https://hb.afl.rakuten.co.jp/hgc/test/?pc=${Uri.encodeComponent(booksUrl)}';
      final d = RakutenProductUrlSupport.detectUnsupported(affiliate);
      expect(d, isNotNull);
      expect(d!.serviceTag, 'books');
    });

    test('affiliate の pc= が item.rakuten の場合は対象外にならない', () {
      const itemUrl =
          'https://item.rakuten.co.jp/soukaidrink/4901085161999/';
      final affiliate =
          'https://hb.afl.rakuten.co.jp/hgc/test/?pc=${Uri.encodeComponent(itemUrl)}';
      expect(RakutenProductUrlSupport.detectUnsupported(affiliate), isNull);
    });

    test('楽天以外の URL は null', () {
      expect(
        RakutenProductUrlSupport.detectUnsupported('https://example.com/x'),
        isNull,
      );
    });
  });
}
