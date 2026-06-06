import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/room_rakuten_url_normalize.dart';

void main() {
  group('RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl', () {
    test('通常 item.rakuten URL を正規化する', () {
      const url = 'https://item.rakuten.co.jp/soukaidrink/4901085161999?scid=x';
      final norm = RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl(url);
      expect(norm, 'https://item.rakuten.co.jp/soukaidrink/4901085161999/');
    });

    test('スラッグ URL を正規化する', () {
      const url = 'https://item.rakuten.co.jp/oiwaizen/sanrio-001-s';
      final norm = RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl(url);
      expect(norm, 'https://item.rakuten.co.jp/oiwaizen/sanrio-001-s/');
    });

    test('affiliateUrl の pc= から item URL を復元する', () {
      const itemUrl =
          'https://item.rakuten.co.jp/soukaidrink/4901085161999/?scid=share';
      final affiliate =
          'https://hb.afl.rakuten.co.jp/hgc/test/?pc=${Uri.encodeComponent(itemUrl)}&link_type=pcpath';
      final norm = RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl(
        affiliate,
      );
      expect(norm, 'https://item.rakuten.co.jp/soukaidrink/4901085161999/');
    });
  });

  group('RoomRakutenUrlNormalize.decodeAffiliatePcTargetUrl', () {
    test('affiliate 以外は null', () {
      expect(
        RoomRakutenUrlNormalize.decodeAffiliatePcTargetUrl(
          'https://item.rakuten.co.jp/a/b/',
        ),
        isNull,
      );
    });
  });
}
