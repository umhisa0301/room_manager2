/// 投稿文の文体。
enum PostTone {
  polite,
  friendlyPolite,
  casual;

  String toJsonKey() {
    switch (this) {
      case PostTone.polite:
        return 'polite';
      case PostTone.friendlyPolite:
        return 'friendly_polite';
      case PostTone.casual:
        return 'casual';
    }
  }

  static PostTone fromJsonKey(String? raw) {
    switch (raw) {
      case 'polite':
        return PostTone.polite;
      case 'friendly_polite':
        return PostTone.friendlyPolite;
      case 'casual':
        return PostTone.casual;
      default:
        return PostTone.friendlyPolite;
    }
  }
}

/// 投稿文の長さ。
enum PostLength {
  short,
  standard,
  detailed;

  String toJsonKey() => name;

  static PostLength fromJsonKey(String? raw) {
    switch (raw) {
      case 'short':
        return PostLength.short;
      case 'detailed':
        return PostLength.detailed;
      case 'standard':
      default:
        return PostLength.standard;
    }
  }
}

/// 絵文字の量。
enum EmojiLevel {
  none,
  low,
  medium;

  String toJsonKey() => name;

  static EmojiLevel fromJsonKey(String? raw) {
    switch (raw) {
      case 'none':
        return EmojiLevel.none;
      case 'medium':
        return EmojiLevel.medium;
      case 'low':
      default:
        return EmojiLevel.low;
    }
  }
}

/// ハッシュタグの量。
enum HashtagLevel {
  none,
  few,
  standard;

  String toJsonKey() => name;

  static HashtagLevel fromJsonKey(String? raw) {
    switch (raw) {
      case 'none':
        return HashtagLevel.none;
      case 'few':
        return HashtagLevel.few;
      case 'standard':
      default:
        return HashtagLevel.standard;
    }
  }
}

/// 投稿文の訴求軸（商品の書き方）。
enum PostFocusPoint {
  costPerformance,
  convenience,
  reviews,
  design,
  cute,
  gift,
  parenting,
  dailyUse;

  String toJsonKey() {
    switch (this) {
      case PostFocusPoint.costPerformance:
        return 'cost_performance';
      case PostFocusPoint.convenience:
        return 'convenience';
      case PostFocusPoint.reviews:
        return 'reviews';
      case PostFocusPoint.design:
        return 'design';
      case PostFocusPoint.cute:
        return 'cute';
      case PostFocusPoint.gift:
        return 'gift';
      case PostFocusPoint.parenting:
        return 'parenting';
      case PostFocusPoint.dailyUse:
        return 'daily_use';
    }
  }

  static PostFocusPoint fromJsonKey(String? raw) {
    switch (raw) {
      case 'cost_performance':
        return PostFocusPoint.costPerformance;
      case 'convenience':
        return PostFocusPoint.convenience;
      case 'reviews':
        return PostFocusPoint.reviews;
      case 'design':
        return PostFocusPoint.design;
      case 'cute':
        return PostFocusPoint.cute;
      case 'gift':
        return PostFocusPoint.gift;
      case 'parenting':
        return PostFocusPoint.parenting;
      case 'daily_use':
        return PostFocusPoint.dailyUse;
      default:
        return PostFocusPoint.costPerformance;
    }
  }
}

/// 想定読者層。
enum PostTargetAudience {
  general,
  women,
  men,
  parents,
  singleLife,
  roomBeginner;

  String toJsonKey() {
    switch (this) {
      case PostTargetAudience.general:
        return 'general';
      case PostTargetAudience.women:
        return 'women';
      case PostTargetAudience.men:
        return 'men';
      case PostTargetAudience.parents:
        return 'parents';
      case PostTargetAudience.singleLife:
        return 'single_life';
      case PostTargetAudience.roomBeginner:
        return 'room_beginner';
    }
  }

  static PostTargetAudience fromJsonKey(String? raw) {
    switch (raw) {
      case 'women':
        return PostTargetAudience.women;
      case 'men':
        return PostTargetAudience.men;
      case 'parents':
        return PostTargetAudience.parents;
      case 'single_life':
        return PostTargetAudience.singleLife;
      case 'room_beginner':
        return PostTargetAudience.roomBeginner;
      case 'general':
      default:
        return PostTargetAudience.general;
    }
  }
}

/// AI投稿文生成時の長さ・トークン上限。
class PostGenerationLimits {
  const PostGenerationLimits({
    required this.minBodyChars,
    required this.maxBodyChars,
    required this.targetLengthChars,
    required this.maxHashtags,
    required this.maxOutputTokens,
    required this.maxTotalChars,
  });

  final int minBodyChars;
  final int maxBodyChars;
  final int targetLengthChars;
  final int maxHashtags;
  final int maxOutputTokens;
  final int maxTotalChars;
}

/// 投稿文の書き方設定（[UserProfile.postStyles] とは別概念）。
class PostStyleSettings {
  const PostStyleSettings({
    required this.tone,
    required this.length,
    required this.emojiLevel,
    required this.kaomojiEnabled,
    required this.hashtagLevel,
    required this.focusPoints,
    required this.targetAudience,
    required this.avoidOverstatement,
    required this.updatedAt,
  });

  final PostTone tone;
  final PostLength length;
  final EmojiLevel emojiLevel;
  final bool kaomojiEnabled;
  final HashtagLevel hashtagLevel;
  final List<PostFocusPoint> focusPoints;
  final PostTargetAudience targetAudience;
  final bool avoidOverstatement;
  final DateTime updatedAt;

  static PostStyleSettings defaults() {
    return PostStyleSettings(
      tone: PostTone.friendlyPolite,
      length: PostLength.standard,
      emojiLevel: EmojiLevel.low,
      kaomojiEnabled: false,
      hashtagLevel: HashtagLevel.standard,
      focusPoints: const [
        PostFocusPoint.costPerformance,
        PostFocusPoint.dailyUse,
      ],
      targetAudience: PostTargetAudience.general,
      avoidOverstatement: true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  int get targetLengthChars {
    switch (length) {
      case PostLength.short:
        return 80;
      case PostLength.standard:
        return 120;
      case PostLength.detailed:
        return 180;
    }
  }

  int get minBodyChars {
    switch (length) {
      case PostLength.short:
        return 60;
      case PostLength.standard:
        return 100;
      case PostLength.detailed:
        return 160;
    }
  }

  int get maxBodyChars {
    switch (length) {
      case PostLength.short:
        return 90;
      case PostLength.standard:
        return 140;
      case PostLength.detailed:
        return 220;
    }
  }

  int get hashtagCount {
    switch (hashtagLevel) {
      case HashtagLevel.none:
        return 0;
      case HashtagLevel.few:
        return 3;
      case HashtagLevel.standard:
        return 5;
    }
  }

  PostGenerationLimits get generationLimits {
    final maxOutputTokens = switch (length) {
      PostLength.short => 120,
      PostLength.standard => 180,
      PostLength.detailed => 260,
    };
    final maxTotalChars = switch (length) {
      PostLength.short => 160,
      PostLength.standard => 220,
      PostLength.detailed => 320,
    };
    return PostGenerationLimits(
      minBodyChars: minBodyChars,
      maxBodyChars: maxBodyChars,
      targetLengthChars: targetLengthChars,
      maxHashtags: hashtagCount,
      maxOutputTokens: maxOutputTokens,
      maxTotalChars: maxTotalChars,
    );
  }

  PostStyleSettings copyWith({
    PostTone? tone,
    PostLength? length,
    EmojiLevel? emojiLevel,
    bool? kaomojiEnabled,
    HashtagLevel? hashtagLevel,
    List<PostFocusPoint>? focusPoints,
    PostTargetAudience? targetAudience,
    bool? avoidOverstatement,
    DateTime? updatedAt,
  }) {
    return PostStyleSettings(
      tone: tone ?? this.tone,
      length: length ?? this.length,
      emojiLevel: emojiLevel ?? this.emojiLevel,
      kaomojiEnabled: kaomojiEnabled ?? this.kaomojiEnabled,
      hashtagLevel: hashtagLevel ?? this.hashtagLevel,
      focusPoints: focusPoints ?? this.focusPoints,
      targetAudience: targetAudience ?? this.targetAudience,
      avoidOverstatement: avoidOverstatement ?? this.avoidOverstatement,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tone': tone.toJsonKey(),
      'length': length.toJsonKey(),
      'emoji_level': emojiLevel.toJsonKey(),
      'kaomoji_enabled': kaomojiEnabled,
      'hashtag_level': hashtagLevel.toJsonKey(),
      'focus_points': focusPoints.map((e) => e.toJsonKey()).toList(),
      'target_audience': targetAudience.toJsonKey(),
      'avoid_overstatement': avoidOverstatement,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static PostStyleSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults();
    return PostStyleSettings(
      tone: PostTone.fromJsonKey(json['tone'] as String?),
      length: PostLength.fromJsonKey(json['length'] as String?),
      emojiLevel: EmojiLevel.fromJsonKey(json['emoji_level'] as String?),
      kaomojiEnabled: json['kaomoji_enabled'] as bool? ?? false,
      hashtagLevel: HashtagLevel.fromJsonKey(json['hashtag_level'] as String?),
      focusPoints: _focusPointsFromJson(json['focus_points']),
      targetAudience: PostTargetAudience.fromJsonKey(
        json['target_audience'] as String?,
      ),
      avoidOverstatement: json['avoid_overstatement'] as bool? ?? true,
      updatedAt: _parseUpdatedAt(json['updated_at']),
    );
  }

  static List<PostFocusPoint> _focusPointsFromJson(dynamic raw) {
    if (raw is! List) {
      return defaults().focusPoints;
    }
    final points = raw
        .map((e) => PostFocusPoint.fromJsonKey(e?.toString()))
        .toList();
    if (points.isEmpty) return defaults().focusPoints;
    return points;
  }

  static DateTime _parseUpdatedAt(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    try {
      return DateTime.parse(raw.toString()).toUtc();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
  }
}
