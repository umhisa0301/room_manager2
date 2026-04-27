import 'rakuten_search_item.dart';

enum TodayRecommendationDecision { pending, skipped, addedCandidate }

enum TodayRecommendationSection { personalized, popular, fresh }

class TodayRecommendationEntry {
  const TodayRecommendationEntry({
    required this.item,
    this.decision = TodayRecommendationDecision.pending,
    this.reason = '人気商品',
    this.section = TodayRecommendationSection.personalized,
    this.score = 0,
  });

  final RakutenSearchItem item;
  final TodayRecommendationDecision decision;
  final String reason;
  final TodayRecommendationSection section;
  final double score;

  TodayRecommendationEntry copyWith({
    RakutenSearchItem? item,
    TodayRecommendationDecision? decision,
    String? reason,
    TodayRecommendationSection? section,
    double? score,
  }) {
    return TodayRecommendationEntry(
      item: item ?? this.item,
      decision: decision ?? this.decision,
      reason: reason ?? this.reason,
      section: section ?? this.section,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': {
        'productId': item.productId,
        'itemName': item.itemName,
        'itemPrice': item.itemPrice,
        'itemUrl': item.itemUrl,
        'affiliateUrl': item.affiliateUrl,
        'imageUrl': item.imageUrl,
        'shopName': item.shopName,
        'reviewCount': item.reviewCount,
        'reviewAverage': item.reviewAverage,
        'shopCode': item.shopCode,
        'shopUrl': item.shopUrl,
        'genreId': item.genreId,
        'genreName': item.genreName,
      },
      'decision': decision.name,
      'reason': reason,
      'section': section.name,
      'score': score,
    };
  }

  static TodayRecommendationEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final itemJson = json['item'];
    if (itemJson is! Map<String, dynamic>) return null;
    final productId = (itemJson['productId'] ?? '').toString().trim();
    final itemName = (itemJson['itemName'] ?? '').toString().trim();
    final itemUrl = (itemJson['itemUrl'] ?? '').toString().trim();
    if (productId.isEmpty || itemName.isEmpty || itemUrl.isEmpty) return null;
    final decisionRaw = (json['decision'] ?? '').toString();
    final decision = TodayRecommendationDecision.values.firstWhere(
      (e) => e.name == decisionRaw,
      orElse: () => TodayRecommendationDecision.pending,
    );
    final sectionRaw = (json['section'] ?? '').toString();
    final section = TodayRecommendationSection.values.firstWhere(
      (e) => e.name == sectionRaw,
      orElse: () => TodayRecommendationSection.personalized,
    );
    return TodayRecommendationEntry(
      item: RakutenSearchItem(
        productId: productId,
        itemName: itemName,
        itemPrice: (itemJson['itemPrice'] as num?)?.toInt() ?? 0,
        itemUrl: itemUrl,
        affiliateUrl: (itemJson['affiliateUrl'] ?? '').toString(),
        imageUrl: (itemJson['imageUrl'] ?? '').toString(),
        shopName: (itemJson['shopName'] ?? '').toString(),
        reviewCount: (itemJson['reviewCount'] as num?)?.toInt() ?? 0,
        reviewAverage: (itemJson['reviewAverage'] as num?)?.toDouble() ?? 0,
        shopCode: (itemJson['shopCode'] ?? '').toString(),
        shopUrl: (itemJson['shopUrl'] ?? '').toString(),
        genreId: (itemJson['genreId'] ?? '').toString(),
        genreName: (itemJson['genreName'] ?? '').toString(),
      ),
      decision: decision,
      reason: (json['reason'] ?? '人気商品').toString(),
      section: section,
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TodayRecommendationBundle {
  const TodayRecommendationBundle({
    required this.localDateKey,
    required this.generatedAt,
    required this.entries,
  });

  final String localDateKey;
  final DateTime generatedAt;
  final List<TodayRecommendationEntry> entries;

  bool get isCompleted =>
      entries.isNotEmpty &&
      entries.every((e) => e.decision != TodayRecommendationDecision.pending);

  int get pendingCount => entries
      .where((e) => e.decision == TodayRecommendationDecision.pending)
      .length;

  Map<String, dynamic> toJson() {
    return {
      'localDateKey': localDateKey,
      'generatedAt': generatedAt.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(growable: false),
    };
  }

  static TodayRecommendationBundle? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final dateKey = (json['localDateKey'] ?? '').toString().trim();
    final generatedRaw = (json['generatedAt'] ?? '').toString().trim();
    if (dateKey.isEmpty || generatedRaw.isEmpty) return null;
    DateTime? generatedAt;
    try {
      generatedAt = DateTime.parse(generatedRaw);
    } catch (_) {
      return null;
    }
    final rawEntries = json['entries'];
    if (rawEntries is! List) return null;
    final entries = <TodayRecommendationEntry>[];
    for (final e in rawEntries) {
      if (e is Map<String, dynamic>) {
        final parsed = TodayRecommendationEntry.fromJson(e);
        if (parsed != null) entries.add(parsed);
      }
    }
    return TodayRecommendationBundle(
      localDateKey: dateKey,
      generatedAt: generatedAt,
      entries: entries,
    );
  }

  TodayRecommendationBundle copyWith({
    String? localDateKey,
    DateTime? generatedAt,
    List<TodayRecommendationEntry>? entries,
  }) {
    return TodayRecommendationBundle(
      localDateKey: localDateKey ?? this.localDateKey,
      generatedAt: generatedAt ?? this.generatedAt,
      entries: entries ?? this.entries,
    );
  }
}
