import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/utils/catalog_product_keys.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _searchItem({
  String productId = 'shop:item001',
  String itemName = '木のおもちゃ',
  int itemPrice = 1980,
  String itemUrl = 'https://item.rakuten.co.jp/shop/item001/',
}) {
  return RakutenSearchItem(
    productId: productId,
    itemName: itemName,
    itemPrice: itemPrice,
    itemUrl: itemUrl,
    affiliateUrl: '',
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopName: 'テストショップ',
    shopCode: 'shop',
    shopUrl: 'https://www.rakuten.co.jp/shop/',
    genreId: '100',
    genreName: 'おもちゃ',
  );
}

void main() {
  group('catalogProductFromSearchItem', () {
    test('RakutenSearchItem から CatalogProduct に変換できる', () {
      final product = catalogProductFromSearchItem(_searchItem());
      expect(product.canonicalId, 'shop:item001');
      expect(product.itemName, '木のおもちゃ');
      expect(product.itemPrice, 1980);
      expect(product.normalizedItemUrl, isNotEmpty);
    });

    test('source=search / sourceTrust=high になる', () {
      final product = catalogProductFromSearchItem(_searchItem());
      expect(product.source, CatalogProductSource.search);
      expect(product.sourceTrust, CatalogProductSourceTrust.high);
    });

    test('alias が生成される', () {
      final product = catalogProductFromSearchItem(_searchItem());
      expect(product.aliases, contains('shop:item001'));
      expect(
        product.aliases,
        contains(
          CatalogProductKeys.normalizeItemUrl(
            'https://item.rakuten.co.jp/shop/item001/',
          ),
        ),
      );
    });

    test('安全 NG は qualityStatus.safe=false になる', () {
      final product = catalogProductFromSearchItem(
        _searchItem(itemName: '大人のおもちゃ 初心者向け'),
      );
      expect(product.qualityStatus.safe, isFalse);
    });

    test('画像なし・価格なしは保存可能で qualityStatus に反映される', () {
      final product = catalogProductFromSearchItem(
        _searchItem(itemPrice: 0, itemName: '木のおもちゃ'),
      );
      expect(product.isSavable, isTrue);
      expect(product.qualityStatus.hasPrice, isFalse);
      expect(product.qualityStatus.safe, isTrue);
    });
  });

  group('upsertCatalogFromSearchItems', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('kProductCatalogEnabled=false のとき no-op', () async {
      if (ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromSearchItems(
        repo,
        [_searchItem()],
      );
      expect(summary, const ProductCatalogUpsertSummary.skipped());
      expect(repo.count(), 0);
    });

    test('安全 NG は upsert 対象から除外される', () async {
      final safe = catalogProductFromSearchItem(_searchItem());
      final unsafe = catalogProductFromSearchItem(
        _searchItem(itemName: '大人のおもちゃ 初心者向け'),
      );
      expect(unsafe.qualityStatus.safe, isFalse);
      final products = [safe, unsafe]
          .where((p) => p.isSavable && p.qualityStatus.safe)
          .toList();
      expect(products.length, 1);
      await repo.upsertAll(products);
      expect(repo.count(), 1);
      expect(repo.findByAlias('shop:item001')?.canonicalId, 'shop:item001');
    });

    test(
      'kProductCatalogEnabled=true のとき upsertAll が永続化する',
      () async {
        if (!ProductCatalogConfig.kProductCatalogEnabled) return;
        final summary = await upsertCatalogFromSearchItems(
          repo,
          [_searchItem()],
          catalogMode: 'productSearch',
        );
        expect(summary.upserted, greaterThan(0));
        expect(repo.count(), 1);
      },
    );

    test('変換商品を upsert すると alias で検索できる', () async {
      final product = catalogProductFromSearchItem(_searchItem());
      await repo.upsertAll([product]);
      final normUrl = CatalogProductKeys.normalizeItemUrl(
        'https://item.rakuten.co.jp/shop/item001/',
      );
      expect(repo.findByAlias(normUrl)?.canonicalId, 'shop:item001');
      expect(repo.findByAlias('shop:item001')?.canonicalId, 'shop:item001');
    });

    test('catalogUpsertModeLabelForSearchModeTag がモード別ラベルを返す', () {
      expect(catalogUpsertModeLabelForSearchModeTag('product'), 'productSearch');
      expect(catalogUpsertModeLabelForSearchModeTag('genre'), 'genreSearch');
      expect(
        catalogUpsertModeLabelForSearchModeTag('savedShop'),
        'savedShopSearch',
      );
    });
  });
}
