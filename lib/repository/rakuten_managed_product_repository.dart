import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/demo_mode.dart';
import '../data/demo_mode_data.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../models/room_collected_persist_kind.dart';
import '../models/room_collected_persist_outcome.dart';
import '../services/rakuten_item_url_parser.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/managed_product_diag_log.dart';
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_reaction_status_display.dart';
import '../utils/room_import_product_image.dart';
import '../utils/room_sync_log.dart';

/// ROOM 同期で既存コレ済行にヒットした照合結果（照合順は [RakutenManagedProductRepository.findRoomImportExistingRowMatch]）。
final class RoomImportExistingRowMatch {
  const RoomImportExistingRowMatch({
    required this.matchType,
    required this.row,
    required this.listIndex,
  });

  /// `roomUrl` / `normalizedRoomUrl` / `shopItem` / `affiliateUrl` / `itemUrl`
  final String matchType;
  final RakutenManagedProduct row;
  final int listIndex;
}

bool _hasHttpImageUrl(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  final u = Uri.tryParse(t);
  if (u == null) return false;
  final s = u.scheme.toLowerCase();
  return s == 'http' || s == 'https';
}

/// ROOM取り込み保存時の画像URL（楽天API > 確定できるROOM商品画像 > 既存）。
String _pickRoomImportPersistImageUrl({
  required String roomPageImageUrl,
  String apiImageUrl = '',
  String existingImageUrl = '',
  bool preserveExistingOnly = false,
  String productId = '',
}) {
  final filteredRoom = RoomImportProductImage.isRejectedProductImageUrl(
        roomPageImageUrl.trim(),
      )
      ? ''
      : roomPageImageUrl.trim();
  return RoomImportProductImage.pickPersistImageUrl(
    productId: productId.isEmpty ? 'unknown' : productId,
    roomPageImageUrl: filteredRoom,
    apiImageUrl: apiImageUrl,
    existingImageUrl: existingImageUrl,
    preserveExistingOnly: preserveExistingOnly,
  );
}

void _logRoomImportImageSource({
  required String productId,
  required String title,
  required String roomPageImageUrl,
  required String apiImageUrl,
  required String selectedUrl,
  required String selectedSource,
  String collectsImageUrl = '',
  String roomDetailImageUrl = '',
}) {
  roomImportImageSourceLog(
    'productId=$productId '
    'title=${title.trim().isEmpty ? '(empty)' : title.trim()} '
    'hasRoomImage=${_hasHttpImageUrl(roomPageImageUrl)} '
    'hasCollectsImage=${_hasHttpImageUrl(collectsImageUrl)} '
    'hasRoomDetailImage=${_hasHttpImageUrl(roomDetailImageUrl)} '
    'hasApiImage=${_hasHttpImageUrl(apiImageUrl)} '
    'selectedSource=$selectedSource '
    'selectedUrl=${selectedUrl.trim().isEmpty ? '(empty)' : selectedUrl.trim()}',
  );
}

/// 楽天検索由来の商品をローカル管理する（コレ候補・将来のコレ済・抽出結果などの拡張前提）。
class RakutenManagedProductRepository {
  RakutenManagedProductRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyList = 'rakuten_room_managed_products_v1';

  static bool _urlsEqualLoose(String? a, String? b) {
    final x = a?.trim() ?? '';
    final y = b?.trim() ?? '';
    if (x.isEmpty || y.isEmpty) return false;
    return x.toLowerCase() == y.toLowerCase();
  }

  /// ROOM 同期用の既存行検索（1) roomUrl 2) 正規化ROOMキー 3) shop+item 4) affiliate 5) itemUrl）。
  static RoomImportExistingRowMatch? findRoomImportExistingRowMatch({
    required List<RakutenManagedProduct> list,
    required String roomPageUrl,
    required String normalizedRoomUrlKey,
    required RakutenItemUrlParseResult parsedItem,
    String? roomPageAffiliateUrl,
  }) {
    final key = normalizedRoomUrlKey.trim();
    final rawRoom = roomPageUrl.trim();
    final roomAff = roomPageAffiliateUrl?.trim() ?? '';
    final pc = parsedItem.rakutenUrl.trim();

    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final ru = e.roomUrl.trim();
      if (ru.isNotEmpty && ru == rawRoom) {
        return RoomImportExistingRowMatch(matchType: 'roomUrl', row: e, listIndex: i);
      }
    }
    if (key.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(e.roomUrl);
        if (ek.isNotEmpty && ek == key) {
          return RoomImportExistingRowMatch(
            matchType: 'normalizedRoomUrl',
            row: e,
            listIndex: i,
          );
        }
      }
    }
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (_matchesPersistParsedItem(e, parsedItem)) {
        return RoomImportExistingRowMatch(matchType: 'shopItem', row: e, listIndex: i);
      }
    }
    if (roomAff.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (_urlsEqualLoose(e.affiliateUrl, roomAff)) {
          return RoomImportExistingRowMatch(
            matchType: 'affiliateUrl',
            row: e,
            listIndex: i,
          );
        }
      }
    }
    if (pc.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (_urlsEqualLoose(e.itemUrl, pc) || _urlsEqualLoose(e.rakutenUrl, pc)) {
          return RoomImportExistingRowMatch(matchType: 'itemUrl', row: e, listIndex: i);
        }
      }
    }
    return null;
  }

  /// ROOM 商品ページキー照合用（メモリ上の一覧から構築）。
  static Set<String> normalizedRoomProductUrlKeys(
    Iterable<RakutenManagedProduct> items,
  ) {
    final out = <String>{};
    for (final e in items) {
      final k = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(e.roomUrl);
      if (k.isNotEmpty) out.add(k);
    }
    return out;
  }

  static bool _debugLoggedLoadAllSummaryOnce = false;

  /// [RakutenSearchItem] ごとの表示ジャンル解決結果（同一 productId の再計算抑止）。
  final Map<String, String> _resolvedGenreLabelByProductId = {};

  /// [status] に一致する商品だけを返す（更新日時の新しい順）。
  List<RakutenManagedProduct> loadByStatus(RakutenManagedProductStatus status) {
    final list = loadAll()
        .where((e) => RakutenManagedProduct.isMemberForStatusTab(e, status))
        .toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 保存済みの一覧を読み込む。要素単位でパースし、1件失敗で全体を捨てない。
  List<RakutenManagedProduct> loadAll() {
    if (kDemoModeEnabled) {
      return DemoModeData.managedProducts();
    }
    try {
      final jsonStr = _prefs.getString(_keyList);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return [];

      final out = <RakutenManagedProduct>[];
      for (final entry in decoded) {
        try {
          Map<String, dynamic>? map;
          if (entry is Map<String, dynamic>) {
            map = entry;
          } else if (entry is Map) {
            map = Map<String, dynamic>.from(entry);
          } else {
            if (kDebugMode) {
              debugPrint(
                '[ROOMコレ診断] loadAll skip non-map entry type=${entry.runtimeType}',
              );
            }
            continue;
          }
          final item = RakutenManagedProduct.fromJson(map);
          if (item != null) {
            out.add(item);
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[ROOMコレ診断] loadAll skip corrupt entry: $e\n$st');
          }
        }
      }
      if (kDebugMode && !_debugLoggedLoadAllSummaryOnce) {
        _debugLoggedLoadAllSummaryOnce = true;
        debugPrint(
          '[ROOMコレ診断] loadAll 初回サマリー parsed=${out.length} '
          'rawJsonList=${decoded.length}',
        );
      }
      return out;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ROOMコレ診断] loadAll 全体失敗（JSON等）: $e\n$st');
      }
      return [];
    }
  }

  RakutenManagedProduct? getByProductId(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    for (final e in loadAll()) {
      if (e.productId == id) return e;
    }
    return null;
  }

  /// 正規化キーで ROOM 商品ページが既に永続化されているか（HTTP 取得前の短絡用）。
  bool isRoomProductPageKeySynced(String normalizedRoomUrlKey) {
    if (kDemoModeEnabled) {
      return false;
    }
    final key = normalizedRoomUrlKey.trim();
    if (key.isEmpty) return false;
    for (final e in loadAll()) {
      final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(e.roomUrl);
      if (ek.isNotEmpty && ek == key) return true;
    }
    return false;
  }

  static bool _matchesPersistParsedItem(
    RakutenManagedProduct e,
    RakutenItemUrlParseResult p,
  ) {
    if (e.productId.trim() == p.compositeProductId) return true;
    final sc = p.shopCode.trim();
    final seg = p.itemPathSegment.trim();
    if (sc.isEmpty || seg.isEmpty) return false;
    if (e.shopCode.trim() != sc) return false;
    final pid = e.productId.trim();
    return pid == seg;
  }

  /// ROOM同期バッチで、[shopCode + itemCode] が既にコレ済か検索する（APIスキップ判定用）。
  static RakutenManagedProduct? managedProductMatchingParsedRoomItem(
    List<RakutenManagedProduct> list,
    RakutenItemUrlParseResult parsed,
  ) {
    for (final e in list) {
      if (_matchesPersistParsedItem(e, parsed)) return e;
    }
    return null;
  }

  /// ROOM取り込みバッチの共有リスト保存直前に、同期開始後にディスクへ追加された行を取り込む。
  /// 古いスナップショットの [_saveAll] が候補追加を上書き消去するのを防ぐ。
  void _mergeConcurrentDiskAddsIntoWorkingList(
    List<RakutenManagedProduct> working,
  ) {
    if (kDemoModeEnabled) {
      return;
    }
    final disk = loadAll();
    final ids = <String>{for (final e in working) e.productId};
    for (final d in disk) {
      final id = d.productId.trim();
      if (id.isEmpty || ids.contains(id)) continue;
      working.add(d);
      ids.add(id);
    }
  }

  Future<void> _saveAllMaybeMerged({
    required List<RakutenManagedProduct> list,
    required List<RakutenManagedProduct>? workingMutableList,
  }) async {
    if (workingMutableList != null) {
      _mergeConcurrentDiskAddsIntoWorkingList(list);
    }
    await _saveAll(list);
  }

  void _debugLogRoomImportSave(String productId) {
    if (!kDebugMode) return;
    final c = ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
    ManagedProductDiagLog.logSave(
      action: 'roomImport',
      productId: productId,
      itemCode: '',
      beforePendingCount: -1,
      afterPendingCount: c.$1,
      beforeDoneCount: -1,
      afterDoneCount: c.$2,
    );
  }

  /// 検索結果1件をコレ候補として保存。同一 [RakutenSearchItem.productId] が既にあれば何もしない（重複防止）。
  /// 新規追加した場合は true。
  Future<bool> registerCandidateFromSearchItem(RakutenSearchItem item) async {
    if (kDemoModeEnabled) {
      return false;
    }
    final beforeCounts = ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
    final list = List<RakutenManagedProduct>.from(loadAll());
    for (final e in list) {
      if (e.productId == item.productId) {
        ManagedProductDiagLog.logSave(
          action: 'addCandidate',
          productId: item.productId,
          itemCode: item.productId,
          beforePendingCount: beforeCounts.$1,
          afterPendingCount: beforeCounts.$1,
          beforeDoneCount: beforeCounts.$2,
          afterDoneCount: beforeCounts.$2,
        );
        return false;
      }
    }
    final resolvedLabel = _resolvedGenreLabelForSearchItem(item);
    final candidate = RakutenManagedProduct.fromSearchItem(
      item,
      status: RakutenManagedProductStatus.candidate,
      resolvedGenreName: resolvedLabel,
    );
    if (kDebugMode) {
      debugPrint(
        '[RakutenGenre][SAVE] itemCode=${candidate.productId} '
        'save.genreId=${candidate.genreId} save.genreName=${candidate.genreName} '
        'save.resolvedGenreName=${candidate.resolvedGenreName}',
      );
    }
    list.add(candidate);
    await _saveAll(list);
    final afterCounts = ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
    ManagedProductDiagLog.logSave(
      action: 'addCandidate',
      productId: item.productId,
      itemCode: item.productId,
      beforePendingCount: beforeCounts.$1,
      afterPendingCount: afterCounts.$1,
      beforeDoneCount: beforeCounts.$2,
      afterDoneCount: afterCounts.$2,
    );
    if (kDebugMode) {
      debugPrint(
        '[ROOMコレ診断] registerCandidateFromSearchItem 保存 productId=${item.productId} '
        'status=candidate saveCount=${list.length}',
      );
    }
    return true;
  }

  Future<void> _mapProduct(
    String productId,
    RakutenManagedProduct Function(RakutenManagedProduct e) mapper,
  ) async {
    if (kDemoModeEnabled) {
      return;
    }
    final list = List<RakutenManagedProduct>.from(loadAll());
    final id = productId.trim();
    if (id.isEmpty) {
      throw Exception('商品IDが空です');
    }
    var found = false;
    final out = <RakutenManagedProduct>[];
    for (final e in list) {
      if (e.productId == id) {
        found = true;
        out.add(mapper(e));
      } else {
        out.add(e);
      }
    }
    if (!found) {
      throw Exception('商品が見つかりません');
    }
    await _saveAll(out);
  }

  /// ROOM取り込み済みコレの商品を、楽天検索APIの1件結果でマージ更新する（バッチ補完用）。
  Future<void> mergeRoomImportMetadataFromSearchItem({
    required String productId,
    required RakutenSearchItem api,
    String persistRoomApiCompositeItemCode = '',
  }) async {
    if (kDemoModeEnabled) {
      return;
    }
    final id = productId.trim();
    final before = getByProductId(id);
    await updateManagedProduct(productId, (e) {
      final resolvedLabel = _resolvedGenreLabelForSearchItem(api);
      final now = DateTime.now();
      final apiShop = api.shopName.trim();
      final mergedShopName =
          apiShop.isNotEmpty && apiShop != 'ショップ名不明' ? apiShop : e.shopName;
      final mergedGenreNameRaw = _mergedGenreNameForRoomImportApi(
        api: api,
        resolvedLabel: resolvedLabel,
        existingGenreName: e.genreName,
      );
      final exGenre = e.genreName.trim();
      final exGenreOk = exGenre.isNotEmpty && exGenre != 'ジャンル未設定';
      final mergedGenreName =
          mergedGenreNameRaw.trim().isEmpty && exGenreOk
          ? e.genreName
          : (mergedGenreNameRaw.trim().isNotEmpty
                ? mergedGenreNameRaw
                : e.genreName);
      final mergedGenreId =
          api.genreId.trim().isNotEmpty ? api.genreId : e.genreId;
      final learnedComp = persistRoomApiCompositeItemCode.trim();
      final roomHasPrice = e.itemPrice > 0;
      final roomHasImage = _hasHttpImageUrl(e.imageUrl);
      final apiPriceOk = api.itemPrice > 0;
      final apiImageOk = api.imageUrl.trim().isNotEmpty;
      return e.copyWith(
        itemName: api.itemName.trim().isNotEmpty ? api.itemName : e.itemName,
        itemPrice: !roomHasPrice && apiPriceOk ? api.itemPrice : e.itemPrice,
        itemUrl: api.itemUrl.trim().isNotEmpty ? api.itemUrl : e.itemUrl,
        rakutenUrl: api.itemUrl.trim().isNotEmpty ? api.itemUrl.trim() : e.rakutenUrl,
        affiliateUrl: api.affiliateUrl.trim().isNotEmpty
            ? api.affiliateUrl.trim()
            : e.affiliateUrl,
        imageUrl: !roomHasImage && apiImageOk ? api.imageUrl : e.imageUrl,
        shopName: mergedShopName,
        shopUrl: api.shopUrl.trim().isNotEmpty ? api.shopUrl : e.shopUrl,
        shopCode: api.shopCode.trim().isNotEmpty ? api.shopCode : e.shopCode,
        genreId: mergedGenreId,
        genreName: mergedGenreName,
        resolvedGenreName: resolvedLabel.isNotEmpty
            ? resolvedLabel
            : e.resolvedGenreName,
        reviewAverage: api.reviewAverage > 0 ? api.reviewAverage : e.reviewAverage,
        reviewCount: api.reviewCount > 0 ? api.reviewCount : e.reviewCount,
        updatedAt: now,
        roomApiCompositeItemCode: learnedComp.isNotEmpty
            ? learnedComp
            : e.roomApiCompositeItemCode,
        roomImportMetadataEnriching: false,
        roomImportEnrichFailureReason: '',
        roomImportEnrichFailureCount: 0,
        roomImportEnrichLastMethod: '',
        clearRoomImportEnrichBackoffUntil: true,
        clearRoomImportEnrichShopItemBlockedUntil: true,
        clearRoomImportEnrichTitleKeywordBlockedUntil: true,
        clearRoomImportEnrichProductIdKeywordBlockedUntil: true,
        clearRoomImportEnrichLastAttemptAt: true,
      );
    });
    final after = getByProductId(id);
    if (before != null && after != null) {
      final apiShopOk =
          api.shopName.trim().isNotEmpty && api.shopName.trim() != 'ショップ名不明';
      final roomHadPrice = before.itemPrice > 0;
      final roomHadImage = before.imageUrl.trim().isNotEmpty;
      final priceSaved = api.itemPrice > 0 &&
          !roomHadPrice &&
          after.itemPrice == api.itemPrice &&
          before.itemPrice != after.itemPrice;
      final imageSaved = api.imageUrl.trim().isNotEmpty &&
          !roomHadImage &&
          after.imageUrl.trim() == api.imageUrl.trim() &&
          before.imageUrl.trim() != after.imageUrl.trim();
      final shopNameSaved = apiShopOk &&
          after.shopName.trim() == api.shopName.trim() &&
          before.shopName.trim() != after.shopName.trim();
      final genreNameSaved = after.genreName.trim() != before.genreName.trim() &&
          (api.genreId.trim().isNotEmpty || api.genreName.trim().isNotEmpty);
      roomImportSaveLog(
        'changedPrice=$priceSaved changedImage=$imageSaved '
        'changedShopName=$shopNameSaved changedGenreName=$genreNameSaved',
      );
      final comp = after.roomApiCompositeItemCode.trim().isNotEmpty
          ? after.roomApiCompositeItemCode.trim()
          : persistRoomApiCompositeItemCode.trim();
      roomImportApiSupplementSuccessLog(
        'productId=$id apiCompositeItemCode=${comp.isEmpty ? '-' : comp} '
        'shopName=${after.shopName.trim()} genreId=${after.genreId.trim()} '
        'genreName=${after.genreName.trim()} priceUpdated=$priceSaved '
        'imageUpdated=$imageSaved shopNameUpdated=$shopNameSaved genreUpdated=$genreNameSaved',
      );
    }
    final row = getByProductId(id);
    if (row != null) {
      debugPrint('[ROOM_IMPORT_ENRICH] saved shopName=${row.shopName}');
      debugPrint('[ROOM_IMPORT_ENRICH] saved genreName=${row.genreName}');
    }
  }

  /// URL 抽出開始（コレ候補登録直後）。
  Future<void> markExtractionExtracting(String productId) async {
    await _mapProduct(productId, (e) {
      return e.copyWith(
        extractionStatus: RakutenUrlExtractionStatus.extracting,
        extractionErrorMessage: '',
        updatedAt: DateTime.now(),
      );
    });
  }

  /// URL 抽出成功。
  Future<void> completeExtractionSuccess(
    String productId,
    String extractedUrl,
  ) async {
    final now = DateTime.now();
    await _mapProduct(productId, (e) {
      return e.copyWith(
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractedUrl: extractedUrl,
        extractionErrorMessage: '',
        extractedAt: now,
        updatedAt: now,
      );
    });
  }

  /// URL 抽出失敗（候補登録自体は維持）。
  Future<void> completeExtractionFailed(
    String productId,
    String message,
  ) async {
    await _mapProduct(productId, (e) {
      return e.copyWith(
        extractionStatus: RakutenUrlExtractionStatus.failed,
        extractionErrorMessage: message,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// コレ候補をコレ済に移す（ROOM 抽出 URL 利用後）。
  Future<void> markCollectedDone(String productId) async {
    final id = productId.trim();
    final beforeCounts = kDemoModeEnabled
        ? (0, 0)
        : ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
    final now = DateTime.now();
    await _mapProduct(productId, (e) {
      if (e.status != RakutenManagedProductStatus.candidate) {
        throw Exception('コレ候補ではない商品です');
      }
      return e.copyWith(
        status: RakutenManagedProductStatus.done,
        doneAt: now,
        updatedAt: now,
        coredActivitySource: RakutenCoredActivitySource.appPost,
      );
    });
    if (!kDemoModeEnabled) {
      final afterCounts = ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
      ManagedProductDiagLog.logSave(
        action: 'addDone',
        productId: id,
        itemCode: id,
        beforePendingCount: beforeCounts.$1,
        afterPendingCount: afterCounts.$1,
        beforeDoneCount: beforeCounts.$2,
        afterDoneCount: afterCounts.$2,
      );
    }
  }

  /// フィードバックフラグなど、一覧要素の任意更新。
  Future<void> updateManagedProduct(
    String productId,
    RakutenManagedProduct Function(RakutenManagedProduct e) mapper,
  ) async {
    await _mapProduct(productId, mapper);
  }

  /// コレ候補を永続化一覧から削除する（再検索からの登録を再度可能にする）。
  Future<void> removeCandidateProduct(String productId) async {
    if (kDemoModeEnabled) {
      return;
    }
    final beforeCounts = ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
    final list = List<RakutenManagedProduct>.from(loadAll());
    final id = productId.trim();
    if (id.isEmpty) {
      throw Exception('商品IDが空です');
    }
    final next = <RakutenManagedProduct>[];
    var removed = false;
    for (final e in list) {
      if (e.productId == id) {
        if (e.status != RakutenManagedProductStatus.candidate) {
          throw Exception('コレ候補の商品のみ候補から外せます');
        }
        removed = true;
        continue;
      }
      next.add(e);
    }
    if (!removed) {
      throw Exception('商品が見つかりません');
    }
    await _saveAll(next);
    final afterCounts = ManagedProductDiagLog.pendingAndDoneCounts(loadAll());
    ManagedProductDiagLog.logSave(
      action: 'remove',
      productId: id,
      itemCode: id,
      beforePendingCount: beforeCounts.$1,
      afterPendingCount: afterCounts.$1,
      beforeDoneCount: beforeCounts.$2,
      afterDoneCount: afterCounts.$2,
    );
  }

  /// ROOM取り込みAPI補完で保存する `genreName`（API名優先、無ければマスタ解決名）。
  String _mergedGenreNameForRoomImportApi({
    required RakutenSearchItem api,
    required String resolvedLabel,
    required String existingGenreName,
  }) {
    final raw = api.genreName.trim();
    if (raw.isNotEmpty) return api.genreName;
    final r = resolvedLabel.trim();
    if (r.isNotEmpty) return r;
    return existingGenreName;
  }

  /// 検索一覧と同じルールの表示名（未分類・空 genreId は保存しない）。
  String _resolvedGenreLabelForSearchItem(RakutenSearchItem item) {
    final pid = item.productId.trim();
    if (pid.isNotEmpty) {
      final cached = _resolvedGenreLabelByProductId[pid];
      if (cached != null) return cached;
    }
    if (item.genreId.trim().isEmpty) {
      if (pid.isNotEmpty) _resolvedGenreLabelByProductId[pid] = '';
      return '';
    }
    final s = RakutenProductGenreDisplay.resolve(
      apiGenreName: item.genreName,
      persistedGenreName: null,
      prefetchedGenreName: null,
      genreId: item.genreId,
      traceItemCode: null,
    ).trim();
    final out = (s.isEmpty || s == RakutenProductGenreDisplay.unknownLabel)
        ? ''
        : s;
    if (pid.isNotEmpty) _resolvedGenreLabelByProductId[pid] = out;
    return out;
  }

  /// ROOM 商品ページ同期（単品・将来の一括の共通永続化）。
  ///
  /// **処理順**: roomUrl キー重複 → shopCode+itemCode 既存のマージ可否 → 新規コレ済插入。
  RakutenManagedProduct _mergeParsedRoomReactions(
    RakutenManagedProduct row,
    int? roomLikeCount,
    int? roomCommentCount,
    DateTime now,
  ) {
    if (roomLikeCount == null && roomCommentCount == null) return row;
    var next = row;
    if (roomLikeCount != null) {
      next = next.copyWith(roomLikeCount: roomLikeCount);
    }
    if (roomCommentCount != null) {
      next = next.copyWith(roomCommentCount: roomCommentCount);
    }
    final merged = next.copyWith(roomReactionUpdatedAt: now);
    RoomReactionStatusDisplay.logSave(
      productId: merged.productId.trim(),
      roomLikeCount: merged.roomLikeCount,
      roomCommentCount: merged.roomCommentCount,
    );
    return merged;
  }

  /// ROOMページ由来のアフィリエイトとAPIの `affiliateUrl` をマージ（**ROOM ページのアフィリエイトを最優先**）。
  String? _mergeAffiliateForRoomPersist({
    required String? roomPageAffiliateUrl,
    required RakutenSearchItem? api,
    required String? existingAffiliate,
  }) {
    final roomAff = roomPageAffiliateUrl?.trim() ?? '';
    if (roomAff.isNotEmpty) return roomAff;
    final apiAff = api?.affiliateUrl.trim() ?? '';
    if (apiAff.isNotEmpty) return apiAff;
    return existingAffiliate;
  }

  /// PC復元URL優先、無ければAPI・既存の通常URL。
  (String itemUrl, String? rakutenUrl) _normalUrlsForRoomPersist({
    required RakutenItemUrlParseResult parsedItem,
    RakutenSearchItem? api,
    required String fallbackItemUrl,
    required String? fallbackRakutenUrl,
  }) {
    final pc = parsedItem.rakutenUrl.trim();
    if (pc.isNotEmpty) return (pc, pc);
    final fromApi = api?.itemUrl.trim() ?? '';
    if (fromApi.isNotEmpty) return (fromApi, fromApi);
    return (fallbackItemUrl, fallbackRakutenUrl);
  }

  Future<RoomCollectedPersistOutcome> persistRoomCollectedFromRoomPage({
    required String roomUrlStoredCanonical,
    required String normalizedRoomUrlKey,
    required RakutenItemUrlParseResult parsedItem,
    String? roomPageAffiliateUrl,
    String roomPageTitle = '',
    String roomPageImageUrl = '',
    RakutenSearchItem? apiEnrichedItem,
    bool traceRoomSync = false,

    /// バッチ処理などで [loadAll] を繰り返さないための共有リスト（破壊的に更新される）。
    List<RakutenManagedProduct>? workingMutableList,
    int? roomLikeCount,
    int? roomCommentCount,

    /// 一覧HTML／collects 由来の参考価格（円）。ROOM 商品ページ由来の表示価格など。
    int? listingHintPriceYen,

    /// true のとき [listingHintPriceYen] を新規行の [itemPrice] に反映しない（反応数のみ更新など）。
    bool suppressListingHintPrice = false,

    /// 楽天検索APIが完全には取れなかった（プロキシ400・Items空など）。
    bool rakutenApiPartialData = false,

    /// 楽天API失敗後に ROOM 商品ページからメタを補填できた。
    bool roomImportFallbackRecovered = false,

    /// 同一 ROOM キーで反応数・同期時刻のみ更新（楽天APIなし）。
    bool roomImportResyncReactionsOnly = false,

    /// 既存商品に初めて ROOM URL を紐付けるが、商品メタは既存のまま（楽天APIなし）。
    bool roomImportAddRoomUrlToExistingNoApi = false,

    String roomProductSlugHint = '',
    String roomRatRedirectUrlHint = '',
    String roomRedirectShopCodeHint = '',
    String roomRedirectItemCodeHint = '',
    String roomApiCompositeItemCodeHint = '',
    String roomEventGenreIdHint = '',

    /// false のとき共有 [workingMutableList] のみ更新し、ディスクへは書かない（ROOM同期バッチ終了時に flush）。
    bool confirmDiskWrite = true,
  }) async {
    if (kDemoModeEnabled) {
      if (traceRoomSync) {
        roomSyncWarn('デモモードのため永続化スキップ（demoUnsupported）');
      }
      return const RoomCollectedPersistOutcome(
        kind: RoomCollectedPersistKind.demoUnsupported,
      );
    }
    final key = normalizedRoomUrlKey.trim();
    if (key.isEmpty) {
      if (traceRoomSync) {
        roomSyncWarn('normalizedRoomUrlKey が空のためスキップ（alreadyCollectedSkip）');
      }
      return const RoomCollectedPersistOutcome(
        kind: RoomCollectedPersistKind.alreadyCollectedSkip,
      );
    }

    final now = DateTime.now();

    if (traceRoomSync) {
      roomSyncLog('DB照合開始 normalizedRoomUrlKey=$key');
      roomSyncLog('roomUrl保存済み（同一キー先行検索）に該当するか確認');
    }

    final list =
        workingMutableList ?? List<RakutenManagedProduct>.from(loadAll());

    if (roomImportResyncReactionsOnly) {
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(e.roomUrl);
        if (ek.isNotEmpty && ek == key) {
          final effLikes = roomLikeCount ?? e.roomLikeCount;
          final effComments = roomCommentCount ?? e.roomCommentCount;
          if (effLikes == e.roomLikeCount && effComments == e.roomCommentCount) {
            if (traceRoomSync) {
              roomSyncLog('反応数変更なしのため保存スキップ productId=${e.productId}');
            }
            return RoomCollectedPersistOutcome(
              kind: RoomCollectedPersistKind.roomPageAlreadySynced,
              productId: e.productId,
            );
          }
          var next = _mergeParsedRoomReactions(
            e,
            roomLikeCount,
            roomCommentCount,
            now,
          );
          next = next.copyWith(
            roomSyncedAt: now,
            importedAt: now,
            updatedAt: now,
            isRoomSynced: true,
          );
          list[i] = next;
          try {
            if (confirmDiskWrite) {
              await _saveAllMaybeMerged(
                list: list,
                workingMutableList: workingMutableList,
              );
            }
            _debugLogRoomImportSave(e.productId);
            if ((next.affiliateUrl ?? '').trim().isNotEmpty) {
              roomImportSaveLog('affiliateUrlSaved=true');
            }
          } catch (e2, st) {
            if (traceRoomSync) {
              roomSyncError('保存失敗（ROOM反応のみ再同期）', e2, st);
            }
            rethrow;
          }
          return RoomCollectedPersistOutcome(
            kind: RoomCollectedPersistKind.roomReactionsUpdated,
            productId: e.productId,
          );
        }
      }
      if (traceRoomSync) {
        roomSyncWarn('反応のみ再同期: 該当行が見つかりません（alreadyCollectedSkip）');
      }
      return const RoomCollectedPersistOutcome(
        kind: RoomCollectedPersistKind.alreadyCollectedSkip,
      );
    }

    for (final e in list) {
      final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(e.roomUrl);
      if (ek.isNotEmpty && ek == key) {
        if (traceRoomSync) {
          roomSyncLog('既に同期済みのため登録処理をスキップします（roomPageAlreadySynced）');
          roomSyncLog('roomUrl保存済み: true（既存 productId=${e.productId}）');
          roomSyncLog('shopCode + itemCode 登録済み: (同一行)');
        }
        // TODO(RoomReactionRefresh): 軽量モードで反応数のみ更新できるようにする（再利用実行時など）。
        return RoomCollectedPersistOutcome(
          kind: RoomCollectedPersistKind.roomPageAlreadySynced,
          productId: e.productId,
        );
      }
    }

    if (traceRoomSync) {
      roomSyncLog('roomUrl保存済み: false（このキーでは未登録）');
    }

    RakutenManagedProduct? existing;
    var existingIndex = -1;
    for (var i = 0; i < list.length; i++) {
      if (_matchesPersistParsedItem(list[i], parsedItem)) {
        existing = list[i];
        existingIndex = i;
        break;
      }
    }

    if (traceRoomSync) {
      roomSyncLog(
        'shopCode + itemCode 登録済み: ${existing != null} '
        '(shop=${parsedItem.shopCode} itemPath=${parsedItem.itemPathSegment})',
      );
    }

    if (existing != null && existingIndex >= 0) {
      final storedRoom = existing.roomUrl.trim();
      if (storedRoom.isNotEmpty) {
        final rk = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
          storedRoom,
        );
        if (rk == key) {
          if (traceRoomSync) {
            roomSyncLog('既に同期済みのため登録処理をスキップします（同一商品・同一room）');
          }
          // TODO(RoomReactionRefresh): 軽量モードで反応数のみ更新。
          return RoomCollectedPersistOutcome(
            kind: RoomCollectedPersistKind.roomPageAlreadySynced,
            productId: existing.productId,
          );
        }
        if (traceRoomSync) {
          roomSyncLog(
            '既存行に別ROOMが紐付いているためスキップ（alreadyCollectedSkip） '
            'storedRoomKey=$rk',
          );
        }
        return RoomCollectedPersistOutcome(
          kind: RoomCollectedPersistKind.alreadyCollectedSkip,
          productId: existing.productId,
        );
      }

      if (traceRoomSync) {
        roomSyncLog('既存コレ済商品にROOM URLを追加します');
        roomSyncLog('保存開始 保存種別: 既存商品へROOM URL追加');
      }

      final preserveMetaOnly =
          roomImportAddRoomUrlToExistingNoApi && apiEnrichedItem == null;
      final t0 = roomPageTitle.trim();
      final img0 = roomPageImageUrl.trim();
      final t = preserveMetaOnly
          ? existing.itemName
          : (t0.isNotEmpty ? t0 : existing.itemName);
      final img = preserveMetaOnly
          ? existing.imageUrl
          : _pickRoomImportPersistImageUrl(
              roomPageImageUrl: img0,
              existingImageUrl: existing.imageUrl,
            );
      final urls = preserveMetaOnly
          ? (existing.itemUrl.trim(), existing.rakutenUrl)
          : _normalUrlsForRoomPersist(
              parsedItem: parsedItem,
              api: apiEnrichedItem,
              fallbackItemUrl: existing.itemUrl,
              fallbackRakutenUrl: existing.rakutenUrl,
            );
      var next = existing.copyWith(
        roomUrl: roomUrlStoredCanonical,
        itemUrl: urls.$1,
        rakutenUrl: urls.$2,
        shopCode: parsedItem.shopCode.isNotEmpty
            ? parsedItem.shopCode
            : existing.shopCode,
        itemName: t,
        imageUrl: img,
        updatedAt: now,
        status: RakutenManagedProductStatus.done,
        doneAt: existing.doneAt ?? now,
        isRoomSynced: true,
        roomSyncedAt: now,
        importedAt: now,
      );
      if (roomRatRedirectUrlHint.trim().isNotEmpty ||
          roomApiCompositeItemCodeHint.trim().isNotEmpty ||
          roomProductSlugHint.trim().isNotEmpty) {
        final slugEx = roomProductSlugHint.trim().isNotEmpty
            ? roomProductSlugHint.trim()
            : next.roomProductSlug;
        next = next.copyWith(
          roomProductSlug: slugEx,
          roomRatRedirectUrl: roomRatRedirectUrlHint.trim().isNotEmpty
              ? roomRatRedirectUrlHint.trim()
              : next.roomRatRedirectUrl,
          roomRedirectShopCode: roomRedirectShopCodeHint.trim().isNotEmpty
              ? roomRedirectShopCodeHint.trim()
              : next.roomRedirectShopCode,
          roomRedirectItemCode: roomRedirectItemCodeHint.trim().isNotEmpty
              ? roomRedirectItemCodeHint.trim()
              : next.roomRedirectItemCode,
          roomApiCompositeItemCode: roomApiCompositeItemCodeHint.trim().isNotEmpty
              ? roomApiCompositeItemCodeHint.trim()
              : next.roomApiCompositeItemCode,
          genreId: roomEventGenreIdHint.trim().isNotEmpty &&
                  next.genreId.trim().isEmpty
              ? roomEventGenreIdHint.trim()
              : next.genreId,
        );
      }

      final api = apiEnrichedItem;
      if (api != null) {
        if (api.itemPrice <= 0) {
          roomImportSaveLog(
            'preservedExistingPrice=true reason=apiPriceNonPositive',
          );
        }
        if (api.imageUrl.trim().isEmpty && existing.imageUrl.trim().isNotEmpty) {
          roomImportSaveLog('preservedExistingImage=true');
        }
        if (api.itemName.trim().isEmpty && existing.itemName.trim().isNotEmpty) {
          roomImportSaveLog('preservedExistingTitle=true');
        }
        final resolvedLabel = _resolvedGenreLabelForSearchItem(api);
        final mergedGn = _mergedGenreNameForRoomImportApi(
          api: api,
          resolvedLabel: resolvedLabel,
          existingGenreName: next.genreName,
        );
        if (mergedGn.trim().isEmpty &&
            api.genreName.trim().isEmpty &&
            api.genreId.trim().isEmpty &&
            existing.genreName.trim().isNotEmpty) {
          roomImportSaveLog('preservedExistingGenre=true');
        }
        if ((api.shopName.trim().isEmpty || api.shopName.trim() == 'ショップ名不明') &&
            existing.shopName.trim().isNotEmpty) {
          roomImportSaveLog('preservedExistingShopName=true');
        }
        next = next.copyWith(
          itemName: api.itemName.trim().isNotEmpty
              ? api.itemName
              : next.itemName,
          itemPrice: api.itemPrice > 0 ? api.itemPrice : next.itemPrice,
          shopName: () {
            final s = api.shopName.trim();
            return (s.isNotEmpty && s != 'ショップ名不明')
                ? api.shopName
                : next.shopName;
          }(),
          shopUrl: api.shopUrl.trim().isNotEmpty ? api.shopUrl : next.shopUrl,
          genreId: api.genreId.trim().isNotEmpty ? api.genreId : next.genreId,
          genreName: mergedGn.trim().isNotEmpty ? mergedGn : next.genreName,
          resolvedGenreName: resolvedLabel.isNotEmpty
              ? resolvedLabel
              : next.resolvedGenreName,
          imageUrl: _pickRoomImportPersistImageUrl(
            roomPageImageUrl: img0,
            apiImageUrl: api.imageUrl,
            existingImageUrl: next.imageUrl,
          ),
          reviewAverage: api.reviewAverage > 0
              ? api.reviewAverage
              : next.reviewAverage,
          reviewCount: api.reviewCount > 0 ? api.reviewCount : next.reviewCount,
          roomImportMetadataEnriching: false,
        );
        if (rakutenApiPartialData) {
          roomImportSaveLog('partialSuccess=true existingRowMerge=true');
        }
      }
      if (rakutenApiPartialData && roomImportFallbackRecovered) {
        roomImportSaveLog('partialSuccess=true fallbackRecovered=true');
      }

      next = next.copyWith(
        affiliateUrl: _mergeAffiliateForRoomPersist(
          roomPageAffiliateUrl: roomPageAffiliateUrl,
          api: apiEnrichedItem,
          existingAffiliate: existing.affiliateUrl,
        ),
      );

      next = _mergeParsedRoomReactions(
        next,
        roomLikeCount,
        roomCommentCount,
        now,
      );

      list[existingIndex] = next;
      _logRoomImportImageSource(
        productId: next.productId,
        title: next.itemName,
        roomPageImageUrl: img0,
        apiImageUrl: api?.imageUrl ?? '',
        selectedUrl: next.imageUrl,
        selectedSource: _hasHttpImageUrl(img0)
            ? 'room'
            : (_hasHttpImageUrl(api?.imageUrl ?? '') ? 'api' : 'placeholder'),
      );
      try {
        if (confirmDiskWrite) {
          await _saveAllMaybeMerged(
            list: list,
            workingMutableList: workingMutableList,
          );
        }
        _debugLogRoomImportSave(existing.productId);
        if ((next.affiliateUrl ?? '').trim().isNotEmpty) {
          roomImportSaveLog('affiliateUrlSaved=true');
        }
        if (traceRoomSync) {
          roomSyncLog('保存成功（既存商品へROOM URL追加）');
        }
      } catch (e, st) {
        if (traceRoomSync) {
          roomSyncError('保存失敗（既存商品へROOM URL追加）', e, st);
        }
        rethrow;
      }
      return RoomCollectedPersistOutcome(
        kind: RoomCollectedPersistKind.updatedRoomUrlOnly,
        productId: existing.productId,
      );
    }

    final title = roomPageTitle.trim().isNotEmpty
        ? roomPageTitle.trim()
        : '（ROOM投稿）';
    final image = _pickRoomImportPersistImageUrl(roomPageImageUrl: roomPageImageUrl);
    final newId = parsedItem.itemPathSegment.trim().isNotEmpty
        ? parsedItem.itemPathSegment.trim()
        : parsedItem.compositeProductId;
    final pcOnly = parsedItem.rakutenUrl.trim();
    final hintRaw = listingHintPriceYen;
    final int hintYen;
    if (suppressListingHintPrice) {
      hintYen = 0;
    } else {
      hintYen = (hintRaw != null && hintRaw > 0)
          ? hintRaw
          : (rakutenApiPartialData ? -1 : 0);
    }

    var row = RakutenManagedProduct(
      productId: newId,
      itemName: title,
      itemPrice: hintYen,
      itemUrl: pcOnly,
      rakutenUrl: pcOnly.isNotEmpty ? pcOnly : null,
      affiliateUrl: _mergeAffiliateForRoomPersist(
        roomPageAffiliateUrl: roomPageAffiliateUrl,
        api: null,
        existingAffiliate: null,
      ),
      imageUrl: image,
      shopName: '',
      shopCode: parsedItem.shopCode,
      shopUrl: '',
      genreId: '',
      genreName: '',
      resolvedGenreName: '',
      status: RakutenManagedProductStatus.done,
      createdAt: now,
      updatedAt: now,
      addedAt: now,
      extractedUrl: '',
      extractionStatus: RakutenUrlExtractionStatus.notStarted,
      extractionErrorMessage: '',
      extractedAt: null,
      roomUrl: roomUrlStoredCanonical,
      doneAt: now,
      feedbackLikedAt: null,
      feedbackSoldAt: null,
      feedbackWeakAt: null,
      isRoomSynced: true,
      roomSyncedAt: now,
      coredActivitySource: RakutenCoredActivitySource.roomImport,
      importedAt: now,
    );

    final slugPersist = roomProductSlugHint.trim().isNotEmpty
        ? roomProductSlugHint.trim()
        : newId;
    row = row.copyWith(
      roomProductSlug: slugPersist,
      roomRatRedirectUrl: roomRatRedirectUrlHint.trim(),
      roomRedirectShopCode: roomRedirectShopCodeHint.trim(),
      roomRedirectItemCode: roomRedirectItemCodeHint.trim(),
      roomApiCompositeItemCode: roomApiCompositeItemCodeHint.trim(),
      genreId: roomEventGenreIdHint.trim().isNotEmpty
          ? roomEventGenreIdHint.trim()
          : row.genreId,
    );

    final apiNew = apiEnrichedItem;
    if (apiNew != null) {
      if (traceRoomSync) {
        roomSyncLog(
          '未登録商品: 一覧ROOM由来を土台に、楽天APIで上書きできる項目のみマージします',
        );
        roomSyncLog('保存開始 保存種別: 新規コレ済登録（一覧＋APIマージ）');
      }
      final resolvedLabel = _resolvedGenreLabelForSearchItem(apiNew);
      final mergedNewGenreName = _mergedGenreNameForRoomImportApi(
        api: apiNew,
        resolvedLabel: resolvedLabel,
        existingGenreName: row.genreName,
      );
      final urlsNew = _normalUrlsForRoomPersist(
        parsedItem: parsedItem,
        api: apiNew,
        fallbackItemUrl: row.itemUrl,
        fallbackRakutenUrl: row.rakutenUrl,
      );
      row = row.copyWith(
        itemName: apiNew.itemName.trim().isNotEmpty ? apiNew.itemName : row.itemName,
        itemPrice: apiNew.itemPrice > 0 ? apiNew.itemPrice : row.itemPrice,
        itemUrl: urlsNew.$1.isNotEmpty ? urlsNew.$1 : row.itemUrl,
        rakutenUrl: urlsNew.$2 ?? row.rakutenUrl,
        affiliateUrl: _mergeAffiliateForRoomPersist(
          roomPageAffiliateUrl: roomPageAffiliateUrl,
          api: apiNew,
          existingAffiliate: row.affiliateUrl,
        ),
        shopCode: parsedItem.shopCode.isNotEmpty
            ? parsedItem.shopCode
            : (apiNew.shopCode.trim().isNotEmpty ? apiNew.shopCode : row.shopCode),
        shopName: () {
          final s = apiNew.shopName.trim();
          return (s.isNotEmpty && s != 'ショップ名不明')
              ? apiNew.shopName
              : row.shopName;
        }(),
        shopUrl: apiNew.shopUrl.trim().isNotEmpty ? apiNew.shopUrl : row.shopUrl,
        genreId: apiNew.genreId.trim().isNotEmpty ? apiNew.genreId : row.genreId,
        genreName: mergedNewGenreName.trim().isNotEmpty
            ? mergedNewGenreName
            : row.genreName,
        resolvedGenreName: resolvedLabel.isNotEmpty
            ? resolvedLabel
            : row.resolvedGenreName,
        imageUrl: _pickRoomImportPersistImageUrl(
          roomPageImageUrl: roomPageImageUrl,
          apiImageUrl: apiNew.imageUrl,
          existingImageUrl: row.imageUrl,
        ),
        reviewAverage: apiNew.reviewAverage > 0
            ? apiNew.reviewAverage
            : row.reviewAverage,
        reviewCount: apiNew.reviewCount > 0 ? apiNew.reviewCount : row.reviewCount,
      );
      if (rakutenApiPartialData) {
        roomImportSaveLog('partialSuccess=true newRow=true mergedWeakApi=true');
        roomImportSaveLog(
          'preservedListingHintPrice=${apiNew.itemPrice <= 0 && hintYen > 0}',
        );
      }
    } else {
      if (traceRoomSync) {
        roomSyncLog('API無し・一覧ROOM情報で新規コレ済登録します');
        roomSyncLog('保存開始 保存種別: 新規コレ済登録（一覧のみ）');
      }
      if (rakutenApiPartialData) {
        roomImportSaveLog(
          'partialSuccess=true newRow=true apiUnavailable=true metadataPending=true',
        );
      }
    }
    if (rakutenApiPartialData && roomImportFallbackRecovered) {
      roomImportSaveLog('partialSuccess=true fallbackRecovered=true');
    }

    row = _mergeParsedRoomReactions(
      row,
      roomLikeCount,
      roomCommentCount,
      now,
    );
    _logRoomImportImageSource(
      productId: row.productId,
      title: row.itemName,
      roomPageImageUrl: roomPageImageUrl,
      apiImageUrl: apiEnrichedItem?.imageUrl ?? '',
      selectedUrl: row.imageUrl,
      selectedSource: _hasHttpImageUrl(roomPageImageUrl)
          ? 'room'
          : (_hasHttpImageUrl(apiEnrichedItem?.imageUrl ?? '')
                ? 'api'
                : 'placeholder'),
    );
    list.add(row);
    try {
      if (confirmDiskWrite) {
        await _saveAllMaybeMerged(
          list: list,
          workingMutableList: workingMutableList,
        );
      }
      _debugLogRoomImportSave(newId);
      if ((row.affiliateUrl ?? '').trim().isNotEmpty) {
        roomImportSaveLog('affiliateUrlSaved=true');
      }
      if (traceRoomSync) {
        roomSyncLog('保存成功（新規コレ済・一覧ベース）');
      }
    } catch (e, st) {
      if (traceRoomSync) {
        roomSyncError('保存失敗（新規コレ済・一覧ベース）', e, st);
      }
      rethrow;
    }
    return RoomCollectedPersistOutcome(
      kind: RoomCollectedPersistKind.insertedNewCollected,
      productId: newId,
    );
  }

  /// [persistRoomCollectedFromRoomPage] で `confirmDiskWrite: false` だった更新をまとめて永続化。
  Future<void> flushSharedWorkingMutableList(
    List<RakutenManagedProduct> workingMutableList,
  ) async {
    await _saveAllMaybeMerged(
      list: workingMutableList,
      workingMutableList: workingMutableList,
    );
  }

  Future<void> _saveAll(List<RakutenManagedProduct> items) async {
    if (kDemoModeEnabled) {
      return;
    }
    try {
      final encoded = jsonEncode(
        items.map((e) => e.toJson()).toList(growable: false),
      );
      final ok = await _prefs.setString(_keyList, encoded);
      if (!ok) {
        throw Exception('SharedPreferences の保存が拒否されました');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('ローカル保存に失敗しました: $e');
    }
  }
}
