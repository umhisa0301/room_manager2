/// ユーザー情報（将来の AI コメント生成などに利用想定。すべて任意）。
class UserProfile {
  const UserProfile({
    this.displayName = '',
    this.age,
    this.genderKey,
    this.occupation = '',
    this.favoriteGenres = '',
    this.favoriteGenreIds = '',
    this.postStyles = '',
    this.roomUrl = '',
  });

  /// 表示用の性別キー（null = 未選択）
  static const String genderMale = 'male';
  static const String genderFemale = 'female';
  static const String genderOther = 'other';
  static const String genderPreferNot = 'prefer_not';

  static String? genderLabelJa(String? key) {
    switch (key) {
      case genderMale:
        return '男性';
      case genderFemale:
        return '女性';
      case genderOther:
        return 'その他';
      case genderPreferNot:
        return '回答しない';
      default:
        return null;
    }
  }

  static const String postStyleBalance = 'balance';
  static const String postStyleAffordable = 'affordable';
  static const String postStylePremium = 'premium';
  static const String postStyleHighlyRated = 'highly_rated';
  static const String postStyleSocial = 'social';
  static const String postStylePractical = 'practical';
  static const String postStyleReviewRich = 'review_rich';
  static const String postStyleTrend = 'trend';

  static const List<String> postStyleKeys = [
    postStyleBalance,
    postStyleAffordable,
    postStylePremium,
    postStyleHighlyRated,
    postStyleSocial,
    postStylePractical,
    postStyleReviewRich,
    postStyleTrend,
  ];

  static String postStyleLabelJa(String key) {
    switch (key) {
      case postStyleBalance:
        return 'バランス';
      case postStyleAffordable:
        return 'お手頃価格';
      case postStylePremium:
        return '高単価';
      case postStyleHighlyRated:
        return '高評価';
      case postStyleSocial:
        return '見た目重視';
      case postStylePractical:
        return '実用的';
      case postStyleReviewRich:
        return 'レビュー多め';
      case postStyleTrend:
        return '新着・トレンド';
      default:
        return key;
    }
  }

  static String postStyleDescriptionJa(String key) {
    switch (key) {
      case postStyleBalance:
        return '商品数・評価・レビューを総合的に見ます';
      case postStyleAffordable:
        return '買いやすい価格帯を優先します';
      case postStylePremium:
        return '成果単価が高そうな商品を優先します';
      case postStyleHighlyRated:
        return 'レビュー評価が高い商品を優先します';
      case postStyleSocial:
        return '画像で紹介しやすい商品を優先します';
      case postStylePractical:
        return '日用品・育児・生活用品などを優先します';
      case postStyleReviewRich:
        return 'レビュー件数が多い商品を優先します';
      case postStyleTrend:
        return '新しさや季節感を重視します';
      default:
        return '';
    }
  }

  /// ニックネーム（任意）。将来の AI おすすめ文・投稿文生成にも利用する。
  final String displayName;
  final int? age;
  final String? genderKey;
  final String occupation;
  final String favoriteGenres;

  /// 好きなジャンルの楽天 `genreId` を `、` または `,` 区切りで保持（最大5件想定・UI側で制御）。
  final String favoriteGenreIds;

  /// 商品探索の傾向設定。`postStyleKeys` の値を `、` または `,` 区切りで最大3件保持する。
  final String postStyles;

  /// 楽天ROOMのプロフィールまたはトップページURL
  final String roomUrl;

  /// 主要情報（ホーム表示やおすすめ生成の起点）入力済み判定。
  bool get hasCoreProfile {
    return displayName.trim().isNotEmpty ||
        roomUrl.trim().isNotEmpty ||
        postStyleList.isNotEmpty ||
        favoriteGenreList.isNotEmpty ||
        favoriteGenreIdList.isNotEmpty;
  }

  bool get hasRoomUrl => roomUrl.trim().isNotEmpty;

  /// 好きなジャンルを正規化した配列（重複除去・空要素除去）。
  List<String> get favoriteGenreList {
    final tokens = favoriteGenres.split(RegExp(r'[、,\n]'));
    final normalized = <String>[];
    final seen = <String>{};
    for (final token in tokens) {
      final text = token.trim();
      if (text.isEmpty) continue;
      final key = text.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      normalized.add(text);
    }
    return normalized;
  }

  /// [favoriteGenreIds] を正規化した配列（重複除去・空要素除去）。
  List<String> get favoriteGenreIdList {
    final tokens = favoriteGenreIds.split(RegExp(r'[、,\n]+'));
    final normalized = <String>[];
    final seen = <String>{};
    for (final token in tokens) {
      final text = token.trim();
      if (text.isEmpty) continue;
      if (seen.contains(text)) continue;
      seen.add(text);
      normalized.add(text);
    }
    return normalized;
  }

  List<String> get postStyleList {
    final tokens = postStyles.split(RegExp(r'[、,\n]+'));
    final normalized = <String>[];
    final seen = <String>{};
    for (final token in tokens) {
      final text = token.trim();
      if (text.isEmpty) continue;
      if (!postStyleKeys.contains(text)) continue;
      if (seen.contains(text)) continue;
      seen.add(text);
      normalized.add(text);
      if (normalized.length >= 3) break;
    }
    return normalized;
  }

  List<String> get effectivePostStyleList {
    final selected = postStyleList;
    return selected.isEmpty ? const [postStyleBalance] : selected;
  }

  String get postStyleLabelsText {
    final selected = postStyleList;
    if (selected.isEmpty) return '未設定';
    return selected.map(postStyleLabelJa).join('・');
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'age': age,
      'genderKey': genderKey,
      'occupation': occupation,
      'favoriteGenres': favoriteGenres,
      'favoriteGenreIds': favoriteGenreIds,
      'postStyles': postStyles,
      'roomUrl': roomUrl,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserProfile();
    return UserProfile(
      displayName: json['displayName'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      genderKey: json['genderKey'] as String?,
      occupation: json['occupation'] as String? ?? '',
      favoriteGenres: json['favoriteGenres'] as String? ?? '',
      favoriteGenreIds: json['favoriteGenreIds'] as String? ?? '',
      postStyles:
          json['postStyles'] as String? ??
          json['postingStyles'] as String? ??
          '',
      roomUrl: json['roomUrl'] as String? ?? '',
    );
  }
}
