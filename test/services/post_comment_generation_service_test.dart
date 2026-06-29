import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';

void main() {
  group('StubPostCommentGenerationService', () {
    test('generates comment from product info', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final text = await service.generate(
        const PostCommentGenerationInput(
          itemName: 'テスト商品',
          recommendationReason: '売れ筋',
          itemPrice: 1500,
          reviewAverage: 4.5,
          reviewCount: 10,
        ),
      );

      expect(text, contains('テスト商品'));
      expect(text, contains('売れ筋'));
      expect(text, contains('￥1,500'));
      expect(text, contains('4.50'));
      expect(text, contains('10件'));
    });

    test('uses fallback reason when empty', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final text = await service.generate(
        const PostCommentGenerationInput(
          itemName: '商品A',
          recommendationReason: '',
          itemPrice: 0,
          reviewAverage: 0,
          reviewCount: 0,
        ),
      );

      expect(text, contains('気になった一品です'));
      expect(text, contains('￥ー'));
    });
  });
}
