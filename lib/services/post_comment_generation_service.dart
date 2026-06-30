import '../models/post_comment_generation_result.dart';
import '../models/post_comment_profile_context.dart';
import '../models/post_style_settings.dart';
import 'stub_post_comment_builder.dart';

/// AI投稿文生成の入力。
class PostCommentGenerationInput {
  const PostCommentGenerationInput({
    required this.itemName,
    required this.recommendationReason,
    required this.itemPrice,
    required this.reviewAverage,
    required this.reviewCount,
    this.rawTitle = '',
    this.titleKeywords = const [],
    this.genreName = '',
    this.genreId = '',
    this.shopName = '',
    this.productUrl = '',
    this.imageUrl = '',
    this.styleSettings,
    this.profileContext,
    this.includeStyleExample = true,
  });

  /// AI生成・画面表示用の短い商品名（payload の title に入る）。
  final String itemName;

  /// 楽天市場の商品タイトルそのまま（参考情報。本文には直接使わない）。
  final String rawTitle;

  /// rawTitle から抽出した特徴語（ハッシュタグ・説明補助用）。
  final List<String> titleKeywords;

  final String recommendationReason;
  final int itemPrice;
  final double reviewAverage;
  final int reviewCount;
  final String genreName;
  final String genreId;
  final String shopName;
  final String productUrl;
  final String imageUrl;

  /// 未指定時は [PostStyleSettings.defaults] を利用。
  final PostStyleSettings? styleSettings;

  /// ROOM診断プロファイル由来のコンテキスト。API 送信時のみ利用。
  final PostCommentProfileContext? profileContext;

  /// `false` のとき user_style.example_text を送らない（生成イメージ更新用）。
  final bool includeStyleExample;

  PostStyleSettings get effectiveStyleSettings =>
      styleSettings ?? PostStyleSettings.defaults();

  PostCommentGenerationInput copyWith({
    String? itemName,
    String? rawTitle,
    List<String>? titleKeywords,
    String? recommendationReason,
    int? itemPrice,
    double? reviewAverage,
    int? reviewCount,
    String? genreName,
    String? genreId,
    String? shopName,
    String? productUrl,
    String? imageUrl,
    PostStyleSettings? styleSettings,
    PostCommentProfileContext? profileContext,
    bool? includeStyleExample,
  }) {
    return PostCommentGenerationInput(
      itemName: itemName ?? this.itemName,
      rawTitle: rawTitle ?? this.rawTitle,
      titleKeywords: titleKeywords ?? this.titleKeywords,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      itemPrice: itemPrice ?? this.itemPrice,
      reviewAverage: reviewAverage ?? this.reviewAverage,
      reviewCount: reviewCount ?? this.reviewCount,
      genreName: genreName ?? this.genreName,
      genreId: genreId ?? this.genreId,
      shopName: shopName ?? this.shopName,
      productUrl: productUrl ?? this.productUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      styleSettings: styleSettings ?? this.styleSettings,
      profileContext: profileContext ?? this.profileContext,
      includeStyleExample: includeStyleExample ?? this.includeStyleExample,
    );
  }
}

/// 投稿文のAI生成（OpenAI 等の実装は将来差し替え）。
abstract class PostCommentGenerationService {
  Future<PostCommentGenerationResult> generate(PostCommentGenerationInput input);
}

/// API未接続段階のスタブ。商品情報と投稿スタイル設定から仮の投稿文を返す。
class StubPostCommentGenerationService implements PostCommentGenerationService {
  const StubPostCommentGenerationService({
    this.delay = const Duration(milliseconds: 500),
    this.defaultStyleSettings,
  });

  final Duration delay;

  /// 入力にスタイル未指定のときのフォールバック（Provider 注入用）。
  final PostStyleSettings? defaultStyleSettings;

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    await Future<void>.delayed(delay);
    final style =
        input.styleSettings ?? defaultStyleSettings ?? PostStyleSettings.defaults();
    final text = StubPostCommentBuilder.build(input: input, style: style);
    return PostCommentGenerationResult(body: text, fullText: text);
  }
}
