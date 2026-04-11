import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/genre_master.dart';
import '../services/rakuten_genre_api_service.dart';
import '../services/rakuten_genre_master_service.dart';

/// 楽天ジャンルマスターの永続キャッシュとAPI取得。
///
/// Firestore 等へ差し替える場合はこのクラスと同等のインターフェースを用意する。
class GenreMasterRepository {
  GenreMasterRepository({
    required SharedPreferences prefs,
    RakutenGenreApiService? apiService,
  }) : _prefs = prefs,
       _api = apiService ?? RakutenGenreApiService();

  final SharedPreferences _prefs;
  final RakutenGenreApiService _api;

  static const String _prefsKey = 'genre_master_cache_v1';

  /// 同一 [genreId] への同時 API を1本にまとめる。
  final Map<int, Future<GenreMaster?>> _inFlight = {};

  Map<String, dynamic> _readStore() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) {
        return Map<String, dynamic>.from(d);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] cache JSON corrupt, resetting: $e');
      }
    }
    return <String, dynamic>{};
  }

  Future<void> _writeStore(Map<String, dynamic> store) async {
    await _prefs.setString(_prefsKey, jsonEncode(store));
  }

  String _key(int genreId) => '$genreId';

  /// 保存済みジャンルを返す（なければ null）。
  Future<GenreMaster?> getGenreMasterById(int genreId) async {
    if (genreId <= 0) return null;
    final store = _readStore();
    final block = store[_key(genreId)];
    if (block is! Map<String, dynamic>) return null;
    try {
      return GenreMaster.fromJson(block);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] getGenreMasterById parse error id=$genreId: $e');
      }
      return null;
    }
  }

  Future<void> saveGenreMaster(GenreMaster genre) async {
    if (genre.genreId <= 0) return;
    final store = _readStore();
    store[_key(genre.genreId)] = genre.toJson();
    await _writeStore(store);
    RakutenGenreMasterService.instance.applyGenreMaster(genre);
    if (kDebugMode) {
      debugPrint('[GenreMaster] save complete genreId=${genre.genreId} name=${genre.genreName}');
    }
  }

  Future<void> saveGenreMasters(List<GenreMaster> genres) async {
    if (genres.isEmpty) return;
    final store = _readStore();
    for (final g in genres) {
      if (g.genreId <= 0) continue;
      store[_key(g.genreId)] = g.toJson();
    }
    await _writeStore(store);
    for (final g in genres) {
      if (g.genreId <= 0) continue;
      RakutenGenreMasterService.instance.applyGenreMaster(g);
    }
    if (kDebugMode) {
      debugPrint('[GenreMaster] batch save count=${genres.length}');
    }
  }

  /// キャッシュ済みの全件（永続ストアから復元）。
  Future<List<GenreMaster>> getAllCachedGenres() async {
    final store = _readStore();
    final out = <GenreMaster>[];
    for (final e in store.values) {
      if (e is! Map<String, dynamic>) continue;
      try {
        out.add(GenreMaster.fromJson(e));
      } catch (_) {}
    }
    out.sort((a, b) => a.genreId.compareTo(b.genreId));
    return out;
  }

  /// [parentGenreId] を親とする子をキャッシュから列挙（未取得は含まない）。
  Future<List<GenreMaster>> getCachedChildrenOf(int parentGenreId) async {
    if (parentGenreId <= 0) return const [];
    final all = await getAllCachedGenres();
    return all.where((g) => g.parentGenreId == parentGenreId).toList();
  }

  /// ルート直下（level==1 かつ親0）のキャッシュ一覧。未取得ジャンルは含まない。
  Future<List<GenreMaster>> getCachedTopLevelGenres() async {
    final all = await getAllCachedGenres();
    return all
        .where((g) => g.level <= 1 && g.parentGenreId == 0)
        .toList();
  }

  /// 未キャッシュなら API で取得して保存する。
  Future<GenreMaster?> fetchAndCacheGenreMaster(int genreId) async {
    if (genreId <= 0) return null;

    final cached = await getGenreMasterById(genreId);
    if (cached != null) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] cache hit genreId=$genreId name=${cached.genreName}');
      }
      return cached;
    }

    if (kDebugMode) {
      debugPrint('[GenreMaster] resolve start genreId=$genreId');
    }

    final existing = _inFlight[genreId];
    if (existing != null) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] coalesce in-flight genreId=$genreId');
      }
      return existing;
    }

    final future = _fetchAndStore(genreId);
    _inFlight[genreId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(genreId);
    }
  }

  Future<GenreMaster?> _fetchAndStore(int genreId) async {
    try {
      final gm = await _api.fetchGenreMaster(genreId);
      if (gm != null) {
        await saveGenreMaster(gm);
        if (kDebugMode) {
          debugPrint(
            '[GenreMaster] API stored genreId=$genreId name=${gm.genreName} '
            'children=${gm.childGenreIds.length}',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('[GenreMaster] API returned null genreId=$genreId');
        }
      }
      return gm;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] fetch error genreId=$genreId: $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  /// 日本語名。失敗時・未取得時は [genreId] の文字列を返し UI を壊さない。
  Future<String> getGenreName(int genreId) async {
    if (genreId <= 0) return '';
    final g = await fetchAndCacheGenreMaster(genreId);
    if (g != null && g.genreName.trim().isNotEmpty) {
      return g.genreName.trim();
    }
    return '$genreId';
  }

  /// 複数 ID をまとめて解決（同一IDの同時呼び出しは [fetchAndCacheGenreMaster] 側で抑制）。
  Future<void> prefetchGenreMasters(Set<int> genreIds) async {
    final ids = genreIds.where((e) => e > 0).toSet();
    if (ids.isEmpty) return;
    if (kDebugMode) {
      debugPrint('[GenreMaster] prefetch start unique=${ids.length}');
    }
    await Future.wait(ids.map(fetchAndCacheGenreMaster));
    if (kDebugMode) {
      debugPrint('[GenreMaster] prefetch done unique=${ids.length}');
    }
  }
}
