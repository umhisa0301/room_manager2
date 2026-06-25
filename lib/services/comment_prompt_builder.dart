import '../data/comment_tone_definitions.dart';
import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/rakuten_search_item.dart';
import '../models/room_recommendation_profile.dart';

/// AIコメント生成用プロンプトDTO。
class CommentPromptDto {
  const CommentPromptDto({
    required this.productName,
    required this.productDescription,
    required this.price,
    required this.reviewAverage,
    required this.reviewCount,
    required this.roomType,
    required this.interestCategories,
    required this.priorityRules,
    required this.commentAngles,
    required this.commentTone,
    required this.recommendationReason,
    required this.promptText,
  });

  final String productName;
  final String productDescription;
  final int price;
  final double reviewAverage;
  final int reviewCount;
  final String roomType;
  final List<String> interestCategories;
  final List<String> priorityRules;
  final List<String> commentAngles;
  final String commentTone;
  final String recommendationReason;
  final String promptText;

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'productDescription': productDescription,
        'price': price,
        'reviewAverage': reviewAverage,
        'reviewCount': reviewCount,
        'roomType': roomType,
        'interestCategories': interestCategories,
        'priorityRules': priorityRules,
        'commentAngles': commentAngles,
        'commentTone': commentTone,
        'recommendationReason': recommendationReason,
        'promptText': promptText,
      };
}

/// 将来のAIコメント生成向けプロンプト組み立て。
abstract final class CommentPromptBuilder {
  CommentPromptBuilder._();

  static CommentPromptDto build({
    required RakutenSearchItem item,
    required RoomRecommendationProfile profile,
    required String recommendationReason,
    String productDescription = '',
  }) {
    final typeName = RoomTypeDefinitions.displayNameFor(profile.primaryTypeId);
    final categories = InterestCategoryDefinitions.displayNamesFor(
      profile.interestCategoryIds,
    );
    final priorities = PriorityRuleDefinitions.displayNamesFor(
      profile.priorityRuleIds,
    );
    final angles = <String>[];
    for (final id in profile.priorityRuleIds) {
      final rule = PriorityRuleDefinitions.byId(id);
      if (rule != null) angles.addAll(rule.commentAngles);
    }
    final tone = CommentToneDefinitions.byId(profile.commentToneId);
    final toneLabel = tone?.displayName ?? '';
    final toneHint = tone?.promptHint ?? '';

    final prompt = StringBuffer()
      ..writeln('以下の商品について、楽天ROOM向けの紹介コメントを作成してください。')
      ..writeln()
      ..writeln('【商品情報】')
      ..writeln('商品名: ${item.itemName}')
      ..writeln('価格: ${item.itemPrice}円')
      ..writeln('レビュー平均: ${item.reviewAverage}')
      ..writeln('レビュー件数: ${item.reviewCount}')
      ..ifPresent(productDescription, (b, v) => b.writeln('商品説明: $v'))
      ..writeln()
      ..writeln('【ユーザー設定】')
      ..writeln('ROOMタイプ: $typeName')
      ..writeln('関心カテゴリ: ${categories.join('、')}')
      ..writeln('重視する条件: ${priorities.join('、')}')
      ..writeln('コメント訴求軸: ${angles.take(4).join('、')}')
      ..writeln('コメント文体: $toneLabel')
      ..ifPresent(toneHint, (b, v) => b.writeln('文体ヒント: $v'))
      ..writeln()
      ..writeln('【おすすめ理由】')
      ..writeln(recommendationReason);

    return CommentPromptDto(
      productName: item.itemName,
      productDescription: productDescription,
      price: item.itemPrice,
      reviewAverage: item.reviewAverage,
      reviewCount: item.reviewCount,
      roomType: typeName,
      interestCategories: categories,
      priorityRules: priorities,
      commentAngles: angles.take(4).toList(growable: false),
      commentTone: toneLabel,
      recommendationReason: recommendationReason,
      promptText: prompt.toString(),
    );
  }
}

extension _StringBufferConditional on StringBuffer {
  void ifPresent(String value, void Function(StringBuffer, String) fn) {
    if (value.trim().isNotEmpty) fn(this, value);
  }
}
