import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/rakuten_api_config.dart';
import '../models/genre_master.dart';

/// ジャンルAPIの実行モード（このファイル内のみ）。商品検索側と同じ思想。
enum _RakutenApiMode { openapi, legacy }

/// 楽天市場ジャンル検索API（IchibaGenre/Search）呼び出し。
///
/// 経路は [RakutenApiConfig.forceLegacy] と [RakutenApiConfig.isOpenApiEnabled] で決まる。
/// - **legacy**: `app.rakuten.co.jp` の 20140222。accessKey なし・OpenAPI 専用ヘッダーなし。
/// - **openapi**: `openapi.rakuten.co.jp` の 20140222。applicationId + accessKey + 必要ヘッダー。
class RakutenGenreApiService {
  static const String _baseUrlOpenApi =
      'https://openapi.rakuten.co.jp/ichibagt/api/IchibaGenre/Search/20140222';

  /// 旧ホスト（OpenAPI ドメインとは分離する）。
  static const String _baseUrlLegacy =
      'https://app.rakuten.co.jp/services/api/IchibaGenre/Search/20140222';

  static const Duration _requestTimeout = Duration(seconds: 28);

  static const String _userAgent = 'RoomManager/1.0 (Flutter)';

  /// [genreId] 指定でジャンル情報を取得し [GenreMaster] に変換する。
  ///
  /// 認証情報がない・[genreId] が 0 以下・APIエラー時は null。
  Future<GenreMaster?> fetchGenreMaster(int genreId) async {
    if (genreId <= 0) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] API skip: invalid genreId=$genreId');
      }
      return null;
    }
    if (!RakutenApiConfig.hasValidAppId) {
      if (kDebugMode) {
        debugPrint('楽天APIのアプリIDが未設定です。');
      }
      return null;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _fetchGenreMasterOnce(genreId);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[GenreMaster] fetchGenreMaster failed genreId=$genreId '
            'attempt=${attempt + 1}: $e',
          );
          debugPrint('$st');
        }
        final retriable = _isRetriableFailure(e);
        if (attempt == 0 && retriable) {
          if (kDebugMode) {
            debugPrint(
              '[GenreMaster] retrying genreId=$genreId after short delay…',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        if (kDebugMode) {
          debugPrint('楽天ジャンルAPI呼び出しに失敗しました: $e');
        }
        return null;
      }
    }
    return null;
  }

  /// モードに応じたベース URL（文字列のねじれを防ぐためここに集約）。
  static String _baseUrlForMode(_RakutenApiMode mode) {
    switch (mode) {
      case _RakutenApiMode.openapi:
        return _baseUrlOpenApi;
      case _RakutenApiMode.legacy:
        return _baseUrlLegacy;
    }
  }

  /// legacy は User-Agent のみ。openapi は Origin/Referer 付き。
  static Map<String, String> _headersForGenreMode(_RakutenApiMode mode) {
    switch (mode) {
      case _RakutenApiMode.openapi:
        return RakutenApiConfig.openApiHttpHeaders(userAgent: _userAgent);
      case _RakutenApiMode.legacy:
        return <String, String>{'User-Agent': _userAgent};
    }
  }

  /// 共通クエリにモード固有の差分（legacy では accessKey を付けない）。
  static Map<String, String> _paramsForGenreMode(
    _RakutenApiMode mode,
    Map<String, String> common,
  ) {
    final m = Map<String, String>.from(common);
    switch (mode) {
      case _RakutenApiMode.openapi:
        m['accessKey'] = RakutenApiConfig.accessKey.trim();
        return m;
      case _RakutenApiMode.legacy:
        m.remove('accessKey');
        return m;
    }
  }

  /// format / applicationId / genreId / genrePath まで（accessKey は含めない）。
  static Map<String, String> _buildCommonGenreParams(int genreId) {
    return <String, String>{
      'format': 'json',
      'applicationId': RakutenApiConfig.applicationId.trim(),
      'genreId': '$genreId',
      'genrePath': '1',
    };
  }

  static _RakutenApiMode _resolveGenreMode() {
    return RakutenApiConfig.isOpenApiEnabled
        ? _RakutenApiMode.openapi
        : _RakutenApiMode.legacy;
  }

  void _debugLogGenreRequest({
    required _RakutenApiMode mode,
    required int genreId,
  }) {
    if (!kDebugMode) return;
    final label = mode == _RakutenApiMode.openapi ? 'openapi' : 'legacy';
    final base = _baseUrlForMode(mode);
    final uri = Uri.parse(base);
    final openapiHeaders = mode == _RakutenApiMode.openapi;
    debugPrint(
      '[GenreMaster] API request mode=$label endpoint=IchibaGenre/Search/20140222 '
      'genreId=$genreId '
      'url=${uri.scheme}://${uri.host}${uri.path} '
      'forceLegacy=${RakutenApiConfig.forceLegacy} '
      'accessKeySent=${mode == _RakutenApiMode.openapi} '
      'openapiHeaders=$openapiHeaders',
    );
  }

  Future<GenreMaster?> _fetchGenreMasterOnce(int genreId) async {
    final common = _buildCommonGenreParams(genreId);
    var mode = _resolveGenreMode();
    _debugLogGenreRequest(mode: mode, genreId: genreId);

    var params = _paramsForGenreMode(mode, common);
    var headers = _headersForGenreMode(mode);
    final baseUrl = _baseUrlForMode(mode);

    http.Response response;
    try {
      response = await _getGenreResponse(
        baseUrl: baseUrl,
        params: params,
        headers: headers,
      );
    } catch (e) {
      // OpenAPI 選択時のみ DNS 失敗なら legacy へ1回だけ試す。
      if (mode == _RakutenApiMode.openapi && _isLikelyDnsFailure(e)) {
        if (kDebugMode) {
          debugPrint(
            '[GenreMaster] DNS失敗のため openapi→legacy に1回だけフォールバックします '
            '(本来のモードは [RAKUTEN_FORCE_LEGACY] / アクセスキーで制御してください)',
          );
        }
        mode = _RakutenApiMode.legacy;
        params = _paramsForGenreMode(mode, common);
        headers = _headersForGenreMode(mode);
        response = await _getGenreResponse(
          baseUrl: _baseUrlForMode(mode),
          params: params,
          headers: headers,
        );
      } else {
        if (kDebugMode) {
          debugPrint('[GenreMaster] API network error genreId=$genreId: $e');
          if (_isLikelyDnsFailure(e)) {
            debugPrint(
              '[GenreMaster] ヒント: 「Failed host lookup」は端末の名前解決(DNS)の問題です。',
            );
          }
        }
        rethrow;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[GenreMaster] API response genreId=$genreId status=${response.statusCode} '
        'bytes=${response.bodyBytes.length}',
      );
    }

    Map<String, dynamic>? bodyMap;
    try {
      final d = jsonDecode(response.body);
      if (d is Map<String, dynamic>) bodyMap = d;
    } catch (e) {
      if (response.statusCode != 200) {
        throw _GenreApiTransportException(
          statusCode: response.statusCode,
          message:
              '楽天ジャンルAPI呼び出しに失敗しました (${response.statusCode}): '
              '${_truncate(response.body)}',
        );
      }
      if (kDebugMode) {
        debugPrint('楽天ジャンルAPIレスポンス形式が不正です (JSON decode): $e');
      }
      return null;
    }

    if (response.statusCode != 200) {
      final detail = _rakutenErrorMessage(bodyMap) ?? _truncate(response.body);
      throw _GenreApiTransportException(
        statusCode: response.statusCode,
        message:
            '楽天ジャンルAPI呼び出しに失敗しました (${response.statusCode})'
            '${detail.isNotEmpty ? ': $detail' : ''}',
      );
    }

    if (bodyMap == null) {
      if (kDebugMode) {
        debugPrint('楽天ジャンルAPIレスポンス形式が不正です (object)');
      }
      return null;
    }

    final errMsg = _rakutenErrorMessage(bodyMap);
    if (errMsg != null) {
      if (kDebugMode) {
        debugPrint('楽天ジャンルAPI: $errMsg');
      }
      return null;
    }

    try {
      return _parseGenreMaster(bodyMap, rawJson: response.body);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('楽天ジャンルAPIレスポンス形式が不正です (parse): $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  Future<http.Response> _getGenreResponse({
    required String baseUrl,
    required Map<String, String> params,
    required Map<String, String> headers,
  }) {
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    if (kDebugMode) {
      final path = Uri.parse(baseUrl).path;
      final hasOrigin = headers.containsKey('Origin');
      final hasReferer = headers.containsKey('Referer');
      debugPrint(
        '[GenreMaster] GET $path … '
        'headers: User-Agent=set Origin=${hasOrigin ? 'set' : 'omit'} '
        'Referer=${hasReferer ? 'set' : 'omit'}',
      );
    }
    return http.get(uri, headers: headers).timeout(_requestTimeout);
  }

  /// 子ジャンル一覧（将来の再帰取得・プルダウン用に切り出し）。
  List<Map<String, dynamic>> _extractChildren(Map<String, dynamic> root) {
    return _mapList(root['children']);
  }

  /// 現在ジャンルブロック（`current` または `genre`）。
  Map<String, dynamic>? _extractCurrentGenre(Map<String, dynamic> root) {
    return _pickCurrent(root);
  }

  /// 親・祖先ブロック（`parents` 優先、なければ `ancestors`）。
  List<Map<String, dynamic>> _extractAncestors(Map<String, dynamic> root) {
    final parents = _mapList(root['parents']);
    final ancestors = _mapList(root['ancestors']);
    return parents.isNotEmpty ? parents : ancestors;
  }

  GenreMaster _parseGenreMaster(
    Map<String, dynamic> root, {
    required String rawJson,
  }) {
    final current = _extractCurrentGenre(root);
    if (current == null) {
      throw StateError('current genre block missing');
    }

    final genreId = _readInt(current['genreId']) ?? 0;
    final genreName = _readName(current);
    final level = _readLevel(current);

    final parentBlocks = _extractAncestors(root);

    final ancestorGenreIds = <int>[];
    final ancestorNames = <String>[];
    for (final p in parentBlocks) {
      final id = _readInt(p['genreId']);
      final name = _readName(p);
      if (id != null && id > 0) {
        ancestorGenreIds.add(id);
        ancestorNames.add(name);
      }
    }

    int parentGenreId = 0;
    if (ancestorGenreIds.isNotEmpty) {
      parentGenreId = ancestorGenreIds.last;
    }

    final children = _extractChildren(root);
    final childGenreIds = <int>[];
    for (final c in children) {
      final id = _readInt(c['genreId']);
      if (id != null && id > 0) childGenreIds.add(id);
    }

    final brothers = _mapList(root['brothers']);
    final siblings = _mapList(root['siblings']);
    final sibBlocks = brothers.isNotEmpty ? brothers : siblings;
    List<int>? siblingGenreIds;
    if (sibBlocks.isNotEmpty) {
      siblingGenreIds = <int>[];
      for (final s in sibBlocks) {
        final id = _readInt(s['genreId']);
        if (id != null && id > 0) siblingGenreIds.add(id);
      }
    }

    return GenreMaster(
      genreId: genreId,
      genreName: genreName.isEmpty ? 'ジャンル$genreId' : genreName,
      level: level,
      parentGenreId: parentGenreId,
      childGenreIds: childGenreIds,
      ancestorGenreIds: ancestorGenreIds,
      ancestorNames: ancestorNames,
      siblingGenreIds: siblingGenreIds,
      updatedAt: DateTime.now(),
      rawJson: rawJson,
    );
  }

  Map<String, dynamic>? _pickCurrent(Map<String, dynamic> root) {
    final c = root['current'];
    if (c is Map<String, dynamic>) return c;
    final g = root['genre'];
    if (g is Map<String, dynamic>) return g;
    return null;
  }

  List<Map<String, dynamic>> _mapList(Object? v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  int _readLevel(Map<String, dynamic> m) {
    final a = _readInt(m['genreLevel']);
    if (a != null) return a;
    final b = _readInt(m['level']);
    return b ?? 0;
  }

  String _readName(Map<String, dynamic> m) {
    final a = m['genreName']?.toString().trim();
    if (a != null && a.isNotEmpty) return a;
    final b = m['jaName']?.toString().trim();
    if (b != null && b.isNotEmpty) return b;
    return '';
  }

  int? _readInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }
}

bool _isLikelyDnsFailure(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('failed host lookup') ||
      s.contains('no address associated with hostname');
}

/// 通信層のHTTPステータス（リトライ判定用）。同一ファイル内のみ。
class _GenreApiTransportException implements Exception {
  _GenreApiTransportException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

bool _isRetriableFailure(Object e) {
  if (e is TimeoutException) return true;
  if (e is http.ClientException) return true;
  if (e is _GenreApiTransportException) {
    final c = e.statusCode;
    if (c == 429) return true;
    if (c >= 500 && c <= 504) return true;
    return false;
  }
  final s = e.toString().toLowerCase();
  if (s.contains('timeoutexception')) return true;
  if (s.contains('clientexception')) return true;
  if (s.contains('connection reset')) return true;
  if (s.contains('connection refused')) return true;
  if (s.contains('failed host lookup')) return true;
  if (s.contains('network is unreachable')) return true;
  return false;
}

String? _rakutenErrorMessage(Map<String, dynamic>? map) {
  if (map == null || !map.containsKey('error')) return null;
  final desc = map['error_description'];
  if (desc != null && desc.toString().trim().isNotEmpty) {
    return desc.toString();
  }
  final err = map['error'];
  if (err != null && err.toString().trim().isNotEmpty) {
    return err.toString();
  }
  return '不明なエラー';
}

String _truncate(String body, [int max = 160]) {
  final t = body.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}
