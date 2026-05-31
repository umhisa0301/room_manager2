import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/shop_catalog_config.dart';
import 'package:room_manager2/models/shop_catalog_entry.dart';
import 'package:room_manager2/repository/shop_catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

ShopCatalogEntry _shop({
  required String shopCode,
  ShopCatalogSourceTrust sourceTrust = ShopCatalogSourceTrust.high,
  DateTime? lastAccessedAt,
  List<String>? aliases,
}) {
  final now = lastAccessedAt ?? DateTime(2026, 5, 31, 12);
  return ShopCatalogEntry(
    shopCode: shopCode,
    shopName: 'ショップ $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    representativeImageUrl: '',
    primaryGenreId: '1',
    primaryGenreName: 'ジャンル',
    genreIds: const ['1'],
    genreNames: const ['ジャンル'],
    itemCountInCatalog: 1,
    safeItemCount: 1,
    itemsWithImage: 1,
    itemsWithPrice: 1,
    averageReviewAverage: 4,
    maxReviewCount: 5,
    averagePrice: 1000,
    minPrice: 1000,
    maxPrice: 1000,
    source: ShopCatalogSource.search,
    sourceTrust: sourceTrust,
    lastFetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    cacheTtlSeconds: ShopCatalogConfig.defaultShopCatalogTtlSeconds,
    qualityStatus: const ShopCatalogQualityStatus(
      hasRepresentativeImage: true,
      hasShopUrl: true,
      hasPrimaryGenre: true,
      safe: true,
    ),
    aliases: aliases ?? [shopCode],
    sampleProductIds: const [],
  );
}

void main() {
  group('ShopCatalogRepository', () {
    late SharedPreferences prefs;
    late ShopCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ShopCatalogRepository(prefs);
      await repo.clear();
    });

    test('SHOP_CATALOG_ENABLED=false では no-op', () async {
      if (ShopCatalogConfig.kShopCatalogEnabled) return;

      await repo.upsert(_shop(shopCode: 'off-shop'));
      expect(repo.count(), 0);
      expect(repo.getByShopCode('off-shop'), isNull);
      expect(repo.getAll(), isEmpty);
      expect(repo.findByAlias('off-shop'), isNull);
    });

    test('SHOP_CATALOG_ENABLED=true では upsert / get', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;

      await repo.upsert(_shop(shopCode: 'on-shop'));
      expect(repo.count(), 1);
      expect(repo.getByShopCode('on-shop')?.shopName, 'ショップ on-shop');
    });

    test('alias で検索できる', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;

      await repo.upsert(
        _shop(
          shopCode: 'alias-shop',
          aliases: ['alias-shop', 'https://www.rakuten.co.jp/alias-shop/'],
        ),
      );
      expect(
        repo.findByAlias('https://www.rakuten.co.jp/alias-shop/')?.shopCode,
        'alias-shop',
      );
    });

    test('最大件数を超えたら古いものが削除される', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;

      final base = DateTime(2026, 5, 31, 12);
      for (var i = 0; i < ShopCatalogConfig.maxShopCatalogEntries + 5; i++) {
        await repo.upsert(
          _shop(
            shopCode: 'lru:$i',
            lastAccessedAt: base.add(Duration(minutes: i)),
          ),
        );
      }
      expect(repo.count(), ShopCatalogConfig.maxShopCatalogEntries);
      expect(repo.getByShopCode('lru:0'), isNull);
      expect(repo.getByShopCode('lru:304'), isNotNull);
    });

    test('clear で空になる', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;

      await repo.upsert(_shop(shopCode: 'clear-shop'));
      await repo.clear();
      expect(repo.count(), 0);
    });

    test('upsert は例外を外に投げない', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;

      await expectLater(repo.upsert(_shop(shopCode: 'safe-shop')), completes);
      expect(repo.getByShopCode('safe-shop'), isNotNull);
    });
  });
}
