class SavedShop {
  const SavedShop({
    required this.shopId,
    required this.shopName,
    required this.shopUrl,
    required this.savedAt,
    this.lastViewedAt,
  });

  final String shopId;
  final String shopName;
  final String shopUrl;
  final DateTime savedAt;
  final DateTime? lastViewedAt;

  SavedShop copyWith({
    String? shopId,
    String? shopName,
    String? shopUrl,
    DateTime? savedAt,
    DateTime? lastViewedAt,
    bool clearLastViewedAt = false,
  }) {
    return SavedShop(
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      shopUrl: shopUrl ?? this.shopUrl,
      savedAt: savedAt ?? this.savedAt,
      lastViewedAt:
          clearLastViewedAt ? null : (lastViewedAt ?? this.lastViewedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'shopUrl': shopUrl,
      'savedAt': savedAt.toIso8601String(),
      'lastViewedAt': lastViewedAt?.toIso8601String(),
    };
  }

  static SavedShop? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = (json['shopId'] ?? '').toString().trim();
    final name = (json['shopName'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) return null;
    final url = (json['shopUrl'] ?? '').toString().trim();
    final savedRaw = (json['savedAt'] ?? '').toString();
    final savedAt = DateTime.tryParse(savedRaw) ?? DateTime.now();
    final viewedRaw = (json['lastViewedAt'] ?? '').toString().trim();
    final lastViewedAt = viewedRaw.isEmpty ? null : DateTime.tryParse(viewedRaw);
    return SavedShop(
      shopId: id,
      shopName: name,
      shopUrl: url,
      savedAt: savedAt,
      lastViewedAt: lastViewedAt,
    );
  }
}
