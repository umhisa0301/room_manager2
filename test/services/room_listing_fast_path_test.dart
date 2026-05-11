import 'package:flutter_test/flutter_test.dart';

import 'package:room_manager2/services/room_url_resolver.dart';
import 'package:room_manager2/utils/room_rakuten_url_normalize.dart';

void main() {
  test('mergeListingFastPathHintsFromHtml picks item.rakuten near room post URL', () {
    const seg = 'demo-user';
    const postId = '17001234567890';
    final html = (StringBuffer()
          ..write('<html><body>')
          ..write('<a href="https://room.rakuten.co.jp/$seg/$postId">post</a>')
          ..write(
            '<script>var x="https://item.rakuten.co.jp/shop-abc/12345/";</script>',
          )
          ..write('</body></html>'))
        .toString();

    final sink = <String, RoomUrlResolveSuccess>{};
    RoomUrlResolver.mergeListingFastPathHintsFromHtml(html, seg, sink);
    final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
      'https://room.rakuten.co.jp/$seg/$postId',
    );
    expect(sink.containsKey(key), isTrue);
    final s = sink[key]!;
    expect(s.rakutenItem.shopCode, 'shop-abc');
    expect(s.rakutenItem.itemPathSegment, '12345');
  });

  test('mergeListingFastPathFromCollectsRow reads nested item URL', () {
    const seg = 'u1';
    final row = <String, dynamic>{
      'id': '17001234567890',
      'meta': <String, dynamic>{
        'link': 'https://item.rakuten.co.jp/xshop/999/',
      },
    };
    final sink = <String, RoomUrlResolveSuccess>{};
    RoomUrlResolver.mergeListingFastPathFromCollectsRow(row, seg, sink);
    final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
      'https://room.rakuten.co.jp/$seg/17001234567890',
    );
    expect(sink.containsKey(key), isTrue);
    expect(sink[key]!.rakutenItem.shopCode, 'xshop');
    expect(sink[key]!.rakutenItem.itemPathSegment, '999');
  });
}
