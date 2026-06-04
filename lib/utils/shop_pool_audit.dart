import '../config/product_catalog_config.dart';
import '../repository/product_catalog_repository.dart';
import '../services/product_catalog_shop_aggregator.dart';
import 'app_debug_log.dart';
import 'product_catalog_audit.dart';
import 'product_catalog_upsert_timing.dart';
import 'shop_pool_fallback_audit.dart';

/// ProductCatalog 由来 ShopPool の監査サマリ（読み取りのみ・UI/API 非変更）。
void logShopPoolSummaryFromProductCatalog({
  required ProductCatalogRepository? productCatalogRepository,
  required String source,
  Set<String> excludeSavedShopCodes = const {},
}) {
  if (!ProductCatalogConfig.kProductCatalogEnabled) return;
  final repo = productCatalogRepository;
  if (repo == null) return;

  final result = ProductCatalogShopAggregator.aggregate(
    repository: repo,
    excludeSavedShopCodes: excludeSavedShopCodes,
  );
  ProductCatalogUpsertTimingRegistry.logReadTimingIfEnabled(
    phase: 'searchPostSchedule',
    catalogCountAtRead: repo.count(),
  );
  final s = result.stats;
  shopPoolSummaryLog(
    'source=$source catalogProducts=${s.catalogProducts} '
    'catalogShops=${s.catalogShops} poolCandidates=${s.poolCandidates} '
    'savedExcluded=${s.savedExcluded} staleExcluded=${s.staleExcluded} '
    'lowTrustExcluded=${s.lowTrustExcluded} unsafeExcluded=${s.unsafeExcluded} '
    'emptyShopCodeExcluded=${s.emptyShopCodeExcluded}',
  );
  logShopPoolDepthSummaryWithDiagnostics(
    source: source,
    candidates: result.candidates,
    repository: repo,
    excludeSavedShopCodes: excludeSavedShopCodes,
  );
  logShopPoolStaleReferenceSummary(
    repository: repo,
    excludeSavedShopCodes: excludeSavedShopCodes,
  );
  logPhase3IStrategyAuditEstimate(
    repository: repo,
    excludeSavedShopCodes: excludeSavedShopCodes,
  );
}
