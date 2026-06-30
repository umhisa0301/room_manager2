import '../services/post_comment_generation_service.dart';

/// 投稿スタイル設定画面の生成イメージ用サンプル商品。
class PostStylePreviewSampleProduct {
  PostStylePreviewSampleProduct._();

  static const String productUrl =
      'https://item.rakuten.co.jp/tamatoshi/200-0004/?iasid=07rpp_10095___3h-mr0x40oc-v-2ddd113a-cb84-41f5-99a0-972ef8ee6fb1';

  static const String rawTitle =
      'バスケット 収納 収納かご 北欧風収納バスケット 日用品 小物入れ カゴ レジャー アウトドア おもちゃ おもちゃ入れ 収納 食品 ストック エコバッグ 買い物 かご キャンプ BBQ ランドリー 衣類 おしゃれ 可愛い ピクニック メッシュ 整理 天然木';

  static const String displayTitle = '北欧風の収納バスケット';

  static const List<String> titleKeywords = [
    '収納かご',
    '北欧風',
    '小物入れ',
    'おもちゃ収納',
    'ランドリー',
    'レジャー',
    '天然木',
    'メッシュ',
  ];

  static const int price = 1980;

  static const double reviewAverage = 4.91;

  static const int reviewCount = 32;

  static const String genre = '収納かご';

  static const String shopName = 'ハンガー&インテリアTAMATOSHI';

  static const String imageUrl =
      'https://tshop.r10s.jp/tamatoshi/cabinet/item/200-0004/200-0004new/200-0004_0x.jpg?fitin=275:275';

  static const String recommendationReason =
      '北欧風のデザインで部屋になじみやすく、小物やおもちゃ、衣類の収納など普段使いしやすそうです。レビュー評価も高く、収納まわりを整えたい人に合いそうです。';

  /// 生成イメージ更新用の [PostCommentGenerationInput]。
  static PostCommentGenerationInput toGenerationInput() {
    return const PostCommentGenerationInput(
      itemName: displayTitle,
      rawTitle: rawTitle,
      titleKeywords: titleKeywords,
      recommendationReason: recommendationReason,
      itemPrice: price,
      reviewAverage: reviewAverage,
      reviewCount: reviewCount,
      genreName: genre,
      shopName: shopName,
      productUrl: productUrl,
      imageUrl: imageUrl,
      includeStyleExample: false,
    );
  }
}
