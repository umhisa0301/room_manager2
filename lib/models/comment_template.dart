/// コメントテンプレートのモデル。
/// 楽天ROOM用コメントの定型文を表現する。
class CommentTemplate {
  const CommentTemplate({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String? category;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommentTemplate copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommentTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static CommentTemplate? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final id = json['id'] as String?;
      final title = json['title'] as String?;
      final body = json['body'] as String?;
      if (id == null || id.isEmpty || title == null || body == null) {
        return null;
      }
      final createdAt = _parseDateTime(json['createdAt']);
      final updatedAt = _parseDateTime(json['updatedAt']);
      if (createdAt == null || updatedAt == null) return null;

      return CommentTemplate(
        id: id,
        title: title,
        body: body,
        category: json['category'] as String?,
        isFavorite: (json['isFavorite'] as bool?) ?? false,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}

