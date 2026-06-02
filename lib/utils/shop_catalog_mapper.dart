import '../config/shop_catalog_config.dart';
import '../models/shop_catalog_entry.dart';
import '../models/shop_discovery_summary.dart';
import '../repository/shop_catalog_repository.dart';
import 'app_debug_log.dart';
import 'room_import_product_image.dart';
import 'shop_catalog_keys.dart';
import 'shop_display_resolve.dart';

class ShopCatalogDiscoveryUpsertSummary {
  const ShopCatalogDiscoveryUpsertSummary({
    required this.summaries,
    required this.upserted,
    required this.skippedNoShopCode,
    required this.skippedInvalidShopName,
    required this.skippedUnsafe,
    required this.skippedInvalidShopUrl,
  });

  final int summaries;
  final int upserted;
  final int skippedNoShopCode;
  final int skippedInvalidShopName;
  final int skippedUnsafe;
  final int skippedInvalidShopUrl;
}

ShopCatalogEntry? shopCatalogEntryFromDiscoverySummary(
  ShopDiscoverySummary summary, {
  DateTime? now,
}) {
  final shopCode = summary.shopKey.trim();
  if (ShopCatalogKeys.normalizeShopCode(shopCode) == null ||
      shopCode == 'unknown') {
    return null;
  }

  final shopName = summary.shopName.trim();
  if (shopName.isEmpty ||
      shopName == ShopDisplayResolve.unknownShopLabel ||
      ShopDisplayResolve.looksLikeShopCode(shopName)) {
    return null;
  }

  final shopUrl = summary.shopUrl.trim();
  if (!_isValidShopUrl(shopUrl)) {
    return null;
  }

  final safeItemCount = summary.hitItemCount;
  if (safeItemCount <= 0) {
    return null;
  }

  final representativeImageUrl =
      _safeRepresentativeImageUrl(summary.representativeItems);

  final t = now ?? DateTime.now();
  return ShopCatalogEntry(
    shopCode: shopCode,
    shopName: shopName,
    shopUrl: shopUrl,
    representativeImageUrl: representativeImageUrl,
    primaryGenreId: '',
    primaryGenreName: '',
    genreIds: const <String>[],
    genreNames: const <String>[],
    itemCountInCatalog: summary.hitItemCount,
    safeItemCount: safeItemCount,
    itemsWithImage: representativeImageUrl.isEmpty ? 0 : 1,
    itemsWithPrice: 0,
    averageReviewAverage: summary.avgReviewAverage,
    maxReviewCount: summary.maxReviewCount,
    averagePrice: 0,
    minPrice: 0,
    maxPrice: 0,
    source: ShopCatalogSource.shopDiscovery,
    sourceTrust: ShopCatalogSourceTrust.medium,
    lastFetchedAt: t,
    lastValidatedAt: t,
    lastAccessedAt: t,
    cacheTtlSeconds: ShopCatalogConfig.defaultShopCatalogTtlSeconds,
    qualityStatus: ShopCatalogQualityStatus(
      hasRepresentativeImage: representativeImageUrl.isNotEmpty,
      hasShopUrl: true,
      hasPrimaryGenre: false,
      safe: true,
    ),
    aliases: ShopCatalogKeys.buildAliases(shopCode: shopCode, shopUrl: shopUrl),
    sampleProductIds: summary.representativeItems
        .map((e) => e.itemUrl.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList(growable: false),
  );
}

Future<ShopCatalogDiscoveryUpsertSummary> upsertShopCatalogFromDiscoverySummaries({
  required ShopCatalogRepository? repository,
  required Iterable<ShopDiscoverySummary> summaries,
  DateTime? now,
}) async {
  final list = summaries.toList(growable: false);
  if (!ShopCatalogConfig.kShopCatalogEnabled || repository == null) {
    return ShopCatalogDiscoveryUpsertSummary(
      summaries: list.length,
      upserted: 0,
      skippedNoShopCode: 0,
      skippedInvalidShopName: 0,
      skippedUnsafe: 0,
      skippedInvalidShopUrl: 0,
    );
  }

  var skippedNoShopCode = 0;
  var skippedInvalidShopName = 0;
  var skippedUnsafe = 0;
  var skippedInvalidShopUrl = 0;
  final entries = <ShopCatalogEntry>[];

  for (final summary in list) {
    final shopCode = summary.shopKey.trim();
    if (ShopCatalogKeys.normalizeShopCode(shopCode) == null ||
        shopCode == 'unknown') {
      skippedNoShopCode++;
      continue;
    }

    final shopName = summary.shopName.trim();
    if (shopName.isEmpty ||
        shopName == ShopDisplayResolve.unknownShopLabel ||
        ShopDisplayResolve.looksLikeShopCode(shopName)) {
      skippedInvalidShopName++;
      continue;
    }

    if (!_isValidShopUrl(summary.shopUrl)) {
      skippedInvalidShopUrl++;
      continue;
    }

    if (summary.hitItemCount <= 0) {
      skippedUnsafe++;
      continue;
    }

    final entry = shopCatalogEntryFromDiscoverySummary(summary, now: now);
    if (entry == null) {
      skippedUnsafe++;
      continue;
    }
    entries.add(entry);
  }

  try {
    if (entries.isNotEmpty) {
      await repository.upsertAll(entries);
    }
  } catch (e) {
    importantDebugLog('[SHOP_CATALOG_DISCOVERY_UPSERT] failed: $e');
  }

  final result = ShopCatalogDiscoveryUpsertSummary(
    summaries: list.length,
    upserted: entries.length,
    skippedNoShopCode: skippedNoShopCode,
    skippedInvalidShopName: skippedInvalidShopName,
    skippedUnsafe: skippedUnsafe,
    skippedInvalidShopUrl: skippedInvalidShopUrl,
  );

  shopCatalogAuditLog(
    '[SHOP_CATALOG_DISCOVERY_UPSERT_SUMMARY] '
    'summaries=${result.summaries} '
    'upserted=${result.upserted} '
    'skippedNoShopCode=${result.skippedNoShopCode} '
    'skippedInvalidShopName=${result.skippedInvalidShopName} '
    'skippedUnsafe=${result.skippedUnsafe} '
    'skippedInvalidShopUrl=${result.skippedInvalidShopUrl} '
    'source=shopDiscovery',
  );

  return result;
}

bool _isValidShopUrl(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  final uri = Uri.tryParse(t);
  if (uri == null || !uri.hasAuthority) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

String _safeRepresentativeImageUrl(Iterable<ShopRepresentativeItem> items) {
  for (final item in items) {
    final imageUrl = item.imageUrl.trim();
    if (imageUrl.isEmpty) continue;
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasAuthority) continue;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') continue;
    if (RoomImportProductImage.isRejectedProductImageUrl(imageUrl)) continue;
    return imageUrl;
  }
  return '';
}
