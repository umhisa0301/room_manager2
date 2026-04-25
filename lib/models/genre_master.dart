/// 楽天市場ジャンルマスター（ローカルキャッシュ・API応答の両方で利用）。
class GenreMaster {
  const GenreMaster({
    required this.genreId,
    required this.genreName,
    required this.level,
    required this.parentGenreId,
    required this.childGenreIds,
    required this.ancestorGenreIds,
    required this.ancestorNames,
    this.siblingGenreIds,
    this.updatedAt,
    this.rawJson,
  });

  /// 楽天ジャンルID（0 はルート扱い・未設定に近い）。
  final int genreId;

  /// 日本語ジャンル名。
  final String genreName;

  /// 階層レベル（ルートは 0）。
  final int level;

  /// 直近の親ジャンルID（なければ 0）。
  final int parentGenreId;

  /// 子ジャンルID一覧。
  final List<int> childGenreIds;

  /// 祖先ジャンルID（ルート→親の順）。
  final List<int> ancestorGenreIds;

  /// [ancestorGenreIds] に対応する日本語名（ルート→親の順）。
  final List<String> ancestorNames;

  /// 兄弟ジャンルID（APIが返す場合のみ）。
  final List<int>? siblingGenreIds;

  /// キャッシュ更新時刻。
  final DateTime? updatedAt;

  /// デバッグ・将来拡張用の生JSON。
  final String? rawJson;

  /// 「家電 > キッチン家電 > コーヒーメーカー」形式。
  String get fullPathLabel {
    final t = genreName.trim();
    if (ancestorNames.isEmpty) {
      return t.isEmpty ? '$genreId' : t;
    }
    final head = ancestorNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' > ');
    if (t.isEmpty) return head;
    if (head.isEmpty) return t;
    return '$head > $t';
  }

  GenreMaster copyWith({
    int? genreId,
    String? genreName,
    int? level,
    int? parentGenreId,
    List<int>? childGenreIds,
    List<int>? ancestorGenreIds,
    List<String>? ancestorNames,
    List<int>? siblingGenreIds,
    DateTime? updatedAt,
    String? rawJson,
  }) {
    return GenreMaster(
      genreId: genreId ?? this.genreId,
      genreName: genreName ?? this.genreName,
      level: level ?? this.level,
      parentGenreId: parentGenreId ?? this.parentGenreId,
      childGenreIds: childGenreIds ?? this.childGenreIds,
      ancestorGenreIds: ancestorGenreIds ?? this.ancestorGenreIds,
      ancestorNames: ancestorNames ?? this.ancestorNames,
      siblingGenreIds: siblingGenreIds ?? this.siblingGenreIds,
      updatedAt: updatedAt ?? this.updatedAt,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'genreId': genreId,
      'genreName': genreName,
      'level': level,
      'parentGenreId': parentGenreId,
      'childGenreIds': childGenreIds,
      'ancestorGenreIds': ancestorGenreIds,
      'ancestorNames': ancestorNames,
      if (siblingGenreIds != null) 'siblingGenreIds': siblingGenreIds,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (rawJson != null) 'rawJson': rawJson,
    };
  }

  factory GenreMaster.fromJson(Map<String, dynamic> json) {
    return GenreMaster(
      genreId: _asInt(json['genreId']) ?? 0,
      genreName: json['genreName']?.toString() ?? '',
      level: _asInt(json['level']) ?? 0,
      parentGenreId: _asInt(json['parentGenreId']) ?? 0,
      childGenreIds: _intList(json['childGenreIds']),
      ancestorGenreIds: _intList(json['ancestorGenreIds']),
      ancestorNames: _stringList(json['ancestorNames']),
      siblingGenreIds: json.containsKey('siblingGenreIds')
          ? _intList(json['siblingGenreIds'])
          : null,
      updatedAt: _parseDate(json['updatedAt']),
      rawJson: json['rawJson']?.toString(),
    );
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static List<int> _intList(Object? v) {
    if (v is! List) return const [];
    final out = <int>[];
    for (final e in v) {
      final n = _asInt(e);
      if (n != null) out.add(n);
    }
    return out;
  }

  static List<String> _stringList(Object? v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
