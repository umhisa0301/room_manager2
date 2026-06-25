/// アプリ独自の関心カテゴリ（楽天ジャンルIDは露出しない）。
class InterestCategoryDefinition {
  const InterestCategoryDefinition({
    required this.id,
    required this.displayName,
    required this.searchTerms,
  });

  final String id;
  final String displayName;

  /// 検索クエリ生成・スコアリング用の表現語。
  final List<String> searchTerms;
}

abstract final class InterestCategoryDefinitions {
  InterestCategoryDefinitions._();

  static const kitchen = InterestCategoryDefinition(
    id: 'kitchen',
    displayName: 'キッチン',
    searchTerms: ['キッチン', '調理', '食器'],
  );

  static const storageInterior = InterestCategoryDefinition(
    id: 'storage_interior',
    displayName: '収納・インテリア',
    searchTerms: ['収納', 'インテリア', '収納術', 'クローゼット'],
  );

  static const cleaningLaundry = InterestCategoryDefinition(
    id: 'cleaning_laundry',
    displayName: '掃除・洗濯',
    searchTerms: ['掃除', '洗濯', 'クリーニング'],
  );

  static const beautyCosme = InterestCategoryDefinition(
    id: 'beauty_cosme',
    displayName: '美容・コスメ',
    searchTerms: ['美容', 'コスメ', 'スキンケア'],
  );

  static const fashion = InterestCategoryDefinition(
    id: 'fashion',
    displayName: 'ファッション',
    searchTerms: ['ファッション', 'アクセサリー', '服'],
  );

  static const foodSweets = InterestCategoryDefinition(
    id: 'food_sweets',
    displayName: '食品・スイーツ',
    searchTerms: ['食品', 'スイーツ', 'お菓子'],
  );

  static const gadgetAppliance = InterestCategoryDefinition(
    id: 'gadget_appliance',
    displayName: '家電・ガジェット',
    searchTerms: ['家電', 'ガジェット', '家電小物'],
  );

  static const babyKids = InterestCategoryDefinition(
    id: 'baby_kids',
    displayName: 'ベビー・キッズ',
    searchTerms: ['ベビー', 'キッズ', '育児'],
  );

  static const stationeryDesk = InterestCategoryDefinition(
    id: 'stationery_desk',
    displayName: '文房具・デスク周り',
    searchTerms: ['文房具', 'デスク', '仕事道具'],
  );

  static const pet = InterestCategoryDefinition(
    id: 'pet',
    displayName: 'ペット',
    searchTerms: ['ペット', '犬', '猫'],
  );

  static const health = InterestCategoryDefinition(
    id: 'health',
    displayName: '健康',
    searchTerms: ['健康', 'サプリ', 'ウェルネス'],
  );

  static const gift = InterestCategoryDefinition(
    id: 'gift',
    displayName: 'ギフト',
    searchTerms: ['ギフト', 'プレゼント', '雑貨'],
  );

  static const List<InterestCategoryDefinition> all = [
    kitchen,
    storageInterior,
    cleaningLaundry,
    beautyCosme,
    fashion,
    foodSweets,
    gadgetAppliance,
    babyKids,
    stationeryDesk,
    pet,
    health,
    gift,
  ];

  static InterestCategoryDefinition? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String displayNameFor(String id) => byId(id)?.displayName ?? id;

  static List<String> displayNamesFor(Iterable<String> ids) =>
      ids.map(displayNameFor).where((n) => n.isNotEmpty).toList();
}
