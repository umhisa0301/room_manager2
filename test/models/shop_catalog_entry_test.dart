import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/shop_catalog_config.dart';
import 'package:room_manager2/models/shop_catalog_entry.dart';

ShopCatalogEntry _entry({
  String shopCode = 'girl-k',
  ShopCatalogSourceTrust sourceTrust = ShopCatalogSourceTrust.high,
  DateTime? lastValidatedAt,
  List<String>? aliases,
}) {
  final now = lastValidatedAt ?? DateTime(2026, 5, 31, 12);
  return ShopCatalogEntry(
    shopCode: shopCode,
    shopName: 'テストショップ',
    shopUrl: 'https://www.rakuten.co.jp/girl-k/',
    representativeImageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/girl-k/cabinet/a.jpg',
    primaryGenreId: '100',
    primaryGenreName: 'ジャンル',
    genreIds: const ['100'],
    genreNames: const ['ジャンル'],
    itemCountInCatalog: 3,
    safeItemCount: 3,
    itemsWithImage: 3,
    itemsWithPrice: 3,
    averageReviewAverage: 4.2,
    maxReviewCount: 12,
    averagePrice: 1500,
    minPrice: 500,
    maxPrice: 3000,
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
    aliases: aliases ?? ['girl-k'],
    sampleProductIds: const ['girl-k:item1'],
  );
}

void main() {
  group('ShopCatalogEntry', () {
    test('JSON 往復できる', () {
      final original = _entry();
      final restored = ShopCatalogEntry.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.shopCode, original.shopCode);
      expect(restored.source, ShopCatalogSource.search);
      expect(restored.sourceTrust, ShopCatalogSourceTrust.high);
    });

    test('aliases を保持する', () {
      final original = _entry(
        aliases: ['girl-k', 'https://www.rakuten.co.jp/girl-k/'],
      );
      final restored = ShopCatalogEntry.fromJson(original.toJson());
      expect(restored!.aliases, contains('girl-k'));
      expect(restored.aliases, contains('https://www.rakuten.co.jp/girl-k/'));
    });

    test('stale 判定用フィールドを保持する', () {
      final validated = DateTime(2026, 5, 29, 8);
      final original = _entry(
        lastValidatedAt: validated,
        aliases: ['girl-k'],
      );
      final restored = ShopCatalogEntry.fromJson(original.toJson());
      expect(restored!.lastValidatedAt, validated);
      expect(restored.cacheTtlSeconds, ShopCatalogConfig.defaultShopCatalogTtlSeconds);
    });

    test('savedStatus を持たない JSON は拒否する', () {
      final json = _entry().toJson();
      json['savedStatus'] = 'saved';
      expect(ShopCatalogEntry.fromJson(json), isNull);
    });

    test('savedAt を持たないこと（モデルにフィールドなし）', () {
      final entry = _entry();
      expect(entry.toJson().containsKey('savedAt'), isFalse);
      expect(entry.toJson().containsKey('savedStatus'), isFalse);
    });
  });
}
