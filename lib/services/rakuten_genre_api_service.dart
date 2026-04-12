import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/rakuten_api_config.dart';
import '../models/genre_master.dart';

/// 楽天市場ジャンル検索API（IchibaGenre/Search）呼び出し。
///
/// 認証は [RakutenApiConfig.applicationId] と [RakutenApiConfig.accessKey]。
class RakutenGenreApiService {
  static const String _baseUrl =
      'https://openapi.rakuten.co.jp/ichibagt/api/IchibaGenre/Search/20140222';

  static const Duration _requestTimeout = Duration(seconds: 28);

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
        debugPrint('[GenreMaster] API skip: RAKUTEN_APP_ID unset');
      }
      return null;
    }
    if (!RakutenApiConfig.hasValidAccessKey) {
      if (kDebugMode) {
        debugPrint(
          '[GenreMaster] API skip: RAKUTEN_ACCESS_KEY unset '
          '(ジャンルAPIにはアプリIDとアクセスキーの両方が必要です)',
        );
      }
      return null;
    }

    final params = <String, String>{
      'format': 'json',
      'applicationId': RakutenApiConfig.applicationId.trim(),
      'accessKey': RakutenApiConfig.accessKey.trim(),
      'genreId': '$genreId',
      'genrePath': '1',
    };
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    if (kDebugMode) {
      debugPrint('[GenreMaster] API request genreId=$genreId');
    }

    http.Response response;
    try {
      response = await http
          .get(uri, headers: RakutenApiConfig.openApiHttpHeaders())
          .timeout(_requestTimeout);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] API network error genreId=$genreId: $e');
        debugPrint('$st');
      }
      return null;
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
      if (kDebugMode) {
        debugPrint('[GenreMaster] JSON decode error genreId=$genreId: $e');
      }
      return null;
    }

    if (bodyMap == null) return null;

    final errMsg = _rakutenErrorMessage(bodyMap);
    if (errMsg != null) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] API logical error genreId=$genreId: $errMsg');
      }
      return null;
    }

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          '[GenreMaster] HTTP ${response.statusCode} genreId=$genreId '
          '${_truncate(response.body)}',
        );
      }
      return null;
    }

    try {
      return _parseGenreMaster(bodyMap, rawJson: response.body);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GenreMaster] parse error genreId=$genreId: $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  GenreMaster _parseGenreMaster(
    Map<String, dynamic> root, {
    required String rawJson,
  }) {
    final current = _pickCurrent(root);
    if (current == null) {
      throw StateError('current genre block missing');
    }

    final genreId = _readInt(current['genreId']) ?? 0;
    final genreName = _readName(current);
    final level = _readLevel(current);

    final parents = _mapList(root['parents']);
    final ancestors = _mapList(root['ancestors']);
    final parentBlocks = parents.isNotEmpty ? parents : ancestors;

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

    final children = _mapList(root['children']);
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
