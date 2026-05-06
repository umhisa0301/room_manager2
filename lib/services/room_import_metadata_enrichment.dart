import '../models/rakuten_managed_product.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';

/// Phase 3 向けに ROOM 取り込みコレのメタデータをバッチで API 補完するサービス。
///
/// 取り込み直後の補完は [RakutenSearchRepository.fetchFirstItemForRoomImportEnrichment] を
/// [RoomSyncService] / [RoomCollectedRegisterService] から呼び出す。
///
/// 将来マイページや ROOM 取り込みカードから [enrichRoomImportedProducts] を叩けるようにする。
class RoomImportMetadataEnrichmentService {
  RoomImportMetadataEnrichmentService({
    required RakutenSearchRepository searchRepository,
    required RakutenManagedProductRepository productRepository,
  }) : _searchRepository = searchRepository,
       _productRepository = productRepository;

  final RakutenSearchRepository _searchRepository;
  final RakutenManagedProductRepository _productRepository;

  /// [shopName] または [genreName] が未設定の ROOM 取り込みコレ済を最大 [limit] 件まで API で補完する。
  ///
  /// - [shopCode] と [productId]（楽天 itemCode の数字側）が両方ある行のみ対象
  /// - 失敗しても次の行へ進む
  /// - 成功時は [RakutenManagedProductRepository.mergeRoomImportMetadataFromSearchItem] でマージ
  Future<int> enrichRoomImportedProducts({required int limit}) async {
    if (limit <= 0) return 0;
    final rows = _productRepository.loadAll();
    final pending = rows.where(_needsRoomImportMetadataEnrichment).take(limit);
    var okCount = 0;
    for (final row in pending) {
      final shop = row.shopCode.trim();
      final pid = row.productId.trim();
      if (shop.isEmpty || pid.isEmpty) continue;
      try {
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: true);
        });
      } catch (_) {
        continue;
      }
      try {
        final api = await _searchRepository.fetchFirstItemForRoomImportEnrichment(
          shopCode: shop,
          itemCode: pid,
        );
        if (api == null) {
          await _productRepository.updateManagedProduct(pid, (e) {
            return e.copyWith(roomImportMetadataEnriching: false);
          });
          continue;
        }
        await _productRepository.mergeRoomImportMetadataFromSearchItem(
          productId: pid,
          api: api,
        );
        okCount++;
      } catch (_) {
        await _productRepository.updateManagedProduct(pid, (e) {
          return e.copyWith(roomImportMetadataEnriching: false);
        });
      }
    }
    return okCount;
  }

  static bool _needsRoomImportMetadataEnrichment(RakutenManagedProduct e) {
    if (e.coredActivitySource != RakutenCoredActivitySource.roomImport) {
      return false;
    }
    if (!RakutenManagedProduct.isMemberForStatusTab(
      e,
      RakutenManagedProductStatus.done,
    )) {
      return false;
    }
    if (e.shopCode.trim().isEmpty || e.productId.trim().isEmpty) {
      return false;
    }
    final shopNeeds = _isShopNameNeedsEnrichment(e.shopName);
    final genreNeeds = _isGenreNameNeedsEnrichment(e.genreName);
    return shopNeeds || genreNeeds;
  }

  /// [shopName] が未設定・プレースホルダのとき API で上書き対象にする。
  static bool _isShopNameNeedsEnrichment(String? raw) {
    final t = (raw ?? '').trim();
    return t.isEmpty ||
        t == 'ショップ未設定' ||
        t == 'ショップ名不明';
  }

  /// [genreName] が未設定・プレースホルダのとき API で名前解決の対象にする。
  static bool _isGenreNameNeedsEnrichment(String? raw) {
    final t = (raw ?? '').trim();
    return t.isEmpty || t == 'ジャンル未設定';
  }
}
