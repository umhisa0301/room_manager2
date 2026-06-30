import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/post_style_preview_sample_product.dart';
import 'package:room_manager2/models/post_comment_profile_context.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
import 'package:room_manager2/services/post_comment_request_builder.dart';

void main() {
  group('PostCommentRequestBuilder', () {
    const builder = PostCommentRequestBuilder();

    PostCommentGenerationInput fullInput({
      PostStyleSettings? styleSettings,
      PostCommentProfileContext? profileContext,
      String genreName = 'キッチン用品',
      String genreId = '558944',
      String shopName = 'ショップ名',
    }) {
      return PostCommentGenerationInput(
        itemName: '商品タイトル',
        recommendationReason: 'レビュー評価が高く、価格も手頃',
        itemPrice: 1980,
        reviewAverage: 4.5,
        reviewCount: 120,
        genreName: genreName,
        genreId: genreId,
        shopName: shopName,
        styleSettings: styleSettings ??
            PostStyleSettings.defaults().copyWith(
              tone: PostTone.friendlyPolite,
              length: PostLength.standard,
              focusPoints: const [
                PostFocusPoint.costPerformance,
                PostFocusPoint.reviews,
                PostFocusPoint.dailyUse,
              ],
              targetAudience: PostTargetAudience.parents,
            ),
        profileContext: profileContext,
      );
    }

    test('includes appId taskId promptVersion', () {
      final json = builder.build(input: fullInput());

      expect(json['appId'], 'room_management');
      expect(json['taskId'], 'room_post_comment');
      expect(json['promptVersion'], 'v1');
    });

    test('maps product fields to snake_case', () {
      final payload = builder.build(input: fullInput())['payload'] as Map;

      final product = payload['product'] as Map;
      expect(product['title'], '商品タイトル');
      expect(product['display_title'], '商品タイトル');
      expect(product['price'], 1980);
      expect(product['review_average'], 4.5);
      expect(product['review_count'], 120);
      expect(product['genre'], 'キッチン用品');
      expect(product['genre_id'], '558944');
      expect(product['shop_name'], 'ショップ名');
      expect(product['recommendation_reason'], 'レビュー評価が高く、価格も手頃');
    });

    test('maps extended product fields when provided', () {
      final input = fullInput().copyWith(
        rawTitle: '長い楽天商品タイトル キッチン用品 便利',
        titleKeywords: const ['キッチン用品', '時短'],
        productUrl: 'https://item.rakuten.co.jp/example/',
        imageUrl: 'https://example.com/image.jpg',
      );
      final product =
          (builder.build(input: input)['payload'] as Map)['product'] as Map;

      expect(product['raw_title'], '長い楽天商品タイトル キッチン用品 便利');
      expect(product['display_title'], '商品タイトル');
      expect(product['title_keywords'], ['キッチン用品', '時短']);
      expect(product['product_url'], 'https://item.rakuten.co.jp/example/');
      expect(product['image_url'], 'https://example.com/image.jpg');
    });

    test('preview sample product maps display title genre and shop', () {
      final input = PostStylePreviewSampleProduct.toGenerationInput();
      final product =
          (builder.build(input: input)['payload'] as Map)['product'] as Map;

      expect(product['title'], PostStylePreviewSampleProduct.displayTitle);
      expect(product['display_title'], PostStylePreviewSampleProduct.displayTitle);
      expect(product['raw_title'], PostStylePreviewSampleProduct.rawTitle);
      expect(product['title_keywords'], PostStylePreviewSampleProduct.titleKeywords);
      expect(product['genre'], PostStylePreviewSampleProduct.genre);
      expect(product['shop_name'], PostStylePreviewSampleProduct.shopName);
      expect(
        product['recommendation_reason'],
        PostStylePreviewSampleProduct.recommendationReason,
      );
      expect(product['product_url'], PostStylePreviewSampleProduct.productUrl);
      expect(product['image_url'], PostStylePreviewSampleProduct.imageUrl);
    });

    test('maps user_style to snake_case', () {
      final payload = builder.build(input: fullInput())['payload'] as Map;

      final userStyle = payload['user_style'] as Map;
      expect(userStyle['tone'], 'friendly_polite');
      expect(userStyle['length'], 'standard');
      expect(userStyle['target_length_chars'], 120);
      expect(userStyle['emoji_level'], 'low');
      expect(userStyle['kaomoji_enabled'], false);
      expect(userStyle['hashtag_level'], 'standard');
      expect(userStyle['hashtag_count'], 5);
      expect(userStyle['focus_points'], [
        'cost_performance',
        'reviews',
        'daily_use',
      ]);
      expect(userStyle['target_audience'], 'parents');
      expect(userStyle['avoid_overstatement'], true);
    });

    test('maps generation_options from length setting', () {
      final payload = builder.build(input: fullInput())['payload'] as Map;

      final options = payload['generation_options'] as Map;
      expect(options['min_body_chars'], 100);
      expect(options['max_body_chars'], 140);
      expect(options['max_hashtags'], 5);
      expect(options['max_output_tokens'], 180);
      expect(options['max_total_chars'], 220);
    });

    test('omits example_text when includeStyleExample is false', () {
      final payload = builder.build(
        input: fullInput(
          styleSettings: PostStyleSettings.defaults().copyWith(
            styleExample: 'ユーザー文例サンプル',
          ),
        ).copyWith(includeStyleExample: false),
      )['payload'] as Map;

      final userStyle = payload['user_style'] as Map;
      expect(userStyle.containsKey('example_text'), isFalse);
    });

    test('includes example_text when includeStyleExample is true', () {
      final payload = builder.build(
        input: fullInput(
          styleSettings: PostStyleSettings.defaults().copyWith(
            styleExample: 'ユーザー文例サンプル',
          ),
        ),
      )['payload'] as Map;

      final userStyle = payload['user_style'] as Map;
      expect(userStyle['example_text'], 'ユーザー文例サンプル');
    });

    test('omits example_text when styleExample is empty', () {
      final payload = builder.build(
        input: fullInput(
          styleSettings: PostStyleSettings.defaults().copyWith(
            styleExample: '   ',
          ),
        ),
      )['payload'] as Map;

      final userStyle = payload['user_style'] as Map;
      expect(userStyle.containsKey('example_text'), isFalse);
    });

    test('omits profile_context when null', () {
      final payload = builder.build(input: fullInput())['payload'] as Map;

      expect(payload.containsKey('profile_context'), isFalse);
    });

    test('includes profile_context when provided', () {
      const profileContext = PostCommentProfileContext(
        roomType: '暮らし便利型',
        interestCategories: ['キッチン', '収納'],
        priorityRules: ['実用性が高い・暮らしに役立つ'],
        commentAngles: ['日常のちょっとした不便を減らす', '時短になる'],
      );

      final payload = builder.build(
        input: fullInput(profileContext: profileContext),
      )['payload'] as Map;

      final context = payload['profile_context'] as Map;
      expect(context['room_type'], '暮らし便利型');
      expect(context['interest_categories'], ['キッチン', '収納']);
      expect(context['priority_rules'], ['実用性が高い・暮らしに役立つ']);
      expect(context['comment_angles'], ['日常のちょっとした不便を減らす', '時短になる']);
    });

    test('omits empty genre shopName and genreId', () {
      final payload = builder.build(
        input: fullInput(genreName: '', genreId: '', shopName: ''),
      )['payload'] as Map;

      final product = payload['product'] as Map;
      expect(product.containsKey('genre'), isFalse);
      expect(product.containsKey('genre_id'), isFalse);
      expect(product.containsKey('shop_name'), isFalse);
    });

    test('uses normalized focus_points from style settings', () {
      final input = fullInput(
        styleSettings: PostStyleSettings.defaults().copyWith(
          focusPoints: const [
            PostFocusPoint.costPerformance,
            PostFocusPoint.costPerformance,
            PostFocusPoint.reviews,
          ],
        ),
      );

      final userStyle =
          (builder.build(input: input)['payload'] as Map)['user_style'] as Map;
      expect(userStyle['focus_points'], ['cost_performance', 'reviews']);
    });

    test('omits empty recommendation_reason', () {
      final payload = builder.build(
        input: PostCommentGenerationInput(
          itemName: '商品タイトル',
          recommendationReason: '   ',
          itemPrice: 1000,
          reviewAverage: 4.0,
          reviewCount: 10,
        ),
      )['payload'] as Map;

      final product = payload['product'] as Map;
      expect(product.containsKey('recommendation_reason'), isFalse);
    });
  });
}
