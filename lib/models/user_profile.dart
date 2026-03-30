/// ユーザー情報（将来の AI コメント生成などに利用想定。すべて任意）。
class UserProfile {
  const UserProfile({
    this.displayName = '',
    this.age,
    this.genderKey,
    this.occupation = '',
    this.favoriteGenres = '',
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

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'age': age,
      'genderKey': genderKey,
      'occupation': occupation,
      'favoriteGenres': favoriteGenres,
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
    );
  }
}
