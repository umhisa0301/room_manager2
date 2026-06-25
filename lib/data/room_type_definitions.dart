/// ROOMタイプ定義（V1: 4タイプ）。
class RoomTypeDefinition {
  const RoomTypeDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.searchDirectionKeywords,
  });

  final String id;
  final String displayName;
  final String description;

  /// 検索クエリ生成時の基本方向キーワード。
  final List<String> searchDirectionKeywords;
}

abstract final class RoomTypeDefinitions {
  RoomTypeDefinitions._();

  static const lifeConvenience = RoomTypeDefinition(
    id: 'life_convenience',
    displayName: '暮らし便利型',
    description: '時短、家事ラク、収納、日用品など、毎日の生活を少しラクにする商品と相性が良いタイプ。',
    searchDirectionKeywords: ['時短', '家事ラク', '収納', '日用品', '便利'],
  );

  static const visualMood = RoomTypeDefinition(
    id: 'visual_mood',
    displayName: 'おしゃれ・気分上げ型',
    description: '見た目、雰囲気、美容、ファッション、雑貨など、気分が上がる商品と相性が良いタイプ。',
    searchDirectionKeywords: ['おしゃれ', '雑貨', 'インテリア', '美容', 'コスメ'],
  );

  static const valueBalance = RoomTypeDefinition(
    id: 'value_balance',
    displayName: 'コスパ・お得型',
    description: '価格と満足感のバランス、高評価、まとめ買い、プチプラなどを紹介しやすいタイプ。',
    searchDirectionKeywords: ['コスパ', 'プチプラ', '高評価', 'まとめ買い'],
  );

  static const giftEvent = RoomTypeDefinition(
    id: 'gift_event',
    displayName: 'ギフト・イベント型',
    description: 'プレゼント、手土産、季節行事、誕生日、内祝いなど、贈り物やイベント向けの商品と相性が良いタイプ。',
    searchDirectionKeywords: ['ギフト', 'プレゼント', '手土産', 'お祝い'],
  );

  static const List<RoomTypeDefinition> all = [
    lifeConvenience,
    visualMood,
    valueBalance,
    giftEvent,
  ];

  static RoomTypeDefinition? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static String displayNameFor(String id) => byId(id)?.displayName ?? id;
}
