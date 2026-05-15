import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/utils/room_import_product_url_match.dart';

void main() {
  group('roomImportEvaluateApiCandidateMatch', () {
    test('shop and url slug match accepts candidate', () {
      const item = RakutenSearchItem(
        productId: 'shop:12345',
        itemName: 'テスト商品',
        itemPrice: 1980,
        itemUrl: 'https://item.rakuten.co.jp/mystore/product-slug/',
        affiliateUrl: '',
        imageUrl: '',
        shopName: 'テスト店',
        shopCode: 'mystore',
      );
      final m = roomImportEvaluateApiCandidateMatch(
        item: item,
        roomShopCode: 'mystore',
        roomUrlProductCode: 'product-slug',
        roomPrice: 1980,
      );
      expect(m.shopMatched, isTrue);
      expect(m.urlSlugMatched, isTrue);
      expect(m.matched, isTrue);
      expect(m.reason, 'shopAndPriceAndUrlSlugMatched');
    });

    test('price match alone does not accept candidate', () {
      const item = RakutenSearchItem(
        productId: 'shop:99999',
        itemName: '別商品',
        itemPrice: 1980,
        itemUrl: 'https://item.rakuten.co.jp/mystore/other-slug/',
        affiliateUrl: '',
        imageUrl: '',
        shopName: 'テスト店',
        shopCode: 'mystore',
      );
      final m = roomImportEvaluateApiCandidateMatch(
        item: item,
        roomShopCode: 'mystore',
        roomUrlProductCode: 'product-slug',
        roomPrice: 1980,
      );
      expect(m.shopMatched, isTrue);
      expect(m.priceMatched, isTrue);
      expect(m.urlSlugMatched, isFalse);
      expect(m.matched, isFalse);
      expect(m.reason, 'priceMatchedButUrlMismatch');
    });

    test('shop mismatch rejects candidate', () {
      const item = RakutenSearchItem(
        productId: 'other:1',
        itemName: '他店商品',
        itemPrice: 1980,
        itemUrl: 'https://item.rakuten.co.jp/otherstore/product-slug/',
        affiliateUrl: '',
        imageUrl: '',
        shopName: '他店',
        shopCode: 'otherstore',
      );
      final m = roomImportEvaluateApiCandidateMatch(
        item: item,
        roomShopCode: 'mystore',
        roomUrlProductCode: 'product-slug',
        roomPrice: 1980,
      );
      expect(m.shopMatched, isFalse);
      expect(m.matched, isFalse);
      expect(m.reason, 'shopMismatch');
    });
  });
}
