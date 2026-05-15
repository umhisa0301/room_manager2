import 'package:flutter_test/flutter_test.dart';

import 'package:room_manager2/utils/rakuten_ichiba_url_parse.dart';
import 'package:room_manager2/utils/room_rat_redirect_parse.dart';

void main() {
  test('tryParseRedirectUrl extracts composite itemCode and slug from event+dest', () {
    const redirect =
        'https://room.rakuten.co.jp/rat/relay/click.html?'
        'event=%7B%22shopurl%22%3A%22soukaidrink%22%2C%22itemid%22%3A%5B%22306273%2F10002596%22%5D%7D&'
        'dest=https%3A%2F%2Fhb.afl.rakuten.co.jp%2Fhgc%2F00000000%2Ftest%2F%3F'
        'pc=https%253A%252F%252Fitem.rakuten.co.jp%252Fsoukaidrink%252F4901085161999%252F';
    final a = RoomRatRedirectParse.tryParseRedirectUrl(
      redirect,
      roomPageUrl: 'https://room.rakuten.co.jp/u/123',
    );
    expect(a, isNotNull);
    expect(a!.apiCompositeItemCode, 'soukaidrink:10002596');
    expect(rakutenIchibaUrlLooksLikeApiItemCode(a.apiCompositeItemCode), isTrue);
    expect(a.urlProductCode, '4901085161999');
    expect(a.urlShopCode, 'soukaidrink');
    expect(a.roomProductSlug, '4901085161999');
    expect(a.apiItemCode, '10002596');
  });

  test('tryParseRedirectUrl supports rat-redirect host and drinkshop slug', () {
    const redirect =
        'https://room.rakuten.co.jp/rat-redirect?'
        'event=%7B%22shopurl%22%3A%22drinkshop%22%2C%22itemid%22%3A%5B%22213103%2F10531958%22%5D%2C%22igenre%22%3A%5B408254%5D%7D&'
        'dest=https%3A%2F%2Fhb.afl.rakuten.co.jp%2Fhgc%2Fx%2Fy%2F%3F'
        'pc=https%253A%252F%252Fitem.rakuten.co.jp%252Fdrinkshop%252F29022-2%252F';
    final a = RoomRatRedirectParse.tryParseRedirectUrl(
      redirect,
      roomPageUrl: 'https://room.rakuten.co.jp/u/1',
    );
    expect(a, isNotNull);
    expect(a!.urlShopCode, 'drinkshop');
    expect(a.urlProductCode, '29022-2');
    expect(a.apiItemCode, '10531958');
    expect(a.apiCompositeItemCode, 'drinkshop:10531958');
    expect(a.genreId, '408254');
    expect(a.rakutenItemUrl, contains('item.rakuten.co.jp/drinkshop/29022-2/'));
  });

  test('roomImportEnrichSlugShouldSkipDirectItemCode flags slug-like segments', () {
    expect(roomImportEnrichSlugShouldSkipDirectItemCode('29022-2'), isTrue);
    expect(roomImportEnrichSlugShouldSkipDirectItemCode('yakitai10'), isTrue);
    expect(roomImportEnrichSlugShouldSkipDirectItemCode('4901085161999'), isTrue);
    expect(roomImportEnrichSlugShouldSkipDirectItemCode('10002596'), isFalse);
    expect(roomImportEnrichSlugShouldSkipDirectItemCode('shop:123'), isFalse);
  });
}
