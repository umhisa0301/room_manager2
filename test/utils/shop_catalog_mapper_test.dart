import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/shop_catalog_config.dart';
import 'package:room_manager2/models/shop_catalog_entry.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/repository/shop_catalog_repository.dart';
import 'package:room_manager2/utils/shop_catalog_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

ShopDiscoverySummary _summary({
  String shopKey = 'girl-k',
  String shopName = 'ガールケー公式ショップ',
  String shopUrl = 'https://www.rakuten.co.jp/girl-k/',
  int hitItemCount = 3,
  List<ShopRepresentativeItem>? representativeItems,
}) {
  return ShopDiscoverySummary(
    shopKey: shopKey,
    shopName: shopName,
    shopUrl: shopUrl,
    hitItemCount: hitItemCount,
    maxReviewCount: 25,
    avgReviewAverage: 4.2,
    discoveryScore: 120,
    representativeItems: representativeItems ??
        const [
          ShopRepresentativeItem(
            itemName: '商品A',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/girl-k/cabinet/a.jpg',
            itemUrl: 'girl-k:item-a',
          ),
        ],
  );
}

class _ThrowingShopCatalogRepository extends ShopCatalogRepository {
  _ThrowingShopCatalogRepository(super.prefs);

  @override
  Future<ShopCatalogUpsertBatchResult> upsertAll(
    Iterable<ShopCatalogEntry> incomingShops,
  ) async {
    throw StateError('upsert failed');
  }
}

void main() {
  group('shopCatalogEntryFromDiscoverySummary', () {
    test('ShopDiscoverySummary から ShopCatalogEntry に変換できる', () {
      final entry = shopCatalogEntryFromDiscoverySummary(_summary());
      expect(entry, isNotNull);
      expect(entry!.shopCode, 'girl-k');
      expect(entry.source, ShopCatalogSource.shopDiscovery);
      expect(entry.sourceTrust, ShopCatalogSourceTrust.medium);
    });

    test('shopCode 空は保存しない', () {
      final entry = shopCatalogEntryFromDiscoverySummary(
        _summary(shopKey: ''),
      );
      expect(entry, isNull);
    });

    test('shopName 不正は保存しない', () {
      final entry = shopCatalogEntryFromDiscoverySummary(
        _summary(shopName: 'girl-k'),
      );
      expect(entry, isNull);
    });

    test('safeItemCount=0 相当（hitItemCount=0）は保存しない', () {
      final entry = shopCatalogEntryFromDiscoverySummary(
        _summary(hitItemCount: 0),
      );
      expect(entry, isNull);
    });

    test('representativeImageUrl は安全画像のみ採用する', () {
      final entry = shopCatalogEntryFromDiscoverySummary(
        _summary(
          representativeItems: const [
            ShopRepresentativeItem(
              itemName: 'NG',
              imageUrl: 'https://example.com/avatar.png',
              itemUrl: 'item-ng',
            ),
            ShopRepresentativeItem(
              itemName: 'OK',
              imageUrl:
                  'https://thumbnail.image.rakuten.co.jp/@0_mall/girl-k/cabinet/b.jpg',
              itemUrl: 'item-ok',
            ),
          ],
        ),
      );
      expect(entry, isNotNull);
      expect(entry!.representativeImageUrl, contains('thumbnail.image.rakuten'));
    });
  });

  group('upsertShopCatalogFromDiscoverySummaries', () {
    late ShopCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = ShopCatalogRepository(prefs);
      await repo.clear();
    });

    test('SHOP_CATALOG_ENABLED=false では no-op', () async {
      if (ShopCatalogConfig.kShopCatalogEnabled) return;
      final summaries = [_summary()];
      final summary = await upsertShopCatalogFromDiscoverySummaries(
        repository: repo,
        summaries: summaries,
      );
      expect(summary.upserted, 0);
      expect(repo.count(), 0);
    });

    test('SHOP_CATALOG_ENABLED=true で upsertAll 相当が動く', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;
      final summaries = [_summary()];
      final summary = await upsertShopCatalogFromDiscoverySummaries(
        repository: repo,
        summaries: summaries,
      );
      expect(summary.upserted, 1);
      expect(repo.count(), 1);
    });

    test('upsert失敗でも例外を投げない（検索成功扱いを阻害しない）', () async {
      if (!ShopCatalogConfig.kShopCatalogEnabled) return;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final throwingRepo = _ThrowingShopCatalogRepository(prefs);
      await expectLater(
        upsertShopCatalogFromDiscoverySummaries(
          repository: throwingRepo,
          summaries: [_summary()],
        ),
        completes,
      );
    });

    test('入力 summaries の件数・順序を変えない', () async {
      final summaries = [
        _summary(shopKey: 'shop-a', shopName: 'Shop A'),
        _summary(shopKey: 'shop-b', shopName: 'Shop B'),
      ];
      final beforeKeys = summaries.map((e) => e.shopKey).toList(growable: false);
      await upsertShopCatalogFromDiscoverySummaries(
        repository: repo,
        summaries: summaries,
      );
      final afterKeys = summaries.map((e) => e.shopKey).toList(growable: false);
      expect(afterKeys, beforeKeys);
    });
  });
}
