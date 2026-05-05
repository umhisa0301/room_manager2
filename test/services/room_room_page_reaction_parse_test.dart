import 'package:flutter_test/flutter_test.dart';

import 'package:room_manager2/services/room_room_page_reaction_parse.dart';

void main() {
  group('RoomRoomPageReactionParse', () {
    test('__NEXT_DATA__ から like / comment を抽出できる', () {
      const html = '''
<html><head></head><body>
<script id="__NEXT_DATA__" type="application/json">
{"props":{"pageProps":{"product":{"likeCount":12,"commentCount":0}}}}
</script>
</body></html>
''';
      final r = RoomRoomPageReactionParse.tryParse(html);
      expect(r.roomLikeCount, 12);
      expect(r.roomCommentCount, 0);
    });

    test('正規表現フォールバックで抽出できる', () {
      const html = '<html>"likeCount": 5, "commentCount": 2</html>';
      final r = RoomRoomPageReactionParse.tryParse(html);
      expect(r.roomLikeCount, 5);
      expect(r.roomCommentCount, 2);
    });

    test('見つからない場合は null', () {
      const html = '<html><body>no data</body></html>';
      final r = RoomRoomPageReactionParse.tryParse(html);
      expect(r.roomLikeCount, isNull);
      expect(r.roomCommentCount, isNull);
    });
  });
}
