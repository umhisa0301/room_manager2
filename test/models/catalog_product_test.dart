import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';

CatalogProduct _product({
  String canonicalId = 'shop:123',
  String itemName = 'テスト商品',
  int itemPrice = 1000,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
}) {
  final now = DateTime(2026, 5, 31, 12);
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/shop/123/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/shop/123/',
    itemName: itemName,
    itemPrice: itemPrice,
    imageUrl: 'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopCode: 'shop',
    shopName: 'テストショップ',
    shopUrl: 'https://www.rakuten.co.jp/shop/',
    genreId: '100',
    genreName: 'ジャンル',
    reviewAverage: 4.5,
    reviewCount: 10,
    affiliateUrl: '',
    itemCaption: '',
    source: CatalogProductSource.search,
    sourceTrust: sourceTrust,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    qualityStatus: const CatalogProductQualityStatus(
      hasImage: true,
      hasPrice: true,
      hasValidUrl: true,
      safe: true,
    ),
    aliases: [canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

void main() {
  group('CatalogProduct', () {
    test('JSON 往復できる', () {
      final original = _product();
      final restored = CatalogProduct.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.canonicalId, original.canonicalId);
      expect(restored.itemName, original.itemName);
      expect(restored.source, CatalogProductSource.search);
      expect(restored.sourceTrust, CatalogProductSourceTrust.high);
    });

    test('high trust が low trust の重要フィールドを上書きできる', () {
      final existing = _product(
        itemName: '古い名前',
        itemPrice: 500,
        sourceTrust: CatalogProductSourceTrust.low,
      );
      final incoming = _product(
        itemName: '新しい名前',
        itemPrice: 2000,
        sourceTrust: CatalogProductSourceTrust.high,
      );
      final merged = existing.mergeFrom(incoming);
      expect(merged.itemName, '新しい名前');
      expect(merged.itemPrice, 2000);
      expect(merged.sourceTrust, CatalogProductSourceTrust.high);
    });

    test('low trust は high trust の重要フィールドを上書きしない', () {
      final existing = _product(
        itemName: '高信頼名',
        itemPrice: 5000,
        sourceTrust: CatalogProductSourceTrust.high,
      );
      final incoming = _product(
        itemName: '低信頼名',
        itemPrice: 100,
        sourceTrust: CatalogProductSourceTrust.low,
      );
      final merged = existing.mergeFrom(incoming);
      expect(merged.itemName, '高信頼名');
      expect(merged.itemPrice, 5000);
    });

    test('low trust でも空欄は補完できる', () {
      final existing = _product(
        itemName: '',
        itemPrice: 0,
        sourceTrust: CatalogProductSourceTrust.high,
      ).copyWith(shopName: '', genreName: '');
      final incoming = _product(
        itemName: '補完名',
        itemPrice: 1500,
        sourceTrust: CatalogProductSourceTrust.low,
      );
      final merged = existing.mergeFrom(incoming);
      expect(merged.itemName, '補完名');
      expect(merged.itemPrice, 1500);
    });
  });
}
