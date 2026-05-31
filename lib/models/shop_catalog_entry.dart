import '../config/shop_catalog_config.dart';
import '../utils/shop_catalog_keys.dart';

/// ショップカタログの取得元。
enum ShopCatalogSource {
  search,
  shopDiscovery,
  initialSetup,
  savedShopSearch,
  productCatalogAggregate,
  roomImport,
  unknown,
}

/// 取得元の信頼度。
enum ShopCatalogSourceTrust {
  high,
  medium,
  low,
}

/// カタログショップの品質スナップショット。
class ShopCatalogQualityStatus {
  const ShopCatalogQualityStatus({
    required this.hasRepresentativeImage,
    required this.hasShopUrl,
    required this.hasPrimaryGenre,
    required this.safe,
    this.blockedReason = '',
  });

  final bool hasRepresentativeImage;
  final bool hasShopUrl;
  final bool hasPrimaryGenre;
  final bool safe;
  final String blockedReason;

  Map<String, dynamic> toJson() => {
    'hasRepresentativeImage': hasRepresentativeImage,
    'hasShopUrl': hasShopUrl,
    'hasPrimaryGenre': hasPrimaryGenre,
    'safe': safe,
    'blockedReason': blockedReason,
  };

  static ShopCatalogQualityStatus? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ShopCatalogQualityStatus(
      hasRepresentativeImage: json['hasRepresentativeImage'] == true,
      hasShopUrl: json['hasShopUrl'] == true,
      hasPrimaryGenre: json['hasPrimaryGenre'] == true,
      safe: json['safe'] == true,
      blockedReason: (json['blockedReason'] as String?) ?? '',
    );
  }
}

/// API / カタログ集計由来のショップ事実（保存状態・ユーザー反応は持たない）。
class ShopCatalogEntry {
  const ShopCatalogEntry({
    required this.shopCode,
    required this.shopName,
    required this.shopUrl,
    required this.representativeImageUrl,
    required this.primaryGenreId,
    required this.primaryGenreName,
    required this.genreIds,
    required this.genreNames,
    required this.itemCountInCatalog,
    required this.safeItemCount,
    required this.itemsWithImage,
    required this.itemsWithPrice,
    required this.averageReviewAverage,
    required this.maxReviewCount,
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.source,
    required this.sourceTrust,
    required this.lastFetchedAt,
    required this.lastValidatedAt,
    required this.lastAccessedAt,
    required this.cacheTtlSeconds,
    required this.qualityStatus,
    required this.aliases,
    required this.sampleProductIds,
  });

  final String shopCode;
  final String shopName;
  final String shopUrl;
  final String representativeImageUrl;
  final String primaryGenreId;
  final String primaryGenreName;
  final List<String> genreIds;
  final List<String> genreNames;
  final int itemCountInCatalog;
  final int safeItemCount;
  final int itemsWithImage;
  final int itemsWithPrice;
  final double averageReviewAverage;
  final int maxReviewCount;
  final double averagePrice;
  final int minPrice;
  final int maxPrice;
  final ShopCatalogSource source;
  final ShopCatalogSourceTrust sourceTrust;
  final DateTime lastFetchedAt;
  final DateTime lastValidatedAt;
  final DateTime lastAccessedAt;
  final int cacheTtlSeconds;
  final ShopCatalogQualityStatus qualityStatus;
  final List<String> aliases;
  final List<String> sampleProductIds;

  Map<String, dynamic> toJson() => {
    'shopCode': shopCode,
    'shopName': shopName,
    'shopUrl': shopUrl,
    'representativeImageUrl': representativeImageUrl,
    'primaryGenreId': primaryGenreId,
    'primaryGenreName': primaryGenreName,
    'genreIds': genreIds,
    'genreNames': genreNames,
    'itemCountInCatalog': itemCountInCatalog,
    'safeItemCount': safeItemCount,
    'itemsWithImage': itemsWithImage,
    'itemsWithPrice': itemsWithPrice,
    'averageReviewAverage': averageReviewAverage,
    'maxReviewCount': maxReviewCount,
    'averagePrice': averagePrice,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'source': source.name,
    'sourceTrust': sourceTrust.name,
    'lastFetchedAt': lastFetchedAt.toIso8601String(),
    'lastValidatedAt': lastValidatedAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'cacheTtlSeconds': cacheTtlSeconds,
    'qualityStatus': qualityStatus.toJson(),
    'aliases': aliases,
    'sampleProductIds': sampleProductIds,
  };

  static ShopCatalogEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      if (json.containsKey('savedStatus') || json.containsKey('savedAt')) {
        return null;
      }
      final sourceRaw = json['source'] as String? ?? 'unknown';
      final trustRaw = json['sourceTrust'] as String? ?? 'medium';
      final quality = ShopCatalogQualityStatus.fromJson(
        json['qualityStatus'] is Map<String, dynamic>
            ? json['qualityStatus'] as Map<String, dynamic>
            : null,
      );
      if (quality == null) return null;

      final lastFetchedAt =
          DateTime.tryParse(json['lastFetchedAt'] as String? ?? '');
      final lastValidatedAt =
          DateTime.tryParse(json['lastValidatedAt'] as String? ?? '');
      final lastAccessedAt =
          DateTime.tryParse(json['lastAccessedAt'] as String? ?? '');
      if (lastFetchedAt == null ||
          lastValidatedAt == null ||
          lastAccessedAt == null) {
        return null;
      }

      final genreIdsRaw = json['genreIds'];
      final genreNamesRaw = json['genreNames'];
      final aliasesRaw = json['aliases'];
      final sampleRaw = json['sampleProductIds'];

      return ShopCatalogEntry(
        shopCode: (json['shopCode'] as String?) ?? '',
        shopName: (json['shopName'] as String?) ?? '',
        shopUrl: (json['shopUrl'] as String?) ?? '',
        representativeImageUrl:
            (json['representativeImageUrl'] as String?) ?? '',
        primaryGenreId: (json['primaryGenreId'] as String?) ?? '',
        primaryGenreName: (json['primaryGenreName'] as String?) ?? '',
        genreIds: genreIdsRaw is List
            ? genreIdsRaw.map((e) => e.toString()).toList(growable: false)
            : const <String>[],
        genreNames: genreNamesRaw is List
            ? genreNamesRaw.map((e) => e.toString()).toList(growable: false)
            : const <String>[],
        itemCountInCatalog:
            (json['itemCountInCatalog'] as num?)?.toInt() ?? 0,
        safeItemCount: (json['safeItemCount'] as num?)?.toInt() ?? 0,
        itemsWithImage: (json['itemsWithImage'] as num?)?.toInt() ?? 0,
        itemsWithPrice: (json['itemsWithPrice'] as num?)?.toInt() ?? 0,
        averageReviewAverage:
            (json['averageReviewAverage'] as num?)?.toDouble() ?? 0,
        maxReviewCount: (json['maxReviewCount'] as num?)?.toInt() ?? 0,
        averagePrice: (json['averagePrice'] as num?)?.toDouble() ?? 0,
        minPrice: (json['minPrice'] as num?)?.toInt() ?? 0,
        maxPrice: (json['maxPrice'] as num?)?.toInt() ?? 0,
        source: ShopCatalogSource.values.firstWhere(
          (e) => e.name == sourceRaw,
          orElse: () => ShopCatalogSource.unknown,
        ),
        sourceTrust: ShopCatalogSourceTrust.values.firstWhere(
          (e) => e.name == trustRaw,
          orElse: () => ShopCatalogSourceTrust.medium,
        ),
        lastFetchedAt: lastFetchedAt,
        lastValidatedAt: lastValidatedAt,
        lastAccessedAt: lastAccessedAt,
        cacheTtlSeconds:
            (json['cacheTtlSeconds'] as num?)?.toInt() ??
            ShopCatalogConfig.defaultShopCatalogTtlSeconds,
        qualityStatus: quality,
        aliases: aliasesRaw is List
            ? aliasesRaw.map((e) => e.toString()).toList(growable: false)
            : const <String>[],
        sampleProductIds: sampleRaw is List
            ? sampleRaw.map((e) => e.toString()).toList(growable: false)
            : const <String>[],
      );
    } catch (_) {
      return null;
    }
  }

  ShopCatalogEntry copyWith({
    String? shopCode,
    String? shopName,
    String? shopUrl,
    String? representativeImageUrl,
    String? primaryGenreId,
    String? primaryGenreName,
    List<String>? genreIds,
    List<String>? genreNames,
    int? itemCountInCatalog,
    int? safeItemCount,
    int? itemsWithImage,
    int? itemsWithPrice,
    double? averageReviewAverage,
    int? maxReviewCount,
    double? averagePrice,
    int? minPrice,
    int? maxPrice,
    ShopCatalogSource? source,
    ShopCatalogSourceTrust? sourceTrust,
    DateTime? lastFetchedAt,
    DateTime? lastValidatedAt,
    DateTime? lastAccessedAt,
    int? cacheTtlSeconds,
    ShopCatalogQualityStatus? qualityStatus,
    List<String>? aliases,
    List<String>? sampleProductIds,
  }) {
    return ShopCatalogEntry(
      shopCode: shopCode ?? this.shopCode,
      shopName: shopName ?? this.shopName,
      shopUrl: shopUrl ?? this.shopUrl,
      representativeImageUrl:
          representativeImageUrl ?? this.representativeImageUrl,
      primaryGenreId: primaryGenreId ?? this.primaryGenreId,
      primaryGenreName: primaryGenreName ?? this.primaryGenreName,
      genreIds: genreIds ?? this.genreIds,
      genreNames: genreNames ?? this.genreNames,
      itemCountInCatalog: itemCountInCatalog ?? this.itemCountInCatalog,
      safeItemCount: safeItemCount ?? this.safeItemCount,
      itemsWithImage: itemsWithImage ?? this.itemsWithImage,
      itemsWithPrice: itemsWithPrice ?? this.itemsWithPrice,
      averageReviewAverage:
          averageReviewAverage ?? this.averageReviewAverage,
      maxReviewCount: maxReviewCount ?? this.maxReviewCount,
      averagePrice: averagePrice ?? this.averagePrice,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      source: source ?? this.source,
      sourceTrust: sourceTrust ?? this.sourceTrust,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      cacheTtlSeconds: cacheTtlSeconds ?? this.cacheTtlSeconds,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      aliases: aliases ?? this.aliases,
      sampleProductIds: sampleProductIds ?? this.sampleProductIds,
    );
  }

  ShopCatalogEntry mergeFrom(ShopCatalogEntry incoming) {
    final mergedAliases = ShopCatalogKeys.mergeAliases(aliases, incoming.aliases);
    return copyWith(
      shopName: _mergeImportantString(
        shopName,
        incoming.shopName,
        incoming.sourceTrust,
      ),
      shopUrl: _mergeOptionalString(
        shopUrl,
        incoming.shopUrl,
        incoming.sourceTrust,
      ),
      representativeImageUrl: _mergeImportantString(
        representativeImageUrl,
        incoming.representativeImageUrl,
        incoming.sourceTrust,
      ),
      primaryGenreId: _mergeImportantString(
        primaryGenreId,
        incoming.primaryGenreId,
        incoming.sourceTrust,
      ),
      primaryGenreName: _mergeImportantString(
        primaryGenreName,
        incoming.primaryGenreName,
        incoming.sourceTrust,
      ),
      genreIds: incoming.genreIds.isNotEmpty ? incoming.genreIds : genreIds,
      genreNames:
          incoming.genreNames.isNotEmpty ? incoming.genreNames : genreNames,
      itemCountInCatalog: incoming.itemCountInCatalog > itemCountInCatalog
          ? incoming.itemCountInCatalog
          : itemCountInCatalog,
      safeItemCount: incoming.safeItemCount > safeItemCount
          ? incoming.safeItemCount
          : safeItemCount,
      itemsWithImage: incoming.itemsWithImage > itemsWithImage
          ? incoming.itemsWithImage
          : itemsWithImage,
      itemsWithPrice: incoming.itemsWithPrice > itemsWithPrice
          ? incoming.itemsWithPrice
          : itemsWithPrice,
      averageReviewAverage: incoming.averageReviewAverage > 0
          ? incoming.averageReviewAverage
          : averageReviewAverage,
      maxReviewCount: incoming.maxReviewCount > maxReviewCount
          ? incoming.maxReviewCount
          : maxReviewCount,
      averagePrice: incoming.averagePrice > 0
          ? incoming.averagePrice
          : averagePrice,
      minPrice: incoming.minPrice > 0 && (minPrice <= 0 || incoming.minPrice < minPrice)
          ? incoming.minPrice
          : minPrice,
      maxPrice: incoming.maxPrice > maxPrice ? incoming.maxPrice : maxPrice,
      source: incoming.source,
      sourceTrust: _maxTrust(sourceTrust, incoming.sourceTrust),
      lastValidatedAt: incoming.lastValidatedAt,
      lastAccessedAt: incoming.lastAccessedAt,
      qualityStatus: incoming.qualityStatus,
      aliases: mergedAliases,
      sampleProductIds: incoming.sampleProductIds.isNotEmpty
          ? incoming.sampleProductIds
          : sampleProductIds,
    );
  }

  String _mergeOptionalString(
    String existing,
    String incoming,
    ShopCatalogSourceTrust incomingTrust,
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
    ShopCatalogSourceTrust incomingTrust,
  ) {
    if (incoming.trim().isEmpty) return existing;
    if (existing.trim().isEmpty) return incoming.trim();
    if (_canOverwriteImportant(
      existingTrust: sourceTrust,
      incomingTrust: incomingTrust,
    )) {
      return incoming.trim();
    }
    return existing;
  }

  static bool _canOverwrite({
    required ShopCatalogSourceTrust existingTrust,
    required ShopCatalogSourceTrust incomingTrust,
  }) {
    return _trustRank(incomingTrust) >= _trustRank(existingTrust);
  }

  static bool _canOverwriteImportant({
    required ShopCatalogSourceTrust existingTrust,
    required ShopCatalogSourceTrust incomingTrust,
  }) {
    if (incomingTrust == ShopCatalogSourceTrust.low &&
        (existingTrust == ShopCatalogSourceTrust.high ||
            existingTrust == ShopCatalogSourceTrust.medium)) {
      return false;
    }
    return _trustRank(incomingTrust) >= _trustRank(existingTrust);
  }

  static int _trustRank(ShopCatalogSourceTrust trust) => switch (trust) {
    ShopCatalogSourceTrust.high => 3,
    ShopCatalogSourceTrust.medium => 2,
    ShopCatalogSourceTrust.low => 1,
  };

  static ShopCatalogSourceTrust _maxTrust(
    ShopCatalogSourceTrust a,
    ShopCatalogSourceTrust b,
  ) {
    return _trustRank(a) >= _trustRank(b) ? a : b;
  }

  bool get isSavable => ShopCatalogKeys.normalizeShopCode(shopCode) != null;
}
