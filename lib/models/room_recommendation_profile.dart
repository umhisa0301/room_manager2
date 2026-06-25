/// ROOM提案プロファイル（診断結果の永続化モデル）。
class RoomRecommendationProfile {
  const RoomRecommendationProfile({
    required this.primaryTypeId,
    this.secondaryTypeIds = const [],
    this.interestCategoryIds = const [],
    this.priorityRuleIds = const [],
    this.searchKeywordPresets = const [],
    this.positiveKeywordIds = const [],
    this.preferredGenreGroupIds = const [],
    this.commentAngleId = '',
    this.commentToneId = '',
    required this.diagnosedAt,
    this.exclusionPreferenceIds = const [],
  });

  final String primaryTypeId;
  final List<String> secondaryTypeIds;
  final List<String> interestCategoryIds;
  final List<String> priorityRuleIds;
  final List<String> searchKeywordPresets;
  final List<String> positiveKeywordIds;
  final List<String> preferredGenreGroupIds;
  final String commentAngleId;
  final String commentToneId;
  final DateTime diagnosedAt;

  /// Q5 除外候補（V1: モデルのみ、画面は後回し可）。
  final List<String> exclusionPreferenceIds;

  bool get isDiagnosed => primaryTypeId.trim().isNotEmpty;

  RoomRecommendationProfile copyWith({
    String? primaryTypeId,
    List<String>? secondaryTypeIds,
    List<String>? interestCategoryIds,
    List<String>? priorityRuleIds,
    List<String>? searchKeywordPresets,
    List<String>? positiveKeywordIds,
    List<String>? preferredGenreGroupIds,
    String? commentAngleId,
    String? commentToneId,
    DateTime? diagnosedAt,
    List<String>? exclusionPreferenceIds,
  }) {
    return RoomRecommendationProfile(
      primaryTypeId: primaryTypeId ?? this.primaryTypeId,
      secondaryTypeIds: secondaryTypeIds ?? this.secondaryTypeIds,
      interestCategoryIds: interestCategoryIds ?? this.interestCategoryIds,
      priorityRuleIds: priorityRuleIds ?? this.priorityRuleIds,
      searchKeywordPresets: searchKeywordPresets ?? this.searchKeywordPresets,
      positiveKeywordIds: positiveKeywordIds ?? this.positiveKeywordIds,
      preferredGenreGroupIds:
          preferredGenreGroupIds ?? this.preferredGenreGroupIds,
      commentAngleId: commentAngleId ?? this.commentAngleId,
      commentToneId: commentToneId ?? this.commentToneId,
      diagnosedAt: diagnosedAt ?? this.diagnosedAt,
      exclusionPreferenceIds:
          exclusionPreferenceIds ?? this.exclusionPreferenceIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryTypeId': primaryTypeId,
      'secondaryTypeIds': secondaryTypeIds,
      'interestCategoryIds': interestCategoryIds,
      'priorityRuleIds': priorityRuleIds,
      'searchKeywordPresets': searchKeywordPresets,
      'positiveKeywordIds': positiveKeywordIds,
      'preferredGenreGroupIds': preferredGenreGroupIds,
      'commentAngleId': commentAngleId,
      'commentToneId': commentToneId,
      'diagnosedAt': diagnosedAt.toIso8601String(),
      'exclusionPreferenceIds': exclusionPreferenceIds,
    };
  }

  static RoomRecommendationProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final primary = (json['primaryTypeId'] ?? '').toString().trim();
    if (primary.isEmpty) return null;
    final diagnosedRaw = (json['diagnosedAt'] ?? '').toString().trim();
    DateTime? diagnosedAt;
    try {
      diagnosedAt = DateTime.parse(diagnosedRaw);
    } catch (_) {
      diagnosedAt = DateTime.now();
    }
    return RoomRecommendationProfile(
      primaryTypeId: primary,
      secondaryTypeIds: _stringList(json['secondaryTypeIds']),
      interestCategoryIds: _stringList(json['interestCategoryIds']),
      priorityRuleIds: _stringList(json['priorityRuleIds']),
      searchKeywordPresets: _stringList(json['searchKeywordPresets']),
      positiveKeywordIds: _stringList(json['positiveKeywordIds']),
      preferredGenreGroupIds: _stringList(json['preferredGenreGroupIds']),
      commentAngleId: (json['commentAngleId'] ?? '').toString(),
      commentToneId: (json['commentToneId'] ?? '').toString(),
      diagnosedAt: diagnosedAt,
      exclusionPreferenceIds: _stringList(json['exclusionPreferenceIds']),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
}

/// 診断回答（画面→プロファイル変換用）。
class RoomDiagnosisAnswers {
  const RoomDiagnosisAnswers({
    required this.primaryTypeId,
    this.priorityRuleIds = const [],
    this.interestCategoryIds = const [],
    this.commentToneId = '',
    this.exclusionPreferenceIds = const [],
  });

  final String primaryTypeId;
  final List<String> priorityRuleIds;
  final List<String> interestCategoryIds;
  final String commentToneId;
  final List<String> exclusionPreferenceIds;
}

/// おすすめコレ枠の役割（将来の3枠分け用）。
enum RecommendationSlotRole {
  personalFit,
  trustedPick,
  discovery,
}
