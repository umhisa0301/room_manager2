import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
import 'package:room_manager2/utils/room_catalog_enrichment.dart';
import 'package:room_manager2/utils/room_import_safe_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogProduct _catalog({
  required String canonicalId,
  int itemPrice = 1980,
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
  String shopName = 'テストショップ',
  String genreName = '水・ソフトドリンク',
  String genreId = '100227',
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? lastValidatedAt,
}) {
  final now = lastValidatedAt ?? DateTime.now();
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    itemName: '水筒',
    itemPrice: itemPrice,
    imageUrl: imageUrl,
    shopCode: 'shop',
    shopName: shopName,
    shopUrl: '',
    genreId: genreId,
    genreName: genreName,
    reviewAverage: 4.0,
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

RakutenManagedProduct _roomRow({
  String productId = 'shop:item001',
  int itemPrice = 0,
  String imageUrl = '',
  String shopName = '',
  String genreName = '',
  String genreId = '',
  String itemUrl = '',
}) {
  final t = DateTime(2026, 5, 31, 10);
  return RakutenManagedProduct(
    productId: productId,
    itemName: 'ROOMタイトル',
    itemPrice: itemPrice,
    itemUrl: itemUrl,
    imageUrl: imageUrl,
    shopName: shopName,
    shopCode: 'shop',
    shopUrl: '',
    genreId: genreId,
    genreName: genreName,
    status: RakutenManagedProductStatus.done,
    createdAt: t,
    updatedAt: t,
    addedAt: t,
    extractedUrl: '',
    extractionStatus: RakutenUrlExtractionStatus.notStarted,
    extractionErrorMessage: '',
    coredActivitySource: RakutenCoredActivitySource.roomImport,
  );
}

void main() {
  group('RoomCatalogEnrichment', () {
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = ProductCatalogRepository(
        await SharedPreferences.getInstance(),
      );
      await repo.clear();
    });

    test('productId 一致で照合できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsert(_catalog(canonicalId: 'shop:item001'));
      final hit = RoomCatalogEnrichment.lookupProduct(
        repository: repo,
        row: _roomRow(productId: 'shop:item001'),
      );
      expect(hit.matchKind, RoomCatalogMatchKind.productId);
      expect(hit.product?.canonicalId, 'shop:item001');
    });

    test('normalizedItemUrl 一致で照合できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      const url = 'https://item.rakuten.co.jp/shop/urlonly/';
      final cat = _catalog(canonicalId: 'url:$url');
      await repo.upsert(
        cat.copyWith(
          productId: '',
          itemCode: '',
          normalizedItemUrl: url,
          aliases: [url],
        ),
      );
      final hit = RoomCatalogEnrichment.lookupKeys(
        repository: repo,
        itemUrl: url,
      );
      expect(hit.matchKind, RoomCatalogMatchKind.normalizedUrl);
    });

    test('shopCode + itemPathSegment 一致で照合できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsert(_catalog(canonicalId: 'shop:item002'));
      final hit = RoomCatalogEnrichment.lookupKeys(
        repository: repo,
        shopCode: 'shop',
        itemPathSegment: 'item002',
      );
      expect(hit.matchKind, RoomCatalogMatchKind.shopItem);
    });

    test('商品名だけでは照合・補完しない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsert(
        _catalog(
          canonicalId: 'shop:other',
        ),
      );
      final hit = RoomCatalogEnrichment.lookupProduct(
        repository: repo,
        row: _roomRow(productId: 'shop:unknown'),
      );
      expect(hit.matched, isFalse);
    });

    test('stale な商品は補完に使わない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final stale = _catalog(
        canonicalId: 'shop:stale',
        lastValidatedAt: DateTime(2026, 5, 20, 12),
      );
      await repo.upsert(stale);
      final hit = RoomCatalogEnrichment.lookupProduct(
        repository: repo,
        row: _roomRow(productId: 'shop:stale'),
        now: DateTime(2026, 5, 31, 13),
      );
      expect(hit.matched, isFalse);
      expect(hit.skippedStale, isTrue);
    });

    test('sourceTrust=low は補完に使わない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsert(
        _catalog(
          canonicalId: 'shop:low',
          sourceTrust: CatalogProductSourceTrust.low,
        ),
      );
      final hit = RoomCatalogEnrichment.lookupProduct(
        repository: repo,
        row: _roomRow(productId: 'shop:low'),
      );
      expect(hit.matched, isFalse);
      expect(hit.skippedLowTrust, isTrue);
    });

    test('既存画像が安全ならカタログ画像で上書きしない', () {
      const safeImg =
          'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/safe.jpg';
      final patch = RoomCatalogEnrichment.buildImmediateImagePatch(
        row: _roomRow(
          imageUrl: safeImg,
        ),
        catalog: _catalog(canonicalId: 'shop:item001'),
      );
      expect(patch, isNull);
    });

    test('既存画像が疑わしくカタログ画像が安全なら補完できる', () {
      final patch = RoomCatalogEnrichment.buildImmediateImagePatch(
        row: _roomRow(imageUrl: 'https://room.rakuten.co.jp/noimage.gif'),
        catalog: _catalog(canonicalId: 'shop:item001'),
      );
      expect(patch, isNotNull);
      expect(patch!.imageUrl, contains('rakuten.co.jp'));
    });

    test('既存価格が0ならカタログ価格で補完できる', () {
      final patch = RoomCatalogEnrichment.buildMetadataEnrichmentPatch(
        row: _roomRow(itemPrice: 0),
        catalog: _catalog(canonicalId: 'shop:item001', itemPrice: 1980),
      );
      expect(patch?.itemPrice, 1980);
    });

    test('既存価格が有効なら上書きしない', () {
      final patch = RoomCatalogEnrichment.buildMetadataEnrichmentPatch(
        row: _roomRow(itemPrice: 2500),
        catalog: _catalog(canonicalId: 'shop:item001', itemPrice: 1980),
      );
      expect(
        RoomImportSafeMerge.mergePrice(
          field: 'price',
          existing: 2500,
          incoming: patch?.itemPrice ?? 0,
          log: false,
        ),
        2500,
      );
    });

    test('shopName / genreName が空なら補完できる', () {
      final patch = RoomCatalogEnrichment.buildMetadataEnrichmentPatch(
        row: _roomRow(shopName: '', genreName: ''),
        catalog: _catalog(canonicalId: 'shop:item001'),
      );
      expect(patch, isNotNull);
      expect(patch!.shopName, 'テストショップ');
      expect(patch.genreName, '水・ソフトドリンク');
    });

    test('upsert時に high が low で上書きされない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsert(
        _catalog(
          canonicalId: 'shop:trust',
          sourceTrust: CatalogProductSourceTrust.high,
          shopName: '検索ショップ',
        ),
      );
      final incoming = catalogProductFromManagedProduct(
        _roomRow(
          productId: 'shop:trust',
          shopName: 'ROOMショップ',
        ),
        source: CatalogProductSource.roomImport,
        sourceTrust: CatalogProductSourceTrust.low,
      );
      await repo.upsert(incoming);
      final stored = repo.getByCanonicalId('shop:trust');
      expect(stored?.shopName, '検索ショップ');
      expect(stored?.sourceTrust, CatalogProductSourceTrust.high);
    });

    test('repository が null でも upsert は skipped', () async {
      final summary = await upsertCatalogFromRoomManagedProducts(
        null,
        [_roomRow()],
      );
      expect(summary.attempted, 0);
    });
  });
}
