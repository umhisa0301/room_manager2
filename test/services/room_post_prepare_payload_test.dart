import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/post_style_preview_sample_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
import 'package:room_manager2/services/post_comment_request_builder.dart';

void main() {
  group('room post prepare payload', () {
    const builder = PostCommentRequestBuilder();

    test('includes genre shop product_url image_url and raw_title', () {
      const item = RakutenSearchItem(
        productId: '123',
        itemName: 'バスケット 収納 収納かご 北欧風収納バスケット 日用品',
        itemPrice: 1980,
        itemUrl: 'https://item.rakuten.co.jp/example/',
        affiliateUrl: '',
        imageUrl: 'https://example.com/image.jpg',
        shopName: 'テストショップ',
        reviewCount: 32,
        reviewAverage: 4.9,
        genreId: '100',
        genreName: '収納かご',
      );

      final input = PostCommentGenerationInput(
        itemName: '北欧風の収納バスケット',
        rawTitle: item.itemName,
        recommendationReason: 'おすすめ理由',
        itemPrice: item.itemPrice,
        reviewAverage: item.reviewAverage,
        reviewCount: item.reviewCount,
        genreName: item.genreName,
        genreId: item.genreId,
        shopName: item.shopName,
        productUrl: item.itemUrl,
        imageUrl: item.imageUrl,
        styleSettings: PostStyleSettings.defaults().copyWith(
          styleExample: '保存済み文例',
        ),
      );

      final product =
          (builder.build(input: input)['payload'] as Map)['product'] as Map;
      final userStyle =
          (builder.build(input: input)['payload'] as Map)['user_style'] as Map;

      expect(product['genre'], '収納かご');
      expect(product['shop_name'], 'テストショップ');
      expect(product['product_url'], 'https://item.rakuten.co.jp/example/');
      expect(product['image_url'], 'https://example.com/image.jpg');
      expect(product['raw_title'], item.itemName);
      expect(product['display_title'], '北欧風の収納バスケット');
      expect(userStyle['example_text'], '保存済み文例');
    });

    test('default style settings omit stub preview from remote payload', () {
      const item = RakutenSearchItem(
        productId: 'shop:item001',
        itemName: 'おすすめ商品テスト',
        itemPrice: 2980,
        itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
        affiliateUrl: '',
        imageUrl: 'https://example.com/p.jpg',
        shopName: 'テストショップ',
        reviewCount: 42,
        reviewAverage: 4.35,
        genreId: '100',
        genreName: 'ジャンル',
      );

      final input = PostCommentGenerationInput(
        itemName: 'おすすめ商品テスト',
        rawTitle: item.itemName,
        recommendationReason: '人気の定番',
        itemPrice: item.itemPrice,
        reviewAverage: item.reviewAverage,
        reviewCount: item.reviewCount,
        genreName: item.genreName,
        genreId: item.genreId,
        shopName: item.shopName,
        productUrl: item.itemUrl,
        imageUrl: item.imageUrl,
        styleSettings: PostStyleSettings.defaults(),
      );

      final userStyle =
          (builder.build(input: input)['payload'] as Map)['user_style'] as Map;

      expect(userStyle.containsKey('example_text'), isFalse);
    });

    test('post style preview refresh path omits stub preview example_text', () {
      final input = PostStylePreviewSampleProduct.toGenerationInput().copyWith(
        styleSettings: PostStyleSettings.defaults().copyWith(
          styleExample: 'Stubプレビューで表示された仮文',
        ),
      );

      final userStyle = (builder.build(input: input)['payload'] as Map)['user_style']
          as Map;

      expect(input.includeStyleExample, isFalse);
      expect(userStyle.containsKey('example_text'), isFalse);
    });
  });
}
