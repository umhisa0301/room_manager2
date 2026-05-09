import '../models/today_recommendation.dart';
import '../models/user_profile.dart';

const int todayRecommendationTagMax = 2;

/// おすすめカード向けのラベル（最大 [todayRecommendationTagMax]）。保存形式に依存しない。
List<String> todayRecommendationUiTags(TodayRecommendationEntry entry) {
  final tags = <String>[];
  void add(String label) {
    if (tags.length >= todayRecommendationTagMax) return;
    if (label.trim().isEmpty) return;
    if (tags.contains(label)) return;
    tags.add(label);
  }

  final r = entry.reason.trim();
  if (r.contains('コメント反応あり')) add('コメント反応あり');
  if (r.contains('♡されやすい')) add('♡されやすい');
  if (r.contains('投稿しやすい')) add('投稿しやすい');
  if (r.contains('コレ履歴')) add('コレ履歴に基づく');
  if (r.contains('コレ済に近い')) add('コレ済に近い');
  if (r.contains('保存ショップ')) add('保存ショップ由来');
  if (r.contains('保存ショップから')) add('保存ショップから');
  if (r.contains('ジャンル')) add('好きなジャンルに近い');
  if (r.contains('候補にした')) add('候補に近い');
  if (r.contains('売れ筋価格')) add('売れ筋価格帯');
  if (r.contains('人気')) add('人気の候補');
  if (r.contains('新しい候補')) add('発掘候補');
  if (r.contains('発掘・トレンド')) add('発掘・トレンド');
  if (r.contains('お手頃価格')) add('買いやすい価格');
  if (r.contains('高単価候補')) add('高単価候補');
  if (r.contains('発掘枠')) add('発掘候補');

  final item = entry.item;
  if (item.reviewCount >= 80) add('レビュー多め');
  if (item.reviewAverage >= 4.2 && item.reviewCount >= 15) {
    add('高評価');
  }

  if (tags.isEmpty) {
    switch (entry.section) {
      case TodayRecommendationSection.sellable:
        add('ROOM向きの指標');
      case TodayRecommendationSection.popular:
        add('あなた向けに調整');
      case TodayRecommendationSection.fresh:
        add('新しい発見');
    }
  }

  return tags;
}

/// ホーム用の1行サマリ（おすすめの根拠を軽く）。
String? todayRecommendationHomeHintLine({
  required TodayRecommendationBundle? bundle,
  required bool isLoading,
  List<String> postStyleKeys = const [],
}) {
  if (isLoading) return null;
  final styleHint = _postStyleHint(postStyleKeys);
  if (bundle == null || bundle.entries.isEmpty) {
    return styleHint == null
        ? 'おすすめは、好きなジャンル・コレ履歴・保存ショップ・売れ筋価格帯を組み合わせて選びます。'
        : 'おすすめは、$styleHintを意識して選びます。';
  }
  final pending = bundle.entries
      .where((e) => e.decision == TodayRecommendationDecision.pending)
      .toList();
  if (pending.isEmpty) {
    return '今日の候補は整理済みです。また明日、あなた向けの候補を提案します。';
  }
  final t1 = todayRecommendationUiTags(pending.first);
  if (t1.isEmpty) {
    return '今日の候補は、プロフィールとコレ履歴に合わせて並んでいます。';
  }
  final tail = t1.take(2).join('・');
  return '先頭候補の目安：${styleHint ?? tail}';
}

String? _postStyleHint(List<String> postStyleKeys) {
  final styles = postStyleKeys.take(1).toSet();
  if (styles.isEmpty) return null;
  if (styles.contains(UserProfile.postStylePremium) &&
      (styles.contains(UserProfile.postStyleHighlyRated) ||
          styles.contains(UserProfile.postStyleReviewRich))) {
    return '高単価・レビュー多め';
  }
  if (styles.contains(UserProfile.postStyleSocial) &&
      styles.contains(UserProfile.postStyleAffordable)) {
    return '見た目で選びやすい・買いやすい価格';
  }
  return styles.map(UserProfile.postStyleLabelJa).take(1).join('・');
}
