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
import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';

/// 楽天検索由来の商品をローカル管理する（コレ候補・将来のコレ済・抽出結果などの拡張前提）。
class RakutenManagedProductRepository {
  RakutenManagedProductRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyList = 'rakuten_room_managed_products_v1';

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
      var rakutenGenreLoadLogCount = 0;
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
            if (kDebugMode && rakutenGenreLoadLogCount < 5) {
              rakutenGenreLoadLogCount++;
              debugPrint(
                '[RakutenGenre][LOAD] itemCode=${item.productId} '
                'loaded.genreId=${item.genreId} loaded.genreName=${item.genreName} '
                'loaded.resolvedGenreName=${item.resolvedGenreName}',
              );
            }
            out.add(item);
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[ROOMコレ診断] loadAll skip corrupt entry: $e\n$st');
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[ROOMコレ診断] loadAll 成功 parsed=${out.length} rawJsonList=${decoded.length}',
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

  /// 検索結果1件をコレ候補として保存。同一 [RakutenSearchItem.productId] が既にあれば何もしない（重複防止）。
  /// 新規追加した場合は true。
  Future<bool> registerCandidateFromSearchItem(RakutenSearchItem item) async {
    if (kDemoModeEnabled) {
      return false;
    }
    final list = List<RakutenManagedProduct>.from(loadAll());
    for (final e in list) {
      if (e.productId == item.productId) {
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
    final now = DateTime.now();
    await _mapProduct(productId, (e) {
      if (e.status != RakutenManagedProductStatus.candidate) {
        throw Exception('コレ候補ではない商品です');
      }
      return e.copyWith(
        status: RakutenManagedProductStatus.done,
        doneAt: now,
        updatedAt: now,
      );
    });
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
  }

  /// 検索一覧と同じルールの表示名（未分類・空 genreId は保存しない）。
  static String _resolvedGenreLabelForSearchItem(RakutenSearchItem item) {
    if (item.genreId.trim().isEmpty) return '';
    final s = RakutenProductGenreDisplay.resolve(
      apiGenreName: item.genreName,
      persistedGenreName: null,
      prefetchedGenreName: null,
      genreId: item.genreId,
      traceItemCode: null,
    ).trim();
    if (s.isEmpty || s == RakutenProductGenreDisplay.unknownLabel) {
      return '';
    }
    return s;
  }

  /// ROOM 商品ページ同期（単品・将来の一括の共通永続化）。
  ///
  /// **処理順**: roomUrl キー重複 → shopCode+itemCode 既存のマージ可否 → 新規コレ済插入。
  Future<RoomCollectedPersistOutcome> persistRoomCollectedFromRoomPage({
    required String roomUrlStoredCanonical,
    required String normalizedRoomUrlKey,
    required RakutenItemUrlParseResult parsedItem,
    String roomPageTitle = '',
    String roomPageImageUrl = '',
    RakutenSearchItem? apiEnrichedItem,
    bool traceRoomSync = false,
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

    if (traceRoomSync) {
      roomSyncLog('DB照合開始 normalizedRoomUrlKey=$key');
      roomSyncLog('roomUrl保存済み（同一キー先行検索）に該当するか確認');
    }

    final list = List<RakutenManagedProduct>.from(loadAll());
    for (final e in list) {
      final ek = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(e.roomUrl);
      if (ek.isNotEmpty && ek == key) {
        if (traceRoomSync) {
          roomSyncLog('既に同期済みのため登録処理をスキップします（roomPageAlreadySynced）');
          roomSyncLog('roomUrl保存済み: true（既存 productId=${e.productId}）');
          roomSyncLog('shopCode + itemCode 登録済み: (同一行)');
        }
        return RoomCollectedPersistOutcome(
          kind: RoomCollectedPersistKind.roomPageAlreadySynced,
          productId: e.productId,
        );
      }
    }

    if (traceRoomSync) {
      roomSyncLog('roomUrl保存済み: false（このキーでは未登録）');
    }

    final now = DateTime.now();

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

      final t = roomPageTitle.trim();
      final img = roomPageImageUrl.trim();
      var next = existing.copyWith(
        roomUrl: roomUrlStoredCanonical,
        itemUrl: parsedItem.rakutenUrl.isNotEmpty
            ? parsedItem.rakutenUrl
            : existing.itemUrl,
        shopCode: parsedItem.shopCode.isNotEmpty
            ? parsedItem.shopCode
            : existing.shopCode,
        itemName: t.isNotEmpty ? t : existing.itemName,
        imageUrl: img.isNotEmpty ? img : existing.imageUrl,
        updatedAt: now,
        status: RakutenManagedProductStatus.done,
        doneAt: existing.doneAt ?? now,
        isRoomSynced: true,
        roomSyncedAt: now,
      );

      final api = apiEnrichedItem;
      if (api != null) {
        final resolvedLabel = _resolvedGenreLabelForSearchItem(api);
        next = next.copyWith(
          itemName: api.itemName.trim().isNotEmpty ? api.itemName : next.itemName,
          itemPrice: api.itemPrice,
          affiliateUrl: api.affiliateUrl.trim().isNotEmpty
              ? api.affiliateUrl
              : next.affiliateUrl,
          shopName: api.shopName.trim().isNotEmpty ? api.shopName : next.shopName,
          shopUrl: api.shopUrl.trim().isNotEmpty ? api.shopUrl : next.shopUrl,
          genreId: api.genreId.trim().isNotEmpty ? api.genreId : next.genreId,
          genreName: api.genreName.trim().isNotEmpty ? api.genreName : next.genreName,
          resolvedGenreName: resolvedLabel.isNotEmpty
              ? resolvedLabel
              : next.resolvedGenreName,
          imageUrl: api.imageUrl.trim().isNotEmpty ? api.imageUrl : next.imageUrl,
        );
      }

      list[existingIndex] = next;
      try {
        await _saveAll(list);
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

    final apiNew = apiEnrichedItem;
    if (apiNew != null) {
      if (traceRoomSync) {
        roomSyncLog('未登録商品のため楽天APIで詳細取得済み行をコレ済として新規保存します');
        roomSyncLog('保存開始 保存種別: 新規コレ済登録（APIあり）');
      }
      final resolvedLabel = _resolvedGenreLabelForSearchItem(apiNew);
      final row = RakutenManagedProduct.fromSearchItem(
        apiNew,
        status: RakutenManagedProductStatus.done,
        now: now,
        resolvedGenreName: resolvedLabel,
      ).copyWith(
        roomUrl: roomUrlStoredCanonical,
        itemUrl: parsedItem.rakutenUrl.isNotEmpty
            ? parsedItem.rakutenUrl
            : apiNew.itemUrl,
        shopCode: parsedItem.shopCode.isNotEmpty
            ? parsedItem.shopCode
            : apiNew.shopCode,
        doneAt: now,
        isRoomSynced: true,
        roomSyncedAt: now,
      );
      list.add(row);
      try {
        await _saveAll(list);
        if (traceRoomSync) {
          roomSyncLog('保存成功（新規コレ済・APIあり）');
        }
      } catch (e, st) {
        if (traceRoomSync) {
          roomSyncError('保存失敗（新規コレ済・APIあり）', e, st);
        }
        rethrow;
      }
      return RoomCollectedPersistOutcome(
        kind: RoomCollectedPersistKind.insertedNewCollected,
        productId: row.productId,
      );
    }

    if (traceRoomSync) {
      roomSyncLog('API無し・最低限データで新規コレ済登録します');
      roomSyncLog('保存開始 保存種別: 新規コレ済登録（最低限）');
    }

    final title = roomPageTitle.trim().isNotEmpty
        ? roomPageTitle.trim()
        : '（ROOM同期）';
    final image = roomPageImageUrl.trim();
    final newId = parsedItem.itemPathSegment.trim().isNotEmpty
        ? parsedItem.itemPathSegment.trim()
        : parsedItem.compositeProductId;

    list.add(
      RakutenManagedProduct(
        productId: newId,
        itemName: title,
        itemPrice: 0,
        itemUrl: parsedItem.rakutenUrl,
        affiliateUrl: '',
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
      ),
    );
    try {
      await _saveAll(list);
      if (traceRoomSync) {
        roomSyncLog('保存成功（新規コレ済・最低限）');
      }
    } catch (e, st) {
      if (traceRoomSync) {
        roomSyncError('保存失敗（新規コレ済・最低限）', e, st);
      }
      rethrow;
    }
    return RoomCollectedPersistOutcome(
      kind: RoomCollectedPersistKind.insertedNewCollected,
      productId: newId,
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
