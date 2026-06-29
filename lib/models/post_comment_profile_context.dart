/// ROOM診断プロファイル由来の投稿文生成コンテキスト（API payload 用）。
class PostCommentProfileContext {
  const PostCommentProfileContext({
    required this.roomType,
    this.interestCategories = const [],
    this.priorityRules = const [],
    this.commentAngles = const [],
  });

  final String roomType;
  final List<String> interestCategories;
  final List<String> priorityRules;
  final List<String> commentAngles;

  Map<String, dynamic> toJson() => {
        'room_type': roomType,
        'interest_categories': List<String>.from(interestCategories),
        'priority_rules': List<String>.from(priorityRules),
        'comment_angles': List<String>.from(commentAngles),
      };
}
