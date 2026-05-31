import '../config/product_catalog_config.dart';
import '../models/catalog_product.dart';
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
  }
  return summary;
}
