import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/room_collected_persist_kind.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/services/rakuten_item_url_parser.dart';
import 'package:room_manager2/utils/room_import_product_identity.dart';
import 'package:room_manager2/utils/room_rakuten_url_normalize.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RoomImportProductIdentity', () {
    test('slug と API itemCode が異なっても同一商品として判定できる', () {
      final existingKeys = RoomImportProductIdentity.keysForManagedProduct(
        RakutenManagedProduct.fromSearchItem(
          const RakutenSearchItem(
            productId: 'shopmarna:10006515',
            itemName: '保存済み商品',
            itemPrice: 3980,
            itemUrl: 'https://item.rakuten.co.jp/shopmarna/x110/',
            affiliateUrl: '',
            imageUrl: 'https://example.com/existing.jpg',
            shopName: 'Shop Marna',
            shopCode: 'shopmarna',
            shopUrl: 'https://www.rakuten.co.jp/shopmarna/',
            genreId: '100',
            genreName: 'キッチン',
          ),
          status: RakutenManagedProductStatus.done,
        ),
      );

      final parsed = RakutenItemUrlParser.tryParse(
        'https://item.rakuten.co.jp/shopmarna/x110/',
      )!;
      final incomingKeys = RoomImportProductIdentity.keysForIncomingImport(
        parsedItem: parsed,
        normalizedRoomUrlKey:
            'https://room.rakuten.co.jp/mix?itemcode=shopmarna%3A10006515',
        roomPageUrl:
            'https://room.rakuten.co.jp/mix?itemcode=shopmarna%3A10006515',
        roomApiCompositeItemCode: 'shopmarna:10006515',
        roomProductSlug: 'x110',
      );

      final hit = RoomImportProductIdentity.intersectMatch(
        incomingKeys: incomingKeys,
        existingKeys: existingKeys,
        incomingShop: 'shopmarna',
        existingShop: 'shopmarna',
      );

      expect(hit, isNotNull);
      expect(hit!.matchType, isNotEmpty);
    });

    test('別ショップの slug 一致だけではマッチしない', () {
      final existingKeys = RoomImportProductIdentity.keysForManagedProduct(
        RakutenManagedProduct.fromSearchItem(
          const RakutenSearchItem(
            productId: 'shop-a:10001',
            itemName: 'A',
            itemPrice: 1000,
            itemUrl: 'https://item.rakuten.co.jp/shop-a/shared-slug/',
            affiliateUrl: '',
            imageUrl: '',
            shopName: 'A',
            shopCode: 'shop-a',
            shopUrl: '',
            genreId: '',
            genreName: '',
          ),
          status: RakutenManagedProductStatus.done,
        ),
      );

      final parsed = RakutenItemUrlParser.tryParse(
        'https://item.rakuten.co.jp/shop-b/shared-slug/',
      )!;
      final incomingKeys = RoomImportProductIdentity.keysForIncomingImport(
        parsedItem: parsed,
        normalizedRoomUrlKey: 'https://room.rakuten.co.jp/mix?itemcode=shop-b%3A20002',
        roomPageUrl: 'https://room.rakuten.co.jp/mix?itemcode=shop-b%3A20002',
        roomApiCompositeItemCode: 'shop-b:20002',
        roomProductSlug: 'shared-slug',
      );

      expect(
        RoomImportProductIdentity.intersectMatch(
          incomingKeys: incomingKeys,
          existingKeys: existingKeys,
          incomingShop: 'shop-b',
          existingShop: 'shop-a',
        ),
        isNull,
      );
    });
  });

  group('ROOM import upsert', () {
    late RakutenManagedProductRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = RakutenManagedProductRepository(prefs);
    });

    RakutenManagedProduct _collectedFromRecommend({
      required String productId,
      required String itemUrl,
      required String title,
      required int price,
      required String imageUrl,
    }) {
      return RakutenManagedProduct.fromSearchItem(
        RakutenSearchItem(
          productId: productId,
          itemName: title,
          itemPrice: price,
          itemUrl: itemUrl,
          affiliateUrl: '',
          imageUrl: imageUrl,
          shopName: 'Shop Marna',
          shopCode: 'shopmarna',
          shopUrl: 'https://www.rakuten.co.jp/shopmarna/',
          genreId: '100',
          genreName: 'キッチン',
        ),
        status: RakutenManagedProductStatus.done,
      );
    }

    RakutenItemUrlParseResult _parsedSlugUrl() {
      return RakutenItemUrlParser.tryParse(
        'https://item.rakuten.co.jp/shopmarna/x110/',
      )!;
    }

    String normalizedRoomKey(String roomPageUrl) {
      return RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomPageUrl);
    }

    test('おすすめコレ登録済み商品を ROOM 取り込みしても新規追加されず更新される', () async {
      final collected = _collectedFromRecommend(
        productId: 'shopmarna:10006515',
        itemUrl: 'https://item.rakuten.co.jp/shopmarna/x110/',
        title: '既存タイトル',
        price: 3980,
        imageUrl: 'https://example.com/existing.jpg',
      );
      await repository.saveAllForTest([collected]);

      const roomPageUrl =
          'https://room.rakuten.co.jp/mix?itemcode=shopmarna%3A10006515';
      final roomKey = normalizedRoomKey(roomPageUrl);
      final parsed = _parsedSlugUrl();
      final match = RakutenManagedProductRepository.findRoomImportExistingRowMatch(
        list: repository.loadAll(),
        roomPageUrl: roomPageUrl,
        normalizedRoomUrlKey: roomKey,
        parsedItem: parsed,
        roomApiCompositeItemCode: 'shopmarna:10006515',
        roomProductSlug: 'x110',
      );
      expect(match, isNotNull);
      expect(match!.row.productId, 'shopmarna:10006515');

      final outcome = await repository.persistRoomCollectedFromRoomPage(
        roomUrlStoredCanonical: roomKey,
        normalizedRoomUrlKey: roomKey,
        parsedItem: parsed,
        roomPageTitle: 'ROOMタイトル',
        roomApiCompositeItemCodeHint: 'shopmarna:10006515',
        roomProductSlugHint: 'x110',
        roomImportAddRoomUrlToExistingNoApi: true,
      );

      expect(outcome.kind, RoomCollectedPersistKind.updatedRoomUrlOnly);
      final rows = repository.loadAll();
      expect(rows.length, 1);
      expect(rows.single.productId, 'shopmarna:10006515');
      expect(rows.single.isRoomSynced, isTrue);
      expect(rows.single.roomUrl, roomKey);
      expect(rows.single.status, RakutenManagedProductStatus.done);
    });

    test('既存のタイトル・価格・画像は空値や ROOM 側の劣化情報で上書きされない', () async {
      final collected = _collectedFromRecommend(
        productId: 'shopmarna:10006515',
        itemUrl: 'https://item.rakuten.co.jp/shopmarna/x110/',
        title: '既存タイトル',
        price: 3980,
        imageUrl: 'https://example.com/existing.jpg',
      );
      await repository.saveAllForTest([collected]);

      const roomPageUrl =
          'https://room.rakuten.co.jp/mix?itemcode=shopmarna%3A10006515';
      final roomKey = normalizedRoomKey(roomPageUrl);
      final parsed = _parsedSlugUrl();
      final outcome = await repository.persistRoomCollectedFromRoomPage(
        roomUrlStoredCanonical: roomKey,
        normalizedRoomUrlKey: roomKey,
        parsedItem: parsed,
        roomPageTitle: '',
        roomPageImageUrl: '',
        roomApiCompositeItemCodeHint: 'shopmarna:10006515',
        roomProductSlugHint: 'x110',
        listingHintPriceYen: 0,
        roomImportAddRoomUrlToExistingNoApi: true,
      );

      expect(outcome.kind, RoomCollectedPersistKind.updatedRoomUrlOnly);
      final row = repository.loadAll().single;
      expect(row.itemName, '既存タイトル');
      expect(row.itemPrice, 3980);
      expect(row.imageUrl, 'https://example.com/existing.jpg');
    });

    test('本当に新規の ROOM 商品だけ新規追加される', () async {
      final collected = _collectedFromRecommend(
        productId: 'shopmarna:10006515',
        itemUrl: 'https://item.rakuten.co.jp/shopmarna/x110/',
        title: '既存タイトル',
        price: 3980,
        imageUrl: 'https://example.com/existing.jpg',
      );
      await repository.saveAllForTest([collected]);

      const roomPageUrl =
          'https://room.rakuten.co.jp/mix?itemcode=other-shop%3A99999';
      final roomKey = normalizedRoomKey(roomPageUrl);
      final parsed = RakutenItemUrlParser.tryParse(
        'https://item.rakuten.co.jp/other-shop/new-item/',
      )!;
      final outcome = await repository.persistRoomCollectedFromRoomPage(
        roomUrlStoredCanonical: roomKey,
        normalizedRoomUrlKey: roomKey,
        parsedItem: parsed,
        roomPageTitle: '新規ROOM商品',
        roomApiCompositeItemCodeHint: 'other-shop:99999',
        roomProductSlugHint: 'new-item',
      );

      expect(outcome.kind, RoomCollectedPersistKind.insertedNewCollected);
      final rows = repository.loadAll();
      expect(rows.length, 2);
      expect(rows.any((e) => e.productId == 'shopmarna:10006515'), isTrue);
      expect(rows.any((e) => e.roomUrl == roomKey), isTrue);
    });

    test('同一 ROOM 商品の取り込みを複数回実行しても件数が増えない', () async {
      final collected = _collectedFromRecommend(
        productId: 'shopmarna:10006515',
        itemUrl: 'https://item.rakuten.co.jp/shopmarna/x110/',
        title: '既存タイトル',
        price: 3980,
        imageUrl: 'https://example.com/existing.jpg',
      );
      await repository.saveAllForTest([collected]);

      const roomPageUrl =
          'https://room.rakuten.co.jp/mix?itemcode=shopmarna%3A10006515';
      final roomKey = normalizedRoomKey(roomPageUrl);
      final parsed = _parsedSlugUrl();

      for (var i = 0; i < 3; i++) {
        final outcome = await repository.persistRoomCollectedFromRoomPage(
          roomUrlStoredCanonical: roomKey,
          normalizedRoomUrlKey: roomKey,
          parsedItem: parsed,
          roomPageTitle: 'ROOMタイトル',
          roomApiCompositeItemCodeHint: 'shopmarna:10006515',
          roomProductSlugHint: 'x110',
          roomImportAddRoomUrlToExistingNoApi: true,
        );
        expect(
          outcome.kind,
          anyOf(
            RoomCollectedPersistKind.updatedRoomUrlOnly,
            RoomCollectedPersistKind.roomPageAlreadySynced,
          ),
        );
      }

      expect(repository.loadAll().length, 1);
    });
  });
}

extension _TestManagedRepo on RakutenManagedProductRepository {
  Future<void> saveAllForTest(List<RakutenManagedProduct> rows) async {
    for (final row in rows) {
      await registerCandidateFromSearchItem(
        RakutenSearchItem(
          productId: row.productId,
          itemName: row.itemName,
          itemPrice: row.itemPrice,
          itemUrl: row.itemUrl,
          affiliateUrl: row.affiliateUrl ?? '',
          imageUrl: row.imageUrl,
          shopName: row.shopName,
          shopCode: row.shopCode,
          shopUrl: row.shopUrl,
          genreId: row.genreId,
          genreName: row.genreName,
        ),
      );
    }
    for (final row in rows) {
      if (row.status == RakutenManagedProductStatus.done) {
        await updateManagedProduct(row.productId, (e) => e.copyWith(
              status: RakutenManagedProductStatus.done,
              doneAt: row.doneAt ?? DateTime.now(),
              itemName: row.itemName,
              itemPrice: row.itemPrice,
              imageUrl: row.imageUrl,
            ));
      }
    }
  }
}
