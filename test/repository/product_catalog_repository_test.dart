import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogProduct _product({
  required String canonicalId,
  String itemName = '商品',
  int itemPrice = 1000,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? lastValidatedAt,
  DateTime? lastAccessedAt,
  List<String>? aliases,
}) {
  final now = lastValidatedAt ?? DateTime(2026, 5, 31, 12);
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/$canonicalId/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/$canonicalId/',
    itemName: itemName,
    itemPrice: itemPrice,
    imageUrl: 'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopCode: 'shop',
    shopName: 'ショップ',
    shopUrl: '',
    genreId: '1',
    genreName: 'ジャンル',
    reviewAverage: 4.0,
    reviewCount: 5,
    affiliateUrl: '',
    itemCaption: '',
    source: CatalogProductSource.search,
    sourceTrust: sourceTrust,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: lastAccessedAt ?? now,
    qualityStatus: const CatalogProductQualityStatus(
      hasImage: true,
      hasPrice: true,
      hasValidUrl: true,
      safe: true,
    ),
    aliases: aliases ?? [canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

void main() {
  group('ProductCatalogRepository', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('upsert して canonicalId で取得できる', () async {
      final product = _product(canonicalId: 'shop:1');
      await repo.upsert(product);
      final loaded = repo.getByCanonicalId('shop:1');
      expect(loaded, isNotNull);
      expect(loaded!.itemName, '商品');
    });

    test('alias で検索できる', () async {
      final product = _product(
        canonicalId: 'shop:2',
        aliases: ['shop:2', 'https://item.rakuten.co.jp/shop/2/'],
      );
      await repo.upsert(product);
      final loaded = repo.findByAlias('https://item.rakuten.co.jp/shop/2/');
      expect(loaded?.canonicalId, 'shop:2');
    });

    test('high trust が low trust を上書きできる', () async {
      await repo.upsert(
        _product(
          canonicalId: 'shop:3',
          itemName: '古い',
          sourceTrust: CatalogProductSourceTrust.low,
        ),
      );
      await repo.upsert(
        _product(
          canonicalId: 'shop:3',
          itemName: '新しい',
          sourceTrust: CatalogProductSourceTrust.high,
        ),
      );
      expect(repo.getByCanonicalId('shop:3')!.itemName, '新しい');
    });

    test('low trust は high trust の重要フィールドを上書きしない', () async {
      await repo.upsert(
        _product(
          canonicalId: 'shop:4',
          itemName: '高信頼',
          itemPrice: 5000,
          sourceTrust: CatalogProductSourceTrust.high,
        ),
      );
      await repo.upsert(
        _product(
          canonicalId: 'shop:4',
          itemName: '低信頼',
          itemPrice: 100,
          sourceTrust: CatalogProductSourceTrust.low,
        ),
      );
      final loaded = repo.getByCanonicalId('shop:4');
      expect(loaded!.itemName, '高信頼');
      expect(loaded.itemPrice, 5000);
    });

    test('最大件数を超えたら古いものが削除される', () async {
      final base = DateTime(2026, 5, 31, 12);
      for (var i = 0; i < ProductCatalogConfig.maxCatalogProducts + 5; i++) {
        await repo.upsert(
          _product(
            canonicalId: 'shop:$i',
            lastAccessedAt: base.add(Duration(minutes: i)),
            lastValidatedAt: base.add(Duration(minutes: i)),
          ),
        );
      }
      expect(repo.count(), ProductCatalogConfig.maxCatalogProducts);
      expect(repo.getByCanonicalId('shop:0'), isNull);
      expect(repo.getByCanonicalId('shop:4'), isNull);
      expect(repo.getByCanonicalId('shop:804'), isNotNull);
    });

    test('stale 判定ができる', () {
      final fresh = _product(
        canonicalId: 'shop:5',
        lastValidatedAt: DateTime(2026, 5, 31, 12),
      );
      final stale = _product(
        canonicalId: 'shop:6',
        lastValidatedAt: DateTime(2026, 5, 29, 12),
      );
      expect(
        repo.isStale(fresh, now: DateTime(2026, 5, 31, 13)),
        isFalse,
      );
      expect(
        repo.isStale(stale, now: DateTime(2026, 5, 31, 13)),
        isTrue,
      );
    });

    test('clear で空になる', () async {
      await repo.upsert(_product(canonicalId: 'shop:7'));
      await repo.clear();
      expect(repo.count(), 0);
    });
  });
}
