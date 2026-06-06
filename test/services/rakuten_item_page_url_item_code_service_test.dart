import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/services/rakuten_item_page_url_item_code_service.dart';

void main() {
  group('RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl', () {
    test('通常URL・クエリ付きで itemCode を抽出する', () {
      const url =
          'https://item.rakuten.co.jp/soukaidrink/4901085161999/?scid=wi_ich_ichibaapp_weburl_share';
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        url,
      );
      expect(r, isA<RakutenItemPageUrlParseSuccess>());
      final s = r as RakutenItemPageUrlParseSuccess;
      expect(s.shopCode, 'soukaidrink');
      expect(s.itemId, '4901085161999');
      expect(s.itemCode, 'soukaidrink:4901085161999');
    });

    test('末尾スラッシュなしでも itemCode を抽出する', () {
      const url = 'https://item.rakuten.co.jp/soukaidrink/4901085161999';
      final s = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
            url,
          )
          as RakutenItemPageUrlParseSuccess;
      expect(s.itemCode, 'soukaidrink:4901085161999');
      expect(s.isApiStyleItemCode, isTrue);
    });

    test('スラッグ URL でも shopCode と itemCode を抽出する', () {
      const url = 'https://item.rakuten.co.jp/oiwaizen/sanrio-001-s/';
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        url,
      );
      expect(r, isA<RakutenItemPageUrlParseSuccess>());
      final s = r as RakutenItemPageUrlParseSuccess;
      expect(s.shopCode, 'oiwaizen');
      expect(s.itemId, 'sanrio-001-s');
      expect(s.itemCode, 'oiwaizen:sanrio-001-s');
      expect(s.isApiStyleItemCode, isFalse);
    });

    test('affiliateUrl から itemCode を抽出する', () {
      const itemUrl =
          'https://item.rakuten.co.jp/soukaidrink/4901085161999/?scid=share';
      final affiliate =
          'https://hb.afl.rakuten.co.jp/hgc/test/?pc=${Uri.encodeComponent(itemUrl)}&link_type=pcpath';
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        affiliate,
      );
      expect(r, isA<RakutenItemPageUrlParseSuccess>());
      final s = r as RakutenItemPageUrlParseSuccess;
      expect(s.itemCode, 'soukaidrink:4901085161999');
      expect(s.isApiStyleItemCode, isTrue);
    });

    test('楽天BOOKS URL は対象外 URL として扱う', () {
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        'https://books.rakuten.co.jp/rb/1234567890/',
      );
      expect(r, isA<RakutenItemPageUrlParseFailure>());
      final f = r as RakutenItemPageUrlParseFailure;
      expect(f.isUnsupportedUrlType, isTrue);
      expect(
        f.userMessage,
        RakutenItemPageUrlItemCodeService.messageUnsupportedRakutenServiceUrl,
      );
    });

    test('楽天ファッション URL は対象外 URL として扱う', () {
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        'https://brandavenue.rakuten.co.jp/item/foo/',
      );
      expect(r, isA<RakutenItemPageUrlParseFailure>());
      expect((r as RakutenItemPageUrlParseFailure).isUnsupportedUrlType, isTrue);
    });

    test('検索結果ホストは非商品ページエラーになる', () {
      const url = 'https://search.rakuten.co.jp/search/mall?keyword=test';
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        url,
      );
      expect(r, isA<RakutenItemPageUrlParseFailure>());
      final f = r as RakutenItemPageUrlParseFailure;
      expect(
        f.userMessage,
        RakutenItemPageUrlItemCodeService.messageNonProductPagesNotSupported,
      );
    });

    test('楽天以外のURLは商品ページURLエラーになる', () {
      const url = 'https://example.com/item/foo/123';
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        url,
      );
      expect(r, isA<RakutenItemPageUrlParseFailure>());
      final f = r as RakutenItemPageUrlParseFailure;
      expect(
        f.userMessage,
        RakutenItemPageUrlItemCodeService.messageNeedIchibaProductPageUrl,
      );
    });

    test('item.rakuten で商品セグメントが不正なら確認できないエラー', () {
      const url = 'https://item.rakuten.co.jp/onlyshop/';
      final r = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
        url,
      );
      expect(r, isA<RakutenItemPageUrlParseFailure>());
      expect(
        (r as RakutenItemPageUrlParseFailure).userMessage,
        RakutenItemPageUrlItemCodeService.messageNonProductPagesNotSupported,
      );
    });
  });

  group('RakutenItemPageUrlItemCodeService.classifyAgainstManagedProducts', () {
    test('コレ済みがコレ候補より優先される', () {
      final items = [
        _product(
          'a:1',
          status: RakutenManagedProductStatus.done,
        ),
      ];
      final k = RakutenItemPageUrlItemCodeService.classifyAgainstManagedProducts(
        items: items,
        itemCode: 'a:1',
      );
      expect(k, RakutenUrlRegistryClassification.collectedDone);
    });

    test('コレ候補として分類される', () {
      final items = [
        _product(
          'b:2',
          status: RakutenManagedProductStatus.candidate,
        ),
      ];
      final k = RakutenItemPageUrlItemCodeService.classifyAgainstManagedProducts(
        items: items,
        itemCode: 'b:2',
      );
      expect(k, RakutenUrlRegistryClassification.candidate);
    });

    test('未登録', () {
      final k = RakutenItemPageUrlItemCodeService.classifyAgainstManagedProducts(
        items: const [],
        itemCode: 'c:3',
      );
      expect(k, RakutenUrlRegistryClassification.unregistered);
    });

    test('ROOM 取り込み slug productId と shopCode でコレ済み判定', () {
      final items = [
        RakutenManagedProduct.fromSearchItem(
          RakutenSearchItem(
            productId: 'sanrio-001-s',
            itemName: 'n',
            itemPrice: 100,
            itemUrl: 'https://item.rakuten.co.jp/oiwaizen/sanrio-001-s/',
            affiliateUrl: '',
            imageUrl: '',
            shopName: 's',
            shopCode: 'oiwaizen',
          ),
          status: RakutenManagedProductStatus.done,
          now: DateTime.parse('2024-01-01T12:00:00.000Z'),
        ),
      ];
      final k = RakutenItemPageUrlItemCodeService.classifyAgainstManagedProducts(
        items: items,
        itemCode: 'oiwaizen:sanrio-001-s',
      );
      expect(k, RakutenUrlRegistryClassification.collectedDone);
    });
  });
}

RakutenManagedProduct _product(
  String productId, {
  required RakutenManagedProductStatus status,
}) {
  final t = DateTime.parse('2024-01-01T12:00:00.000Z');
  return RakutenManagedProduct.fromSearchItem(
    RakutenSearchItem(
      productId: productId,
      itemName: 'n',
      itemPrice: 100,
      itemUrl: 'https://item.rakuten.co.jp/x/1/',
      affiliateUrl: '',
      imageUrl: '',
      shopName: 's',
      shopCode: 'x',
    ),
    status: status,
    now: t,
  );
}
