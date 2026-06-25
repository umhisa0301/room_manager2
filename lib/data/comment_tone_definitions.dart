/// コメント文体定義（診断Q4）。
class CommentToneDefinition {
  const CommentToneDefinition({
    required this.id,
    required this.displayName,
    required this.promptHint,
  });

  final String id;
  final String displayName;
  final String promptHint;
}

abstract final class CommentToneDefinitions {
  CommentToneDefinitions._();

  static const softNatural = CommentToneDefinition(
    id: 'soft_natural',
    displayName: 'やわらかく自然に',
    promptHint: 'やわらかく自然な口調で、押し付けがましくない紹介文にしてください。',
  );

  static const practicalClear = CommentToneDefinition(
    id: 'practical_clear',
    displayName: '具体的にわかりやすく',
    promptHint: '具体的でわかりやすい表現を使い、使いどころが伝わる紹介文にしてください。',
  );

  static const cheerfulRecommend = CommentToneDefinition(
    id: 'cheerful_recommend',
    displayName: '明るくおすすめ感を出す',
    promptHint: '明るく前向きなトーンで、おすすめ感が伝わる紹介文にしてください。',
  );

  static const politeSuggestive = CommentToneDefinition(
    id: 'polite_suggestive',
    displayName: '丁寧に紹介する',
    promptHint: '丁寧で落ち着いた文体で、信頼感のある紹介文にしてください。',
  );

  static const List<CommentToneDefinition> all = [
    softNatural,
    practicalClear,
    cheerfulRecommend,
    politeSuggestive,
  ];

  static CommentToneDefinition? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static String displayNameFor(String id) => byId(id)?.displayName ?? id;
}
