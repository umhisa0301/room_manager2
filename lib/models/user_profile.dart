/// ユーザー情報（将来の AI コメント生成などに利用想定。すべて任意）。
class UserProfile {
  const UserProfile({
    this.displayName = '',
    this.age,
    this.genderKey,
    this.occupation = '',
    this.favoriteGenres = '',
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

  final String displayName;
  final int? age;
  final String? genderKey;
  final String occupation;
  final String favoriteGenres;
  /// 楽天ROOMのプロフィールまたはトップページURL
  final String roomUrl;

  /// 主要情報（ホーム表示やおすすめ生成の起点）入力済み判定。
  bool get hasCoreProfile {
    return displayName.trim().isNotEmpty ||
        roomUrl.trim().isNotEmpty ||
        favoriteGenreList.isNotEmpty;
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

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'age': age,
      'genderKey': genderKey,
      'occupation': occupation,
      'favoriteGenres': favoriteGenres,
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
      roomUrl: json['roomUrl'] as String? ?? '',
    );
  }
}
