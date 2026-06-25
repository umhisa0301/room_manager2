/// 優先条件ルール定義（表示文言・検索ワード・加点ワード・訴求軸を分離）。
class PriorityRuleDefinition {
  const PriorityRuleDefinition({
    required this.id,
    required this.displayName,
    required this.searchKeywords,
    required this.boostKeywords,
    required this.commentAngles,
    this.numericSignals = const [],
  });

  final String id;
  final String displayName;
  final List<String> searchKeywords;
  final List<String> boostKeywords;
  final List<String> commentAngles;

  /// レビュー数値など、テキスト以外のシグナル名。
  final List<String> numericSignals;
}

abstract final class PriorityRuleDefinitions {
  PriorityRuleDefinitions._();

  static const practicalLifehack = PriorityRuleDefinition(
    id: 'practical_lifehack',
    displayName: '実用性が高い・暮らしに役立つ',
    searchKeywords: [
      '便利グッズ',
      'ライフハック',
      '時短',
      '家事ラク',
      '収納術',
      '省スペース',
      'ながら',
      'ズボラ',
      '簡単',
    ],
    boostKeywords: [
      '便利',
      '時短',
      '家事ラク',
      'ライフハック',
      '収納術',
      '省スペース',
      '簡単',
      '軽量',
      '多機能',
      '毎日使える',
      '片付く',
      'すっきり',
    ],
    commentAngles: [
      '日常のちょっとした不便を減らす',
      '時短になる',
      '毎日使いやすい',
      '家事や作業が少しラクになる',
    ],
  );

  static const visualSns = PriorityRuleDefinition(
    id: 'visual_sns',
    displayName: '見た目がよい・気分が上がる',
    searchKeywords: [
      'インスタ映え',
      'SNS映え',
      '写真映え',
      '高見え',
      '淡色',
      '韓国風',
      '北欧風',
      'おしゃれ',
      'かわいい',
    ],
    boostKeywords: [
      'インスタ映え',
      'SNS映え',
      '写真映え',
      '映える',
      '高見え',
      '淡色',
      '韓国',
      '北欧',
      'ナチュラル',
      'おしゃれ',
      'かわいい',
      '大人かわいい',
      'シンプル',
    ],
    commentAngles: [
      '写真で雰囲気が伝わりやすい',
      '置くだけで気分が上がる',
      'ROOMでも紹介しやすい',
      '見た目の印象を伝えやすい',
    ],
  );

  static const reviewTrust = PriorityRuleDefinition(
    id: 'review_trust',
    displayName: 'レビューが多く安心して選べる',
    searchKeywords: [
      '高評価',
      '高レビュー',
      'レビュー高評価',
      'ランキング',
      '定番',
      'ロングセラー',
    ],
    boostKeywords: [
      '高評価',
      '高レビュー',
      'レビュー高評価',
      'ランキング',
      '定番',
      'ロングセラー',
      '口コミ',
    ],
    commentAngles: [
      'レビューを見て検討しやすい',
      '定番感がある',
      '初めてでも選びやすい',
      '安心感を持って紹介しやすい',
    ],
    numericSignals: ['reviewAverage', 'reviewCount'],
  );

  static const valueBalance = PriorityRuleDefinition(
    id: 'value_balance',
    displayName: '価格と満足感のバランスがよい',
    searchKeywords: [
      'コスパ',
      'プチプラ',
      '高見え',
      '大容量',
      'まとめ買い',
      '訳あり',
      'お試し',
      'セット',
    ],
    boostKeywords: [
      'コスパ',
      'プチプラ',
      '大容量',
      'まとめ買い',
      '訳あり',
      'お試し',
      'セット',
      '高見え',
    ],
    commentAngles: [
      '価格と満足感のバランスがよい',
      '普段使いしやすい',
      '気軽に試しやすい',
      '価格以上に見えやすい',
    ],
  );

  static const giftEvent = PriorityRuleDefinition(
    id: 'gift_event',
    displayName: 'プレゼントに使いやすい',
    searchKeywords: [
      'ギフト',
      'プレゼント',
      '手土産',
      'プチギフト',
      '誕生日',
      '内祝い',
      'お祝い',
      'ラッピング',
    ],
    boostKeywords: [
      'ギフト',
      'プレゼント',
      '贈り物',
      '手土産',
      'プチギフト',
      '誕生日',
      '内祝い',
      'お祝い',
      'ラッピング',
    ],
    commentAngles: [
      'ちょっとした贈り物に使いやすい',
      '誕生日やお礼にも選びやすい',
      '季節イベントに合わせて紹介しやすい',
      '手土産として紹介しやすい',
    ],
  );

  static const seasonalTrend = PriorityRuleDefinition(
    id: 'seasonal_trend',
    displayName: '季節感・今っぽさがある',
    searchKeywords: [
      '新生活',
      '母の日',
      '父の日',
      '敬老の日',
      '夏',
      '冬',
      '冷感',
      'あったか',
      '梅雨',
      'アウトドア',
      'お中元',
      'クリスマス',
      'バレンタイン',
    ],
    boostKeywords: [
      '新生活',
      '母の日',
      '父の日',
      '敬老の日',
      '夏',
      '冬',
      '冷感',
      'あったか',
      '梅雨',
      'お中元',
      'クリスマス',
      'バレンタイン',
    ],
    commentAngles: [
      '今の季節に取り入れやすい',
      'イベント前に紹介しやすい',
      '季節感のある投稿にしやすい',
      '今っぽい投稿テーマにしやすい',
    ],
  );

  static const List<PriorityRuleDefinition> all = [
    practicalLifehack,
    visualSns,
    reviewTrust,
    valueBalance,
    giftEvent,
    seasonalTrend,
  ];

  static PriorityRuleDefinition? byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  static String displayNameFor(String id) => byId(id)?.displayName ?? id;

  static List<String> displayNamesFor(Iterable<String> ids) =>
      ids.map(displayNameFor).where((n) => n.isNotEmpty).toList();

  /// 削除対象ワード（検索・加点に使わない）。
  static const Set<String> bannedKeywords = {'送料無料'};

  /// 汎用ワード（最大3点程度の弱加点）。
  static const Set<String> weakBoostKeywords = {
    '人気',
    'おすすめ',
    '売れ筋',
    'おしゃれ',
    'かわいい',
    '便利',
  };

  static const double weakBoostMaxPoints = 3;
}
