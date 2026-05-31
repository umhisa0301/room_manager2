import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/utils/catalog_product_quality.dart';

CatalogProduct _product({
  String itemName = '木のおもちゃ',
  int itemPrice = 1980,
  String itemUrl = 'https://item.rakuten.co.jp/shop/item/',
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
}) {
  final now = DateTime(2026, 5, 31);
  return CatalogProduct(
    canonicalId: 'shop:item',
    productId: 'shop:item',
    itemCode: 'shop:item',
    itemUrl: itemUrl,
    normalizedItemUrl: itemUrl,
    itemName: itemName,
    itemPrice: itemPrice,
    imageUrl: imageUrl,
    shopCode: 'shop',
    shopName: 'テストショップ',
    shopUrl: '',
    genreId: '1',
    genreName: 'おもちゃ',
    reviewAverage: 4.0,
    reviewCount: 10,
    affiliateUrl: '',
    itemCaption: '',
    source: CatalogProductSource.search,
    sourceTrust: CatalogProductSourceTrust.high,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    qualityStatus: const CatalogProductQualityStatus(
      hasImage: false,
      hasPrice: false,
      hasValidUrl: false,
      safe: true,
    ),
    aliases: const ['shop:item'],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

void main() {
  group('CatalogProductQuality', () {
    test('正常商品の qualityStatus が生成できる', () {
      final status = CatalogProductQuality.evaluate(_product());
      expect(status.hasImage, isTrue);
      expect(status.hasPrice, isTrue);
      expect(status.hasValidUrl, isTrue);
      expect(status.safe, isTrue);
      expect(status.blockedReason, isEmpty);
    });

    test('無効 URL を判定できる', () {
      final status = CatalogProductQuality.evaluate(_product(itemUrl: ''));
      expect(status.hasValidUrl, isFalse);
    });

    test('画像なしを判定できる', () {
      final status = CatalogProductQuality.evaluate(_product(imageUrl: ''));
      expect(status.hasImage, isFalse);
    });

    test('価格なしを判定できる', () {
      final status = CatalogProductQuality.evaluate(_product(itemPrice: 0));
      expect(status.hasPrice, isFalse);
    });

    test('安全 NG を判定できる', () {
      final status = CatalogProductQuality.evaluate(
        _product(itemName: '大人のおもちゃ 初心者向け'),
      );
      expect(status.safe, isFalse);
      expect(status.blockedReason, isNotEmpty);
    });
  });
}
