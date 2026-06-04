import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/catalog_product_keys.dart';

void main() {
  group('CatalogProductKeys', () {
    test('productId / itemCode 優先で canonicalId が決まる', () {
      expect(
        CatalogProductKeys.resolveCanonicalId(productId: 'shop:123456'),
        'shop:123456',
      );
      expect(
        CatalogProductKeys.resolveCanonicalId(itemCode: 'shop:abc'),
        'shop:abc',
      );
    });

    test('productId が無い場合 normalizedItemUrl から synthetic key が作られる', () {
      final url = 'https://item.rakuten.co.jp/demo/999/';
      final canonical = CatalogProductKeys.resolveCanonicalId(itemUrl: url);
      expect(canonical, 'url:https://item.rakuten.co.jp/demo/999/');
    });

    test('canonicalId が決められない場合は null', () {
      expect(CatalogProductKeys.resolveCanonicalId(), isNull);
      expect(CatalogProductKeys.resolveCanonicalId(itemUrl: ''), isNull);
    });

    test('alias を生成できる', () {
      final aliases = CatalogProductKeys.buildAliases(
        canonicalId: 'shop:123',
        productId: 'shop:123',
        itemUrl: 'https://item.rakuten.co.jp/shop/123/',
        shopCode: 'shop',
        itemPathSegment: '123',
        roomPageUrl: 'https://room.rakuten.co.jp/shop/item/123?ref=1',
      );
      expect(aliases, contains('shop:123'));
      expect(aliases, contains('https://item.rakuten.co.jp/shop/123/'));
      expect(
        aliases,
        contains('https://room.rakuten.co.jp/shop/item/123'),
      );
    });

    test('itemUrl を正規化できる', () {
      expect(
        CatalogProductKeys.normalizeItemUrl(
          'https://item.rakuten.co.jp/shop/123?affid=1',
        ),
        'https://item.rakuten.co.jp/shop/123/',
      );
    });

    test('productId と URL パスが不一致のとき composite alias を付けない', () {
      final aliases = CatalogProductKeys.buildAliases(
        canonicalId: 'takeya-tea:10000383',
        productId: 'takeya-tea:10000383',
        itemUrl: 'https://item.rakuten.co.jp/takeya-tea/10000490/',
        shopCode: 'takeya-tea',
        itemPathSegment: '10000490',
      );
      expect(aliases, contains('takeya-tea:10000383'));
      expect(aliases, isNot(contains('takeya-tea:10000490')));
    });

    test('catalogProductsShareIdentity は別 productId・別 URL で false', () {
      expect(
        CatalogProductKeys.catalogProductsShareIdentity(
          existingCanonicalId: 'takeya-tea:10000490',
          existingProductId: 'takeya-tea:10000490',
          existingNormalizedItemUrl:
              'https://item.rakuten.co.jp/takeya-tea/10000490/',
          incomingCanonicalId: 'takeya-tea:10000383',
          incomingProductId: 'takeya-tea:10000383',
          incomingNormalizedItemUrl:
              'https://item.rakuten.co.jp/takeya-tea/10000383/',
        ),
        isFalse,
      );
    });

    test('catalogProductsShareIdentity は同一 URL で true', () {
      const url = 'https://item.rakuten.co.jp/takeya-tea/same/';
      expect(
        CatalogProductKeys.catalogProductsShareIdentity(
          existingCanonicalId: 'takeya-tea:a',
          existingProductId: 'takeya-tea:a',
          existingNormalizedItemUrl: url,
          incomingCanonicalId: 'takeya-tea:b',
          incomingProductId: 'takeya-tea:b',
          incomingNormalizedItemUrl: url,
        ),
        isTrue,
      );
    });
  });
}
