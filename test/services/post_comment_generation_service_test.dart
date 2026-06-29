import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';

void main() {
  group('StubPostCommentGenerationService', () {
    const input = PostCommentGenerationInput(
      itemName: 'テスト商品',
      recommendationReason: '売れ筋',
      itemPrice: 1500,
      reviewAverage: 4.5,
      reviewCount: 10,
    );

    test('generates comment from product info', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final text = await service.generate(input);

      expect(text, contains('テスト商品'));
      expect(text, contains('売れ筋'));
      expect(text, contains('￥1,500'));
      expect(text, contains('#楽天ROOM'));
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

    test('reflects casual tone', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final text = await service.generate(
        PostCommentGenerationInput(
          itemName: input.itemName,
          recommendationReason: input.recommendationReason,
          itemPrice: input.itemPrice,
          reviewAverage: input.reviewAverage,
          reviewCount: input.reviewCount,
          styleSettings: PostStyleSettings.defaults().copyWith(
            tone: PostTone.casual,
            hashtagLevel: HashtagLevel.none,
            emojiLevel: EmojiLevel.none,
          ),
        ),
      );

      expect(text, contains('見つけたよ'));
      expect(text, contains('見てみてね'));
      expect(text, isNot(contains('#楽天ROOM')));
    });

    test('adds hashtags when enabled', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final text = await service.generate(
        PostCommentGenerationInput(
          itemName: input.itemName,
          recommendationReason: input.recommendationReason,
          itemPrice: input.itemPrice,
          reviewAverage: input.reviewAverage,
          reviewCount: input.reviewCount,
          styleSettings: PostStyleSettings.defaults().copyWith(
            hashtagLevel: HashtagLevel.few,
            emojiLevel: EmojiLevel.none,
          ),
        ),
      );

      expect(text, contains('#楽天ROOM'));
      expect(text, contains('#おすすめ'));
      expect(text, isNot(contains('#コスパ')));
    });

    test('respects body length limits for short setting', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final text = await service.generate(
        PostCommentGenerationInput(
          itemName: input.itemName,
          recommendationReason: input.recommendationReason,
          itemPrice: input.itemPrice,
          reviewAverage: input.reviewAverage,
          reviewCount: input.reviewCount,
          styleSettings: PostStyleSettings.defaults().copyWith(
            length: PostLength.short,
            hashtagLevel: HashtagLevel.none,
            emojiLevel: EmojiLevel.none,
            focusPoints: const [PostFocusPoint.costPerformance],
          ),
        ),
      );

      final limits = PostStyleSettings.defaults()
          .copyWith(length: PostLength.short)
          .generationLimits;
      expect(text.length, greaterThanOrEqualTo(limits.minBodyChars));
      expect(text.length, lessThanOrEqualTo(limits.maxBodyChars));
    });

    test('does not exceed maxTotalChars with hashtags', () async {
      const service = StubPostCommentGenerationService(delay: Duration.zero);
      final style = PostStyleSettings.defaults().copyWith(
        length: PostLength.detailed,
        hashtagLevel: HashtagLevel.standard,
        emojiLevel: EmojiLevel.medium,
        kaomojiEnabled: true,
        focusPoints: const [
          PostFocusPoint.costPerformance,
          PostFocusPoint.convenience,
          PostFocusPoint.reviews,
        ],
      );
      final text = await service.generate(
        PostCommentGenerationInput(
          itemName: 'とても長い商品名の収納バスケットセット',
          recommendationReason:
              '部屋になじみやすく、口コミ評価も高いアイテムです。毎日の片付けに役立ちそうです。',
          itemPrice: 1980,
          reviewAverage: 4.8,
          reviewCount: 120,
          styleSettings: style,
        ),
      );

      final limits = style.generationLimits;
      expect(text.length, lessThanOrEqualTo(limits.maxTotalChars));
      expect(text, contains('#楽天ROOM'));
    });

    test('uses defaultStyleSettings when input omits style', () async {
      final service = StubPostCommentGenerationService(
        delay: Duration.zero,
        defaultStyleSettings: PostStyleSettings(
          tone: PostTone.polite,
          length: PostLength.standard,
          emojiLevel: EmojiLevel.none,
          kaomojiEnabled: false,
          hashtagLevel: HashtagLevel.none,
          focusPoints: [PostFocusPoint.reviews],
          targetAudience: PostTargetAudience.general,
          avoidOverstatement: true,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );

      final text = await service.generate(input);
      expect(text, contains('ご紹介いたします'));
    });
  });
}
