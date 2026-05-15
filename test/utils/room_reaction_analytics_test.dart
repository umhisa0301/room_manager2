import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/utils/room_reaction_analytics.dart';

void main() {
  group('roomReactionAnalytics', () {
    final t = DateTime.parse('2024-06-01T12:00:00.000Z');

    RakutenManagedProduct p({
      RakutenManagedProductStatus status = RakutenManagedProductStatus.done,
      String roomUrl = 'https://room.rakuten.co.jp/a',
      int? like,
      int? comment,
      String genreName = '',
      String shopName = '',
      String shopCode = '',
    }) {
      return RakutenManagedProduct(
        productId: 'pid:${like}_$comment',
        itemName: 'item',
        itemPrice: 0,
        itemUrl: 'https://item.rakuten.co.jp/x',
        imageUrl: '',
        shopName: shopName,
        shopCode: shopCode,
        shopUrl: '',
        genreId: '',
        genreName: genreName,
        status: status,
        createdAt: t,
        updatedAt: t,
        addedAt: t,
        extractedUrl: '',
        extractionStatus: RakutenUrlExtractionStatus.notStarted,
        extractionErrorMessage: '',
        roomUrl: roomUrl,
        doneAt: t,
        roomLikeCount: like,
        roomCommentCount: comment,
      );
    }

    test('eligible は done かつ roomUrl かつ カウント取得済み', () {
      expect(roomReactionAnalyticsIsEligible(p(like: 0, comment: null)), true);
      expect(roomReactionAnalyticsIsEligible(p(roomUrl: '')), false);
      expect(
        roomReactionAnalyticsIsEligible(
          p(like: null, comment: null),
        ),
        false,
      );
      expect(roomReactionAnalyticsIsEligible(p(like: 0, comment: null)), true);
    });

    test('reactionScore は like + comment*3', () {
      expect(roomReactionAnalyticsReactionScore(p(like: 2, comment: 1)), 5);
    });

    test('genre 空は ジャンル未確認', () {
      expect(roomReactionAnalyticsGenreBucket(p()), 'ジャンル未確認');
      expect(
        roomReactionAnalyticsGenreBucket(p(genreName: ' 服 ')),
        '服',
      );
    });

    test('shopName 空なら shopCode をラベルに', () {
      final b = roomReactionAnalyticsShopBucket(
        p(shopName: '', shopCode: 'sc1'),
      );
      expect(b.label, 'sc1');
      expect(b.key, 'code:sc1');
    });
  });
}
