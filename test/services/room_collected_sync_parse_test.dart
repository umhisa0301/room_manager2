import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:room_manager2/services/rakuten_item_url_parser.dart';
import 'package:room_manager2/services/room_url_resolver.dart';

void main() {
  group('RakutenItemUrlParser', () {
    test('https の item.rakuten から shop / セグメント / 正規URL', () {
      const u =
          'https://item.rakuten.co.jp/soukaidrink/4901085161999/?scid=share';
      final r = RakutenItemUrlParser.tryParse(u)!;
      expect(r.shopCode, 'soukaidrink');
      expect(r.itemPathSegment, '4901085161999');
      expect(r.rakutenUrl, 'https://item.rakuten.co.jp/soukaidrink/4901085161999/');
      expect(r.compositeProductId, 'soukaidrink:4901085161999');
    });

    test('http でも抽出できる', () {
      final r = RakutenItemUrlParser.tryParse(
        'http://item.rakuten.co.jp/foo/999/',
      )!;
      expect(r.shopCode, 'foo');
      expect(r.itemPathSegment, '999');
    });

    test('HTML 内の複数リンクから数値ID付きを優先', () {
      const html =
          '<a href="https://item.rakuten.co.jp/a/slug">x</a>'
          '<a href="https://item.rakuten.co.jp/b/42">y</a>';
      final r = RakutenItemUrlParser.findFirstInText(html)!;
      expect(r.itemPathSegment, '42');
    });
  });

  group('RoomUrlResolver', () {
    test('ROOM HTML から楽天商品URLを取得できる', () async {
      final client = MockClient((request) async {
        expect(
          request.url.host.toLowerCase(),
          contains('room.rakuten'),
        );
        return http.Response.bytes(
          utf8.encode(
            '''
          <html>
          <meta property="og:title" content="TestTitle" />
          <a href="https://item.rakuten.co.jp/shopdemo/12345/">open</a>
          </html>
          ''',
          ),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final resolver = RoomUrlResolver(
        httpClient: client,
        timeout: const Duration(seconds: 5),
      );
      final out = await resolver.resolveRakutenItemUrlFromRoomPage(
        'https://room.rakuten.co.jp/user/1700373088237366',
      );
      expect(out, isA<RoomUrlResolveSuccess>());
      final s = out as RoomUrlResolveSuccess;
      expect(s.roomPageAffiliateUrl, isNull);
      expect(s.rakutenItem.shopCode, 'shopdemo');
      expect(s.rakutenItem.itemPathSegment, '12345');
      expect(s.roomPageTitle, 'TestTitle');
    });
  });
}
