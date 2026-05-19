import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/utils/room_unconfirmed_display_copy.dart';

void main() {
  group('RoomUnconfirmedDisplayCopy', () {
    final t = DateTime.parse('2024-06-01T12:00:00.000Z');

    RakutenManagedProduct product({
      int itemPrice = 0,
      String itemName = 'テスト商品',
      String imageUrl = 'https://example.com/p.jpg',
      String itemUrl = 'https://item.rakuten.co.jp/shop/item',
      String shopCode = 'shop',
      String shopName = 'テストショップ',
    }) {
      return RakutenManagedProduct(
        productId: 'pid-1',
        itemName: itemName,
        itemPrice: itemPrice,
        itemUrl: itemUrl,
        imageUrl: imageUrl,
        shopName: shopName,
        shopCode: shopCode,
        shopUrl: '',
        genreId: '',
        genreName: '',
        status: RakutenManagedProductStatus.done,
        createdAt: t,
        updatedAt: t,
        addedAt: t,
        extractedUrl: '',
        extractionStatus: RakutenUrlExtractionStatus.notStarted,
        extractionErrorMessage: '',
        roomUrl: 'https://room.rakuten.co.jp/x',
        doneAt: t,
        coredActivitySource: RakutenCoredActivitySource.roomImport,
        importedAt: t,
      );
    }

    test('価格だけ未取得のとき強い未確認文言は出さない', () {
      final p = product(itemPrice: 0);
      expect(RoomUnconfirmedDisplayCopy.chipLabelFor(p), isNull);
      expect(
        RoomUnconfirmedDisplayCopy.priceSublineFor(p),
        '価格を確認できません',
      );
    });

    test('商品名も画像も無いときは売り切れ系を表示', () {
      final p = product(
        itemPrice: 0,
        itemName: '',
        imageUrl: '',
      );
      expect(
        RoomUnconfirmedDisplayCopy.chipLabelFor(p),
        '売り切れ・販売停止の可能性',
      );
    });
  });
}
