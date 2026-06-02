import '../config/debug_log_flags.dart';
import '../models/catalog_product.dart';
import '../repository/product_catalog_repository.dart';
import 'app_debug_log.dart';

/// ProductCatalog 全体のフィールド分布（[CATALOG_AUDIT_LOGS] 時のみ）。
void logProductCatalogDistributionSummary(ProductCatalogRepository repository) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;

  final products = repository.getAll();
  final total = products.length;
  if (total == 0) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_DISTRIBUTION_SUMMARY] total=0 '
      'withGenreId=0 withGenreName=0 withShopCode=0 withShopName=0 '
      'withItemName=0 unknownGenreName=0 '
      'sourceBreakdown=- trustBreakdown=-',
    );
    return;
  }

  var withGenreId = 0;
  var withGenreName = 0;
  var withShopCode = 0;
  var withShopName = 0;
  var withItemName = 0;
  var unknownGenreName = 0;
  final sourceCounts = <CatalogProductSource, int>{};
  final trustCounts = <CatalogProductSourceTrust, int>{};

  for (final p in products) {
    if (p.genreId.trim().isNotEmpty) withGenreId++;
    final gn = p.genreName.trim();
    if (gn.isNotEmpty && gn.toLowerCase() != 'unknown') {
      withGenreName++;
    } else {
      unknownGenreName++;
    }
    if (p.shopCode.trim().isNotEmpty) withShopCode++;
    if (p.shopName.trim().isNotEmpty) withShopName++;
    if (p.itemName.trim().isNotEmpty) withItemName++;
    sourceCounts.update(p.source, (v) => v + 1, ifAbsent: () => 1);
    trustCounts.update(p.sourceTrust, (v) => v + 1, ifAbsent: () => 1);
  }

  catalogAuditLog(
    '[PRODUCT_CATALOG_DISTRIBUTION_SUMMARY] '
    'total=$total '
    'withGenreId=$withGenreId '
    'withGenreName=$withGenreName '
    'withShopCode=$withShopCode '
    'withShopName=$withShopName '
    'withItemName=$withItemName '
    'unknownGenreName=$unknownGenreName '
    'sourceBreakdown=${_formatEnumCounts(sourceCounts)} '
    'trustBreakdown=${_formatTrustCounts(trustCounts)}',
  );
}

String _formatEnumCounts(Map<CatalogProductSource, int> counts) {
  if (counts.isEmpty) return '-';
  final parts = CatalogProductSource.values
      .where(counts.containsKey)
      .map((e) => '${e.name}:${counts[e]}')
      .toList(growable: false);
  return parts.isEmpty ? '-' : parts.join(',');
}

String _formatTrustCounts(Map<CatalogProductSourceTrust, int> counts) {
  if (counts.isEmpty) return '-';
  final parts = CatalogProductSourceTrust.values
      .where(counts.containsKey)
      .map((e) => '${e.name}:${counts[e]}')
      .toList(growable: false);
  return parts.isEmpty ? '-' : parts.join(',');
}
