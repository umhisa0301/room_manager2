import '../config/product_catalog_config.dart';
import '../utils/catalog_product_keys.dart';
import '../utils/catalog_product_quality.dart';

/// 商品カタログの取得元。
enum CatalogProductSource {
  search,
  todayRecommendation,
  roomImport,
  roomEnrich,
  shopDiscovery,
  initialSetup,
  urlLookup,
  unknown,
}

/// 取得元の信頼度（upsert 時の上書き優先度）。
enum CatalogProductSourceTrust {
  high,
  medium,
  low,
}

/// カタログ商品の品質スナップショット（API 由来の事実に対する判定）。
class CatalogProductQualityStatus {
  const CatalogProductQualityStatus({
    required this.hasImage,
    required this.hasPrice,
    required this.hasValidUrl,
    required this.safe,
    this.blockedReason = '',
  });

  final bool hasImage;
  final bool hasPrice;
  final bool hasValidUrl;
  final bool safe;
  final String blockedReason;

  Map<String, dynamic> toJson() => {
    'hasImage': hasImage,
    'hasPrice': hasPrice,
    'hasValidUrl': hasValidUrl,
    'safe': safe,
    'blockedReason': blockedReason,
  };

  static CatalogProductQualityStatus? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CatalogProductQualityStatus(
      hasImage: json['hasImage'] == true,
      hasPrice: json['hasPrice'] == true,
      hasValidUrl: json['hasValidUrl'] == true,
      safe: json['safe'] == true,
      blockedReason: (json['blockedReason'] as String?) ?? '',
    );
  }
}

/// API 由来の商品事実（ユーザー操作状態は持たない）。
class CatalogProduct {
  const CatalogProduct({
    required this.canonicalId,
    required this.productId,
    required this.itemCode,
    required this.itemUrl,
    required this.normalizedItemUrl,
    required this.itemName,
    required this.itemPrice,
    required this.imageUrl,
    required this.shopCode,
    required this.shopName,
    required this.shopUrl,
    required this.genreId,
    required this.genreName,
    required this.reviewAverage,
    required this.reviewCount,
    required this.affiliateUrl,
    required this.itemCaption,
    required this.source,
    required this.sourceTrust,
    required this.fetchedAt,
    required this.lastValidatedAt,
    required this.lastAccessedAt,
    required this.qualityStatus,
    required this.aliases,
    required this.cacheTtlSeconds,
  });

  final String canonicalId;
  final String productId;
  final String itemCode;
  final String itemUrl;
  final String normalizedItemUrl;
  final String itemName;
  final int itemPrice;
  final String imageUrl;
  final String shopCode;
  final String shopName;
  final String shopUrl;
  final String genreId;
  final String genreName;
  final double reviewAverage;
  final int reviewCount;
  final String affiliateUrl;
  final String itemCaption;
  final CatalogProductSource source;
  final CatalogProductSourceTrust sourceTrust;
  final DateTime fetchedAt;
  final DateTime lastValidatedAt;
  final DateTime lastAccessedAt;
  final CatalogProductQualityStatus qualityStatus;
  final List<String> aliases;
  final int cacheTtlSeconds;

  Map<String, dynamic> toJson() => {
    'canonicalId': canonicalId,
    'productId': productId,
    'itemCode': itemCode,
    'itemUrl': itemUrl,
    'normalizedItemUrl': normalizedItemUrl,
    'itemName': itemName,
    'itemPrice': itemPrice,
    'imageUrl': imageUrl,
    'shopCode': shopCode,
    'shopName': shopName,
    'shopUrl': shopUrl,
    'genreId': genreId,
    'genreName': genreName,
    'reviewAverage': reviewAverage,
    'reviewCount': reviewCount,
    'affiliateUrl': affiliateUrl,
    'itemCaption': itemCaption,
    'source': source.name,
    'sourceTrust': sourceTrust.name,
    'fetchedAt': fetchedAt.toIso8601String(),
    'lastValidatedAt': lastValidatedAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'qualityStatus': qualityStatus.toJson(),
    'aliases': aliases,
    'cacheTtlSeconds': cacheTtlSeconds,
  };

  static CatalogProduct? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final sourceRaw = json['source'] as String? ?? 'unknown';
      final trustRaw = json['sourceTrust'] as String? ?? 'medium';
      final quality = CatalogProductQualityStatus.fromJson(
        json['qualityStatus'] is Map<String, dynamic>
            ? json['qualityStatus'] as Map<String, dynamic>
            : null,
      );
      if (quality == null) return null;

      final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
      final lastValidatedAt =
          DateTime.tryParse(json['lastValidatedAt'] as String? ?? '');
      final lastAccessedAt =
          DateTime.tryParse(json['lastAccessedAt'] as String? ?? '');
      if (fetchedAt == null || lastValidatedAt == null || lastAccessedAt == null) {
        return null;
      }

      final aliasesRaw = json['aliases'];
      final aliases = aliasesRaw is List
          ? aliasesRaw.map((e) => e.toString()).toList(growable: false)
          : const <String>[];

      return CatalogProduct(
        canonicalId: (json['canonicalId'] as String?) ?? '',
        productId: (json['productId'] as String?) ?? '',
        itemCode: (json['itemCode'] as String?) ?? '',
        itemUrl: (json['itemUrl'] as String?) ?? '',
        normalizedItemUrl: (json['normalizedItemUrl'] as String?) ?? '',
        itemName: (json['itemName'] as String?) ?? '',
        itemPrice: (json['itemPrice'] as num?)?.toInt() ?? 0,
        imageUrl: (json['imageUrl'] as String?) ?? '',
        shopCode: (json['shopCode'] as String?) ?? '',
        shopName: (json['shopName'] as String?) ?? '',
        shopUrl: (json['shopUrl'] as String?) ?? '',
        genreId: (json['genreId'] as String?) ?? '',
        genreName: (json['genreName'] as String?) ?? '',
        reviewAverage: (json['reviewAverage'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        affiliateUrl: (json['affiliateUrl'] as String?) ?? '',
        itemCaption: (json['itemCaption'] as String?) ?? '',
        source: CatalogProductSource.values.firstWhere(
          (e) => e.name == sourceRaw,
          orElse: () => CatalogProductSource.unknown,
        ),
        sourceTrust: CatalogProductSourceTrust.values.firstWhere(
          (e) => e.name == trustRaw,
          orElse: () => CatalogProductSourceTrust.medium,
        ),
        fetchedAt: fetchedAt,
        lastValidatedAt: lastValidatedAt,
        lastAccessedAt: lastAccessedAt,
        qualityStatus: quality,
        aliases: aliases,
        cacheTtlSeconds:
            (json['cacheTtlSeconds'] as num?)?.toInt() ??
            ProductCatalogConfig.defaultProductCacheTtlSeconds,
      );
    } catch (_) {
      return null;
    }
  }

  CatalogProduct copyWith({
    String? canonicalId,
    String? productId,
    String? itemCode,
    String? itemUrl,
    String? normalizedItemUrl,
    String? itemName,
    int? itemPrice,
    String? imageUrl,
    String? shopCode,
    String? shopName,
    String? shopUrl,
    String? genreId,
    String? genreName,
    double? reviewAverage,
    int? reviewCount,
    String? affiliateUrl,
    String? itemCaption,
    CatalogProductSource? source,
    CatalogProductSourceTrust? sourceTrust,
    DateTime? fetchedAt,
    DateTime? lastValidatedAt,
    DateTime? lastAccessedAt,
    CatalogProductQualityStatus? qualityStatus,
    List<String>? aliases,
    int? cacheTtlSeconds,
  }) {
    return CatalogProduct(
      canonicalId: canonicalId ?? this.canonicalId,
      productId: productId ?? this.productId,
      itemCode: itemCode ?? this.itemCode,
      itemUrl: itemUrl ?? this.itemUrl,
      normalizedItemUrl: normalizedItemUrl ?? this.normalizedItemUrl,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      shopCode: shopCode ?? this.shopCode,
      shopName: shopName ?? this.shopName,
      shopUrl: shopUrl ?? this.shopUrl,
      genreId: genreId ?? this.genreId,
      genreName: genreName ?? this.genreName,
      reviewAverage: reviewAverage ?? this.reviewAverage,
      reviewCount: reviewCount ?? this.reviewCount,
      affiliateUrl: affiliateUrl ?? this.affiliateUrl,
      itemCaption: itemCaption ?? this.itemCaption,
      source: source ?? this.source,
      sourceTrust: sourceTrust ?? this.sourceTrust,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      aliases: aliases ?? this.aliases,
      cacheTtlSeconds: cacheTtlSeconds ?? this.cacheTtlSeconds,
    );
  }

  /// 別取得元の商品事実をマージ（sourceTrust ルール適用）。
  CatalogProduct mergeFrom(CatalogProduct incoming) {
    final mergedAliases = CatalogProductKeys.mergeAliases(aliases, incoming.aliases);
    return copyWith(
      productId: _mergeOptionalString(productId, incoming.productId, incoming.sourceTrust),
      itemCode: _mergeOptionalString(itemCode, incoming.itemCode, incoming.sourceTrust),
      itemUrl: _mergeImportantString(itemUrl, incoming.itemUrl, incoming.sourceTrust),
      normalizedItemUrl: _mergeOptionalString(
        normalizedItemUrl,
        incoming.normalizedItemUrl,
        incoming.sourceTrust,
      ),
      itemName: _mergeImportantString(itemName, incoming.itemName, incoming.sourceTrust),
      itemPrice: _mergeImportantInt(itemPrice, incoming.itemPrice, incoming.sourceTrust),
      imageUrl: _mergeImportantString(imageUrl, incoming.imageUrl, incoming.sourceTrust),
      shopCode: _mergeImportantString(shopCode, incoming.shopCode, incoming.sourceTrust),
      shopName: _mergeImportantString(shopName, incoming.shopName, incoming.sourceTrust),
      shopUrl: _mergeOptionalString(shopUrl, incoming.shopUrl, incoming.sourceTrust),
      genreId: _mergeImportantString(genreId, incoming.genreId, incoming.sourceTrust),
      genreName: _mergeImportantString(genreName, incoming.genreName, incoming.sourceTrust),
      reviewAverage: _mergeImportantDouble(
        reviewAverage,
        incoming.reviewAverage,
        incoming.sourceTrust,
      ),
      reviewCount: _mergeImportantInt(
        reviewCount,
        incoming.reviewCount,
        incoming.sourceTrust,
      ),
      affiliateUrl: _mergeOptionalString(
        affiliateUrl,
        incoming.affiliateUrl,
        incoming.sourceTrust,
      ),
      itemCaption: _mergeOptionalString(
        itemCaption,
        incoming.itemCaption,
        incoming.sourceTrust,
      ),
      source: incoming.source,
      sourceTrust: _maxTrust(sourceTrust, incoming.sourceTrust),
      lastValidatedAt: incoming.lastValidatedAt,
      lastAccessedAt: incoming.lastAccessedAt,
      qualityStatus: incoming.qualityStatus,
      aliases: mergedAliases,
      cacheTtlSeconds: incoming.cacheTtlSeconds,
    );
  }

  String _mergeOptionalString(
    String existing,
    String incoming,
    CatalogProductSourceTrust incomingTrust,
  ) {
    if (incoming.trim().isEmpty) return existing;
    if (existing.trim().isEmpty) return incoming.trim();
    if (_canOverwrite(existingTrust: sourceTrust, incomingTrust: incomingTrust)) {
      return incoming.trim();
    }
    return existing;
  }

  String _mergeImportantString(
    String existing,
    String incoming,
    CatalogProductSourceTrust incomingTrust,
  ) {
    if (incoming.trim().isEmpty) return existing;
    if (existing.trim().isEmpty) return incoming.trim();
    if (_canOverwriteImportant(existingTrust: sourceTrust, incomingTrust: incomingTrust)) {
      return incoming.trim();
    }
    return existing;
  }

  int _mergeImportantInt(
    int existing,
    int incoming,
    CatalogProductSourceTrust incomingTrust,
  ) {
    if (incoming <= 0) return existing;
    if (existing <= 0) return incoming;
    if (_canOverwriteImportant(existingTrust: sourceTrust, incomingTrust: incomingTrust)) {
      return incoming;
    }
    return existing;
  }

  double _mergeImportantDouble(
    double existing,
    double incoming,
    CatalogProductSourceTrust incomingTrust,
  ) {
    if (incoming <= 0) return existing;
    if (existing <= 0) return incoming;
    if (_canOverwriteImportant(existingTrust: sourceTrust, incomingTrust: incomingTrust)) {
      return incoming;
    }
    return existing;
  }

  static bool _canOverwrite({
    required CatalogProductSourceTrust existingTrust,
    required CatalogProductSourceTrust incomingTrust,
  }) {
    return _trustRank(incomingTrust) >= _trustRank(existingTrust);
  }

  static bool _canOverwriteImportant({
    required CatalogProductSourceTrust existingTrust,
    required CatalogProductSourceTrust incomingTrust,
  }) {
    if (incomingTrust == CatalogProductSourceTrust.low &&
        (existingTrust == CatalogProductSourceTrust.high ||
            existingTrust == CatalogProductSourceTrust.medium)) {
      return false;
    }
    return _trustRank(incomingTrust) >= _trustRank(existingTrust);
  }

  static int _trustRank(CatalogProductSourceTrust trust) => switch (trust) {
    CatalogProductSourceTrust.high => 3,
    CatalogProductSourceTrust.medium => 2,
    CatalogProductSourceTrust.low => 1,
  };

  static CatalogProductSourceTrust _maxTrust(
    CatalogProductSourceTrust a,
    CatalogProductSourceTrust b,
  ) {
    return _trustRank(a) >= _trustRank(b) ? a : b;
  }

  /// 品質判定を再計算したコピーを返す。
  CatalogProduct withRecomputedQuality() {
    return copyWith(qualityStatus: CatalogProductQuality.evaluate(this));
  }

  /// 保存可能か（canonicalId が決まっているか）。
  bool get isSavable => canonicalId.trim().isNotEmpty;
}
