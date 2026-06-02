import '../config/debug_log_flags.dart';
import '../config/product_catalog_config.dart';
import '../models/catalog_product.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/product_catalog_repository.dart';
import '../services/rakuten_item_url_parser.dart';
import 'app_debug_log.dart';
import 'catalog_product_keys.dart';

/// [RakutenSearchItem] から [CatalogProduct] を生成。
CatalogProduct catalogProductFromSearchItem(
  RakutenSearchItem item, {
  CatalogProductSource source = CatalogProductSource.search,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? now,
  String? roomPageUrl,
}) {
  final t = now ?? DateTime.now();
  final normalizedUrl = CatalogProductKeys.normalizeItemUrl(item.itemUrl);
  final parsed = RakutenItemUrlParser.tryParse(item.itemUrl);
  final canonicalId = CatalogProductKeys.resolveCanonicalId(
    productId: item.productId,
    itemUrl: item.itemUrl,
    normalizedItemUrl: normalizedUrl,
  );
  final aliases = CatalogProductKeys.buildAliases(
    canonicalId: canonicalId ?? '',
    productId: item.productId,
    itemUrl: item.itemUrl,
    normalizedItemUrl: normalizedUrl,
    shopCode: parsed?.shopCode ?? item.shopCode,
    itemPathSegment: parsed?.itemPathSegment,
    roomPageUrl: roomPageUrl,
  );

  final product = CatalogProduct(
    canonicalId: canonicalId ?? '',
    productId: item.productId,
    itemCode: item.productId,
    itemUrl: item.itemUrl,
    normalizedItemUrl: normalizedUrl,
    itemName: item.itemName,
    itemPrice: item.itemPrice,
    imageUrl: item.imageUrl,
    shopCode: item.shopCode,
    shopName: item.shopName,
    shopUrl: item.shopUrl,
    genreId: item.genreId,
    genreName: item.genreName,
    reviewAverage: item.reviewAverage,
    reviewCount: item.reviewCount,
    affiliateUrl: item.affiliateUrl,
    itemCaption: '',
    source: source,
    sourceTrust: sourceTrust,
    fetchedAt: t,
    lastValidatedAt: t,
    lastAccessedAt: t,
    qualityStatus: const CatalogProductQualityStatus(
      hasImage: false,
      hasPrice: false,
      hasValidUrl: false,
      safe: true,
    ),
    aliases: aliases,
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
  return product.withRecomputedQuality();
}

/// [RakutenManagedProduct] から [CatalogProduct] を生成。
CatalogProduct catalogProductFromManagedProduct(
  RakutenManagedProduct row, {
  CatalogProductSource source = CatalogProductSource.roomImport,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.medium,
  DateTime? now,
}) {
  return catalogProductFromSearchItem(
    RakutenSearchItem(
      productId: row.productId,
      itemName: row.itemName,
      itemPrice: row.itemPrice,
      itemUrl: row.itemUrl,
      affiliateUrl: row.affiliateUrl ?? '',
      imageUrl: row.imageUrl,
      shopName: row.shopName,
      reviewCount: row.reviewCount,
      reviewAverage: row.reviewAverage,
      shopCode: row.shopCode,
      shopUrl: row.shopUrl,
      genreId: row.genreId,
      genreName: row.genreName,
    ),
    source: source,
    sourceTrust: sourceTrust,
    now: now,
    roomPageUrl: row.roomUrl,
  );
}

/// [CatalogProduct] を既存 UI 互換の [RakutenSearchItem] に変換。
RakutenSearchItem catalogProductToSearchItem(CatalogProduct product) {
  return RakutenSearchItem(
    productId: product.productId.isNotEmpty
        ? product.productId
        : product.canonicalId,
    itemName: product.itemName,
    itemPrice: product.itemPrice,
    itemUrl: product.itemUrl,
    affiliateUrl: product.affiliateUrl,
    imageUrl: product.imageUrl,
    shopName: product.shopName,
    reviewCount: product.reviewCount,
    reviewAverage: product.reviewAverage,
    shopCode: product.shopCode,
    shopUrl: product.shopUrl,
    genreId: product.genreId,
    genreName: product.genreName,
  );
}

/// upsert 結果サマリ。
class ProductCatalogUpsertSummary {
  const ProductCatalogUpsertSummary({
    required this.attempted,
    required this.upserted,
    required this.skipped,
    required this.merged,
    this.qualityNg = 0,
  });

  const ProductCatalogUpsertSummary.skipped()
    : attempted = 0,
      upserted = 0,
      skipped = 0,
      merged = 0,
      qualityNg = 0;

  final int attempted;
  final int upserted;
  final int skipped;
  final int merged;

  /// 安全判定 NG のため保存しなかった件数。
  final int qualityNg;
}

/// 探すタブ検索モード向けの監査ログ用ラベル。
String catalogUpsertModeLabelForSearchModeTag(String modeTag) {
  switch (modeTag) {
    case 'genre':
      return 'genreSearch';
    case 'savedShop':
      return 'savedShopSearch';
    case 'product':
    default:
      return 'productSearch';
  }
}

/// 検索結果をカタログへ upsert（[ProductCatalogConfig.kProductCatalogEnabled] 時のみ）。
Future<ProductCatalogUpsertSummary> upsertCatalogFromSearchItems(
  ProductCatalogRepository repository,
  Iterable<RakutenSearchItem> items, {
  CatalogProductSource source = CatalogProductSource.search,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? now,
  String? catalogMode,
}) async {
  if (!ProductCatalogConfig.kProductCatalogEnabled) {
    return const ProductCatalogUpsertSummary.skipped();
  }
  final list = items.toList(growable: false);
  if (list.isEmpty) {
    return const ProductCatalogUpsertSummary(
      attempted: 0,
      upserted: 0,
      skipped: 0,
      merged: 0,
    );
  }

  var qualityNg = 0;
  final products = <CatalogProduct>[];
  for (final item in list) {
    final product = catalogProductFromSearchItem(
      item,
      source: source,
      sourceTrust: sourceTrust,
      now: now,
    );
    if (!product.isSavable) continue;
    if (!product.qualityStatus.safe) {
      qualityNg++;
      continue;
    }
    products.add(product);
  }

  final skipped = list.length - products.length - qualityNg;
  final result = await repository.upsertAll(products);
  final summary = ProductCatalogUpsertSummary(
    attempted: list.length,
    upserted: result.inserted + result.updated,
    skipped: skipped + result.skipped,
    merged: result.updated,
    qualityNg: qualityNg,
  );
  if (catalogMode != null && catalogMode.isNotEmpty) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_SEARCH_UPSERT_SUMMARY] mode=$catalogMode '
      'items=${summary.attempted} upserted=${summary.upserted} '
      'skipped=${summary.skipped} qualityNg=${summary.qualityNg} '
      'source=${source.name}',
    );
    _logProductCatalogSearchVerifySummary(
      repository,
      products,
      catalogMode,
    );
  }
  return summary;
}

/// おすすめコレ API 取得結果をカタログへ upsert。
Future<ProductCatalogUpsertSummary> upsertCatalogFromRecommendItems(
  ProductCatalogRepository repository,
  Iterable<RakutenSearchItem> items, {
  DateTime? now,
}) async {
  final summary = await upsertCatalogFromSearchItems(
    repository,
    items,
    source: CatalogProductSource.todayRecommendation,
    sourceTrust: CatalogProductSourceTrust.high,
    now: now,
  );
  if (!ProductCatalogConfig.kProductCatalogEnabled) {
    return summary;
  }
  catalogAuditLog(
    '[PRODUCT_CATALOG_RECOMMEND_UPSERT_SUMMARY] items=${summary.attempted} '
    'upserted=${summary.upserted} skipped=${summary.skipped} '
    'qualityNg=${summary.qualityNg} source=todayRecommendation',
  );
  return summary;
}

/// ROOM 取り込み・補完結果をカタログへ upsert（失敗しても呼び出し元は継続）。
Future<ProductCatalogUpsertSummary> upsertCatalogFromRoomManagedProducts(
  ProductCatalogRepository? repository,
  Iterable<RakutenManagedProduct> items, {
  CatalogProductSource source = CatalogProductSource.roomImport,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.medium,
  DateTime? now,
}) async {
  if (repository == null || !ProductCatalogConfig.kProductCatalogEnabled) {
    return const ProductCatalogUpsertSummary.skipped();
  }
  final list = items.toList(growable: false);
  if (list.isEmpty) {
    return const ProductCatalogUpsertSummary(
      attempted: 0,
      upserted: 0,
      skipped: 0,
      merged: 0,
    );
  }

  var qualityNg = 0;
  var trustHigh = 0;
  var trustMedium = 0;
  var trustLow = 0;
  final products = <CatalogProduct>[];
  for (final row in list) {
    final product = catalogProductFromManagedProduct(
      row,
      source: source,
      sourceTrust: sourceTrust,
      now: now,
    );
    switch (product.sourceTrust) {
      case CatalogProductSourceTrust.high:
        trustHigh++;
      case CatalogProductSourceTrust.medium:
        trustMedium++;
      case CatalogProductSourceTrust.low:
        trustLow++;
    }
    if (!product.isSavable) continue;
    if (!product.qualityStatus.safe) {
      qualityNg++;
      continue;
    }
    products.add(product);
  }

  try {
    final skipped = list.length - products.length - qualityNg;
    final result = await repository.upsertAll(products);
    final summary = ProductCatalogUpsertSummary(
      attempted: list.length,
      upserted: result.inserted + result.updated,
      skipped: skipped + result.skipped,
      merged: result.updated,
      qualityNg: qualityNg,
    );
    _logRoomCatalogUpsertSummary(
      source: source,
      summary: summary,
      trustHigh: trustHigh,
      trustMedium: trustMedium,
      trustLow: trustLow,
    );
    return summary;
  } catch (e) {
    importantDebugLog('[ROOM_CATALOG_UPSERT] failed: $e');
    return ProductCatalogUpsertSummary(
      attempted: list.length,
      upserted: 0,
      skipped: list.length,
      merged: 0,
      qualityNg: qualityNg,
    );
  }
}

void _logRoomCatalogUpsertSummary({
  required CatalogProductSource source,
  required ProductCatalogUpsertSummary summary,
  required int trustHigh,
  required int trustMedium,
  required int trustLow,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled &&
      !DebugLogFlags.kRoomAuditLogsEnabled) {
    return;
  }
  final line =
      '[ROOM_CATALOG_UPSERT_SUMMARY] source=${source.name} '
      'items=${summary.attempted} upserted=${summary.upserted} '
      'skipped=${summary.skipped} qualityNg=${summary.qualityNg} '
      'trustHigh=$trustHigh trustMedium=$trustMedium trustLow=$trustLow';
  if (DebugLogFlags.kCatalogAuditLogsEnabled) {
    catalogAuditLog(line);
  } else {
    roomAuditLog(line);
  }
}

/// 実機確認用: 保存直後のカタログ状態サマリ（[DebugLogFlags.kCatalogAuditLogsEnabled] 時のみ）。
void _logProductCatalogSearchVerifySummary(
  ProductCatalogRepository repository,
  List<CatalogProduct> products,
  String catalogMode,
) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final count = repository.count();
  if (products.isEmpty) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_SEARCH_VERIFY_SUMMARY] mode=$catalogMode '
      'count=$count savedBatch=0',
    );
    return;
  }
  final sample = products.first;
  final stored = repository.getByCanonicalId(sample.canonicalId, touch: false);
  final byProductId = sample.productId.trim().isNotEmpty
      ? repository.findByAlias(sample.productId, touch: false)
      : null;
  final byNormUrl = sample.normalizedItemUrl.trim().isNotEmpty
      ? repository.findByAlias(sample.normalizedItemUrl, touch: false)
      : null;
  final parsed = RakutenItemUrlParser.tryParse(sample.itemUrl);
  final shopItemAlias = parsed != null
      ? CatalogProductKeys.shopItemAlias(parsed.shopCode, parsed.itemPathSegment)
      : null;
  final byShopItem = shopItemAlias != null
      ? repository.findByAlias(shopItemAlias, touch: false)
      : null;
  var batchWithGenreId = 0;
  var batchWithGenreName = 0;
  for (final p in products) {
    if (p.genreId.trim().isNotEmpty) batchWithGenreId++;
    if (p.genreName.trim().isNotEmpty) batchWithGenreName++;
  }
  catalogAuditLog(
    '[PRODUCT_CATALOG_SEARCH_VERIFY_SUMMARY] mode=$catalogMode count=$count '
    'savedBatch=${products.length} batchWithGenreId=$batchWithGenreId '
    'batchWithGenreName=$batchWithGenreName '
    'canonicalId=${sample.canonicalId} '
    'getByCanonicalId=${stored != null} findByProductId=${byProductId != null} '
    'findByNormalizedUrl=${byNormUrl != null} findByShopItem=${byShopItem != null} '
    'sampleGenreId=${sample.genreId.isEmpty ? '-' : sample.genreId} '
    'sampleGenreName=${sample.genreName.isEmpty ? '-' : sample.genreName} '
    'storedGenreId=${stored == null || stored.genreId.isEmpty ? '-' : stored.genreId} '
    'storedGenreName=${stored == null || stored.genreName.isEmpty ? '-' : stored.genreName} '
    'source=${stored?.source.name} sourceTrust=${stored?.sourceTrust.name} '
    'qualitySafe=${stored?.qualityStatus.safe} '
    'hasImage=${stored?.qualityStatus.hasImage} hasPrice=${stored?.qualityStatus.hasPrice}',
  );
}
