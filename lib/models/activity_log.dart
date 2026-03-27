/// 1日分のROOM運用ログ。
class ActivityLog {
  const ActivityLog({
    required this.dateKey,
    required this.collectedCount,
    required this.commentCount,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `yyyy-MM-dd` 形式の日付キー
  final String dateKey;
  final int collectedCount;
  final int commentCount;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  ActivityLog copyWith({
    String? dateKey,
    int? collectedCount,
    int? commentCount,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivityLog(
      dateKey: dateKey ?? this.dateKey,
      collectedCount: collectedCount ?? this.collectedCount,
      commentCount: commentCount ?? this.commentCount,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'collectedCount': collectedCount,
      'commentCount': commentCount,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ActivityLog? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final dateKey = json['dateKey'] as String?;
      if (dateKey == null || dateKey.isEmpty) return null;
      final createdAt = _parseDateTime(json['createdAt']);
      final updatedAt = _parseDateTime(json['updatedAt']);
      if (createdAt == null || updatedAt == null) return null;
      return ActivityLog(
        dateKey: dateKey,
        collectedCount: (json['collectedCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        memo: json['memo'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}

