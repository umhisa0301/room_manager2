import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';

/// 楽天検索由来の商品をローカル管理する（コレ候補・将来のコレ済・抽出結果などの拡張前提）。
class RakutenManagedProductRepository {
  RakutenManagedProductRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyList = 'rakuten_room_managed_products_v1';

  /// [status] に一致する商品だけを返す（更新日時の新しい順）。
  List<RakutenManagedProduct> loadByStatus(RakutenManagedProductStatus status) {
    final list =
        loadAll().where((e) => e.status == status).toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 保存済みの一覧を読み込む。破損時は空。
  List<RakutenManagedProduct> loadAll() {
    try {
      final jsonStr = _prefs.getString(_keyList);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return [];

      final out = <RakutenManagedProduct>[];
      for (final entry in decoded) {
        final map = entry is Map<String, dynamic> ? entry : null;
        final item = RakutenManagedProduct.fromJson(map);
        if (item != null) out.add(item);
      }
      return out;
    } catch (_) {
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

  /// 検索結果1件をコレ候補として保存。同一 [RakutenSearchItem.productId] が既にあれば何もしない（重複防止）。
  /// 新規追加した場合は true。
  Future<bool> registerCandidateFromSearchItem(RakutenSearchItem item) async {
    final list = List<RakutenManagedProduct>.from(loadAll());
    for (final e in list) {
      if (e.productId == item.productId) {
        return false;
      }
    }
    list.add(
      RakutenManagedProduct.fromSearchItem(
        item,
        status: RakutenManagedProductStatus.candidate,
      ),
    );
    await _saveAll(list);
    return true;
  }

  Future<void> _mapProduct(
    String productId,
    RakutenManagedProduct Function(RakutenManagedProduct e) mapper,
  ) async {
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

  /// コレ候補を永続化一覧から削除する（再検索からの登録を再度可能にする）。
  Future<void> removeCandidateProduct(String productId) async {
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

  Future<void> _saveAll(List<RakutenManagedProduct> items) async {
    try {
      final encoded =
          jsonEncode(items.map((e) => e.toJson()).toList(growable: false));
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
