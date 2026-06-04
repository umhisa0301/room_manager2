import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/utils/catalog_product_keys.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
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

    test('別 canonicalId・別 URL は alias 誤マージせず2件保存される', () async {
      final existing = catalogProductFromSearchItem(
        RakutenSearchItem(
          productId: 'takeya-tea:10000490',
          itemName: '商品A',
          itemPrice: 1000,
          itemUrl: 'https://item.rakuten.co.jp/takeya-tea/10000490/',
          affiliateUrl: '',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/a.jpg',
          shopName: 'TAKEYA',
          shopCode: 'takeya-tea',
        ),
        source: CatalogProductSource.shopDiscovery,
        sourceTrust: CatalogProductSourceTrust.medium,
      );
      final incoming = catalogProductFromSearchItem(
        RakutenSearchItem(
          productId: 'takeya-tea:10000383',
          itemName: '商品B',
          itemPrice: 2000,
          itemUrl: 'https://item.rakuten.co.jp/takeya-tea/10000383/',
          affiliateUrl: '',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/b.jpg',
          shopName: 'TAKEYA',
          shopCode: 'takeya-tea',
        ),
        source: CatalogProductSource.shopDiscovery,
        sourceTrust: CatalogProductSourceTrust.medium,
      );
      await repo.upsert(existing);
      final result = await repo.upsertAll(
        [incoming],
        collectItemAuditResults: true,
      );
      expect(result.inserted, 1);
      expect(result.updatedByAlias, 0);
      expect(result.aliasConflictPrevented, 0);
      expect(repo.getByCanonicalId('takeya-tea:10000490'), isNotNull);
      expect(repo.getByCanonicalId('takeya-tea:10000383'), isNotNull);
      expect(repo.count(), 2);
    });

    test('レガシー誤 alias があっても別 productId は別商品として insert', () async {
      await repo.upsert(
        CatalogProduct(
          canonicalId: 'takeya-tea:10000490',
          productId: 'takeya-tea:10000490',
          itemCode: 'takeya-tea:10000490',
          itemUrl: 'https://item.rakuten.co.jp/takeya-tea/10000490/',
          normalizedItemUrl: 'https://item.rakuten.co.jp/takeya-tea/10000490/',
          itemName: 'A',
          itemPrice: 1000,
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/a.jpg',
          shopCode: 'takeya-tea',
          shopName: 'TAKEYA',
          shopUrl: '',
          genreId: '1',
          genreName: 'g',
          reviewAverage: 4,
          reviewCount: 1,
          affiliateUrl: '',
          itemCaption: '',
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
          fetchedAt: DateTime(2026, 6, 4),
          lastValidatedAt: DateTime(2026, 6, 4),
          lastAccessedAt: DateTime(2026, 6, 4),
          qualityStatus: const CatalogProductQualityStatus(
            hasImage: true,
            hasPrice: true,
            hasValidUrl: true,
            safe: true,
          ),
          aliases: ['takeya-tea:10000490', 'takeya-tea:10000383'],
          cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
        ),
      );
      final incoming = catalogProductFromSearchItem(
        RakutenSearchItem(
          productId: 'takeya-tea:10000383',
          itemName: 'B',
          itemPrice: 2000,
          itemUrl: 'https://item.rakuten.co.jp/takeya-tea/10000383/',
          affiliateUrl: '',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/b.jpg',
          shopName: 'TAKEYA',
          shopCode: 'takeya-tea',
        ),
      );
      final result = await repo.upsertAll([incoming]);
      expect(result.aliasConflictPrevented, 1);
      expect(result.inserted, 1);
      expect(repo.getByCanonicalId('takeya-tea:10000383'), isNotNull);
      expect(repo.count(), 2);
    });

    test('同一 affiliate URL・別 productId は urlMatch せず2件保存', () async {
      const aff =
          'https://hb.afl.rakuten.co.jp/hgc/g00rfqqh.362kta6e.g00rfqqh.362ku4a9/';
      await repo.upsert(
        CatalogProduct(
          canonicalId: 'takeya-tea:10000490',
          productId: 'takeya-tea:10000490',
          itemCode: 'takeya-tea:10000490',
          itemUrl: aff,
          normalizedItemUrl: aff,
          itemName: 'A',
          itemPrice: 1000,
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/a.jpg',
          shopCode: 'takeya-tea',
          shopName: 'TAKEYA',
          shopUrl: '',
          genreId: '1',
          genreName: 'g',
          reviewAverage: 4,
          reviewCount: 1,
          affiliateUrl: aff,
          itemCaption: '',
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
          fetchedAt: DateTime(2026, 6, 4),
          lastValidatedAt: DateTime(2026, 6, 4),
          lastAccessedAt: DateTime(2026, 6, 4),
          qualityStatus: const CatalogProductQualityStatus(
            hasImage: true,
            hasPrice: true,
            hasValidUrl: true,
            safe: true,
          ),
          aliases: ['takeya-tea:10000490', aff],
          cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
        ),
      );
      final incoming = CatalogProduct(
        canonicalId: 'takeya-tea:10000383',
        productId: 'takeya-tea:10000383',
        itemCode: 'takeya-tea:10000383',
        itemUrl: aff,
        normalizedItemUrl: aff,
        itemName: 'B',
        itemPrice: 2000,
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/b.jpg',
        shopCode: 'takeya-tea',
        shopName: 'TAKEYA',
        shopUrl: '',
        genreId: '1',
        genreName: 'g',
        reviewAverage: 4,
        reviewCount: 1,
        affiliateUrl: aff,
        itemCaption: '',
        source: CatalogProductSource.shopDiscovery,
        sourceTrust: CatalogProductSourceTrust.medium,
        fetchedAt: DateTime(2026, 6, 4),
        lastValidatedAt: DateTime(2026, 6, 4),
        lastAccessedAt: DateTime(2026, 6, 4),
        qualityStatus: const CatalogProductQualityStatus(
          hasImage: true,
          hasPrice: true,
          hasValidUrl: true,
          safe: true,
        ),
        aliases: ['takeya-tea:10000383', aff],
        cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
      );
      final result = await repo.upsertAll([incoming]);
      expect(result.inserted, 1);
      expect(result.updatedByAlias, 0);
      expect(result.aliasConflictPrevented, 1);
      expect(repo.count(), 2);
      expect(repo.getByCanonicalId('takeya-tea:10000490'), isNotNull);
      expect(repo.getByCanonicalId('takeya-tea:10000383'), isNotNull);
    });

    test('takeya-tea 2商品バッチで productCountForShop=2', () async {
      const aff =
          'https://hb.afl.rakuten.co.jp/hgc/g00rfqqh.362kta6e.g00rfqqh.362ku4a9/';
      final batch = [
        CatalogProduct(
          canonicalId: 'takeya-tea:10000490',
          productId: 'takeya-tea:10000490',
          itemCode: 'takeya-tea:10000490',
          itemUrl: aff,
          normalizedItemUrl: aff,
          itemName: 'A',
          itemPrice: 1000,
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/a.jpg',
          shopCode: 'takeya-tea',
          shopName: 'TAKEYA',
          shopUrl: '',
          genreId: '1',
          genreName: 'g',
          reviewAverage: 4,
          reviewCount: 1,
          affiliateUrl: aff,
          itemCaption: '',
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
          fetchedAt: DateTime(2026, 6, 4),
          lastValidatedAt: DateTime(2026, 6, 4),
          lastAccessedAt: DateTime(2026, 6, 4),
          qualityStatus: const CatalogProductQualityStatus(
            hasImage: true,
            hasPrice: true,
            hasValidUrl: true,
            safe: true,
          ),
          aliases: ['takeya-tea:10000490', aff],
          cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
        ),
        CatalogProduct(
          canonicalId: 'takeya-tea:10000383',
          productId: 'takeya-tea:10000383',
          itemCode: 'takeya-tea:10000383',
          itemUrl: aff,
          normalizedItemUrl: aff,
          itemName: 'B',
          itemPrice: 2000,
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/takeya-tea/cabinet/b.jpg',
          shopCode: 'takeya-tea',
          shopName: 'TAKEYA',
          shopUrl: '',
          genreId: '1',
          genreName: 'g',
          reviewAverage: 4,
          reviewCount: 1,
          affiliateUrl: aff,
          itemCaption: '',
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
          fetchedAt: DateTime(2026, 6, 4),
          lastValidatedAt: DateTime(2026, 6, 4),
          lastAccessedAt: DateTime(2026, 6, 4),
          qualityStatus: const CatalogProductQualityStatus(
            hasImage: true,
            hasPrice: true,
            hasValidUrl: true,
            safe: true,
          ),
          aliases: ['takeya-tea:10000383', aff],
          cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
        ),
      ];
      final result = await repo.upsertAll(
        batch,
        collectItemAuditResults: true,
      );
      expect(result.inserted, 2);
      expect(result.updatedByAlias, 0);
      expect(result.aliasConflictPrevented, 1);
      final forShop = repo
          .getAll()
          .where((p) => p.shopCode == 'takeya-tea')
          .length;
      expect(forShop, 2);
    });

    test('productId 欠落時は同一 item URL で alias merge される', () async {
      const url = 'https://item.rakuten.co.jp/shop/same-item/';
      final urlCanonical = CatalogProductKeys.resolveCanonicalId(itemUrl: url)!;
      await repo.upsert(
        CatalogProduct(
          canonicalId: urlCanonical,
          productId: '',
          itemCode: '',
          itemUrl: url,
          normalizedItemUrl: url,
          itemName: '既存',
          itemPrice: 1000,
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
          shopCode: 'shop',
          shopName: 'ショップ',
          shopUrl: '',
          genreId: '1',
          genreName: 'g',
          reviewAverage: 4,
          reviewCount: 1,
          affiliateUrl: '',
          itemCaption: '',
          source: CatalogProductSource.search,
          sourceTrust: CatalogProductSourceTrust.high,
          fetchedAt: DateTime(2026, 6, 4),
          lastValidatedAt: DateTime(2026, 6, 4),
          lastAccessedAt: DateTime(2026, 6, 4),
          qualityStatus: const CatalogProductQualityStatus(
            hasImage: true,
            hasPrice: true,
            hasValidUrl: true,
            safe: true,
          ),
          aliases: [urlCanonical, url],
          cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
        ),
      );
      final incoming = catalogProductFromSearchItem(
        RakutenSearchItem(
          productId: 'shop:bbb',
          itemName: '別ID同一URL',
          itemPrice: 1000,
          itemUrl: url,
          affiliateUrl: '',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
          shopName: 'ショップ',
          shopCode: 'shop',
        ),
      );
      final result = await repo.upsertAll([incoming]);
      expect(result.inserted, 0);
      expect(result.updatedByAlias, 1);
      expect(repo.getByCanonicalId('shop:bbb'), isNull);
      expect(repo.getByCanonicalId(urlCanonical), isNotNull);
    });

    test('バッチ upsert で別商品2件は inserted=2', () async {
      final items = [
        catalogProductFromSearchItem(
          RakutenSearchItem(
            productId: 'batch:1',
            itemName: '1',
            itemPrice: 100,
            itemUrl: 'https://item.rakuten.co.jp/batch/one/',
            affiliateUrl: '',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/batch/cabinet/a.jpg',
            shopName: 'B',
            shopCode: 'batch',
          ),
        ),
        catalogProductFromSearchItem(
          RakutenSearchItem(
            productId: 'batch:2',
            itemName: '2',
            itemPrice: 200,
            itemUrl: 'https://item.rakuten.co.jp/batch/two/',
            affiliateUrl: '',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/batch/cabinet/b.jpg',
            shopName: 'B',
            shopCode: 'batch',
          ),
        ),
      ];
      final result = await repo.upsertAll(items);
      expect(result.inserted, 2);
      expect(result.updatedByAlias, 0);
      expect(repo.count(), 2);
    });
  });
}
