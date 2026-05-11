import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/rakuten_api_config.dart';
import '../models/rakuten_product_search_condition.dart';

/// 商品検索の実行モード（このファイル内のみ）。
enum _RakutenApiMode { openapi, legacy }

/// 楽天商品検索APIとの通信だけを担当するサービス。
///
/// 経路は [RakutenApiConfig.forceLegacy] と [RakutenApiConfig.isOpenApiEnabled] で決まる。
/// - **legacy**: `app.rakuten.co.jp` の 2022-06-01。accessKey なし・OpenAPI 専用ヘッダーなし。
/// - **openapi**: `openapi.rakuten.co.jp` の 2026-04-01。applicationId + accessKey + 必要ヘッダー。
class RakutenApiService {
  static const String _proxyPath = '/rakuten';
  static const String _baseUrlOpenApi =
      'https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260401';

  /// 旧ホスト（OpenAPI ドメインとは分離する）。
  static const String _baseUrlLegacy =
      'https://app.rakuten.co.jp/services/api/IchibaItem/Search/20220601';

  static const Duration _requestTimeout = Duration(seconds: 28);

  static const String _userAgent = 'RoomManager/1.0 (Flutter)';

  Future<Map<String, dynamic>> searchItems({
    required RakutenProductSearchCondition condition,
    int page = 1,
    int hits = 20,
  }) async {
    if (!RakutenApiConfig.useProxyForItemSearch && !RakutenApiConfig.hasValidAppId) {
      throw Exception('楽天APIのアプリIDが未設定です。');
    }
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _searchItemsOnce(
          condition: condition,
          page: page,
          hits: hits,
        );
      } catch (e, st) {
        lastError = e;
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] searchItems failed page=$page attempt=${attempt + 1}: $e',
          );
          debugPrint('$st');
        }
        final retriable = _isRetriableFailure(e);
        if (attempt == 0 && retriable) {
          if (kDebugMode) {
            debugPrint('[Rakuten] retrying page=$page after short delay…');
          }
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        rethrow;
      }
    }
    throw lastError!;
  }

  /// モードに応じたベース URL（ねじれないようここだけを参照する）。
  static String _baseUrlForMode(_RakutenApiMode mode) {
    switch (mode) {
      case _RakutenApiMode.openapi:
        return _baseUrlOpenApi;
      case _RakutenApiMode.legacy:
        return _baseUrlLegacy;
    }
  }

  /// legacy では User-Agent のみ。OpenAPI では Origin/Referer 付き。
  static Map<String, String> _headersForSearchMode(_RakutenApiMode mode) {
    switch (mode) {
      case _RakutenApiMode.openapi:
        return RakutenApiConfig.openApiHttpHeaders(userAgent: _userAgent);
      case _RakutenApiMode.legacy:
        return <String, String>{'User-Agent': _userAgent};
    }
  }

  /// 共通クエリにモード固有の差分を適用（legacy では accessKey を含めない）。
  static Map<String, String> _paramsForSearchMode(
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

  /// プロキシ向け（VPS）では認証情報は付与しない。
  static Map<String, String> _paramsForProxy(Map<String, String> common) {
    final m = Map<String, String>.from(common);
    m.remove('applicationId');
    m.remove('accessKey');
    m.remove('affiliateId');
    return m;
  }

  /// キーワード・ジャンル・店舗・価格・レビュー・affiliate までを組み立てる（accessKey は含めない）。
  static Map<String, String> _buildCommonSearchParams({
    required RakutenProductSearchCondition normalized,
    required int page,
    required int hits,
  }) {
    final params = <String, String>{
      'format': 'json',
      'applicationId': RakutenApiConfig.applicationId.trim(),
      'page': '$page',
      'hits': '$hits',
    };

    final keywordTrimmed = normalized.keyword.trim();
    final genreTrimmed = normalized.genreId?.trim() ?? '';
    final shopTrimmed = normalized.shopCode?.trim() ?? '';
    final itemTrimmed = normalized.itemCode?.trim() ?? '';
    final hasGenre = genreTrimmed.isNotEmpty;
    final hasShop = shopTrimmed.isNotEmpty;
    final hasItem = itemTrimmed.isNotEmpty;

    if (keywordTrimmed.isNotEmpty) {
      params['keyword'] = keywordTrimmed;
    } else if (!hasGenre && !hasShop && !hasItem) {
      throw Exception(
        '楽天API: キーワードが空のときは genreId・shopCode・itemCode のいずれかが必要です。',
      );
    }

    if (normalized.minPrice != null) {
      params['minPrice'] = '${normalized.minPrice}';
    }
    if (normalized.maxPrice != null) {
      params['maxPrice'] = '${normalized.maxPrice}';
    }
    if (normalized.excludeKeyword.isNotEmpty) {
      params['NGKeyword'] = normalized.excludeKeyword;
    }
    if (normalized.minReviewCount != null) {
      params['minReviewCount'] = '${normalized.minReviewCount}';
    }
    if (normalized.minReviewAverage != null) {
      params['minReviewAverage'] = '${normalized.minReviewAverage}';
    }
    if (hasShop) {
      params['shopCode'] = shopTrimmed;
    }
    if (hasItem) {
      params['itemCode'] = itemTrimmed;
    }
    if (hasGenre) {
      params['genreId'] = genreTrimmed;
    }
    final sortTrimmed = normalized.sort?.trim() ?? '';
    if (sortTrimmed.isNotEmpty) {
      params['sort'] = sortTrimmed;
    }
    if (!RakutenApiConfig.useProxyForItemSearch) {
      final aff = RakutenApiConfig.affiliateId.trim();
      if (aff.isNotEmpty) {
        params['affiliateId'] = aff;
      }
    }
    return params;
  }

  static _RakutenApiMode _resolveSearchMode() {
    return RakutenApiConfig.isOpenApiEnabled
        ? _RakutenApiMode.openapi
        : _RakutenApiMode.legacy;
  }

  void _debugLogSearchPlan({
    required _RakutenApiMode mode,
    required int page,
    required int hits,
    required String keywordTrimmed,
    required bool hasGenre,
    required String genreTrimmed,
    required bool hasShop,
    required String shopTrimmed,
    required bool hasItem,
    required String itemTrimmed,
  }) {
    if (!kDebugMode) return;
    final proxy = RakutenApiConfig.useProxyForItemSearch;
    final label = mode == _RakutenApiMode.openapi ? 'openapi' : 'legacy';
    final base = proxy
        ? '${RakutenApiConfig.proxyBaseUrl.trim()}$_proxyPath'
        : _baseUrlForMode(mode);
    final uri = Uri.parse(base);
    final openapiHeaders = !proxy && mode == _RakutenApiMode.openapi;
    debugPrint(
      '[Rakuten] request start mode=${proxy ? 'proxy' : label} page=$page hits=$hits '
      'url=${uri.scheme}://${uri.host}${uri.path} '
      'useProxy=${RakutenApiConfig.useProxyForItemSearch} '
      'forceLegacy=${RakutenApiConfig.forceLegacy} '
      'accessKeySent=${!proxy && mode == _RakutenApiMode.openapi} '
      'openapiHeaders=$openapiHeaders '
      'keyword=${keywordTrimmed.isEmpty ? '(omit)' : keywordTrimmed} '
      'genreId=${hasGenre ? genreTrimmed : '-'} '
      'shopCode=${hasShop ? shopTrimmed : '-'} '
      'itemCode=${hasItem ? itemTrimmed : '-'} '
      'shopName=未送信(APIはshopCodeのみ)',
    );
  }

  Future<Map<String, dynamic>> _searchItemsOnce({
    required RakutenProductSearchCondition condition,
    required int page,
    required int hits,
  }) async {
    final normalized = condition.normalized();
    final common = _buildCommonSearchParams(
      normalized: normalized,
      page: page,
      hits: hits,
    );

    final keywordTrimmed = normalized.keyword.trim();
    final genreTrimmed = normalized.genreId?.trim() ?? '';
    final shopTrimmed = normalized.shopCode?.trim() ?? '';
    final itemTrimmed = normalized.itemCode?.trim() ?? '';
    final hasGenre = genreTrimmed.isNotEmpty;
    final hasShop = shopTrimmed.isNotEmpty;
    final hasItem = itemTrimmed.isNotEmpty;

    var mode = _resolveSearchMode();
    final useProxy = RakutenApiConfig.useProxyForItemSearch;
    _debugLogSearchPlan(
      mode: mode,
      page: page,
      hits: hits,
      keywordTrimmed: keywordTrimmed,
      hasGenre: hasGenre,
      genreTrimmed: genreTrimmed,
      hasShop: hasShop,
      shopTrimmed: shopTrimmed,
      hasItem: hasItem,
      itemTrimmed: itemTrimmed,
    );

    var params = useProxy ? _paramsForProxy(common) : _paramsForSearchMode(mode, common);
    var headers = <String, String>{'User-Agent': _userAgent};
    final baseUrl = useProxy
        ? '${RakutenApiConfig.proxyBaseUrl.trim()}$_proxyPath'
        : _baseUrlForMode(mode);

    http.Response response;
    try {
      response = await _getSearchResponse(
        baseUrl: baseUrl,
        params: params,
        headers: headers,
      );
    } catch (e) {
      if (useProxy) {
        if (kDebugMode) {
          debugPrint('[Rakuten] proxy network error page=$page: $e');
        }
        rethrow;
      }
      // OpenAPI 選択時のみ DNS 失敗なら legacy へ1回だけ試す（経路を明示ログ）。
      if (mode == _RakutenApiMode.openapi && _isLikelyDnsFailure(e)) {
        if (kDebugMode) {
          debugPrint(
            '[Rakuten] DNS失敗のため openapi→legacy に1回だけフォールバックします '
            '(本来のモード解決は [RAKUTEN_FORCE_LEGACY] / アクセスキーで制御してください)',
          );
        }
        mode = _RakutenApiMode.legacy;
        params = _paramsForSearchMode(mode, common);
        headers = _headersForSearchMode(mode);
        response = await _getSearchResponse(
          baseUrl: _baseUrlForMode(mode),
          params: params,
          headers: headers,
        );
      } else {
        if (kDebugMode) {
          debugPrint('[Rakuten] network error page=$page: $e');
          if (_isLikelyDnsFailure(e)) {
            debugPrint(
              '[Rakuten] ヒント: 「Failed host lookup」はキー不正ではなく端末の名前解決(DNS)の問題です。'
              'Android の「プライベートDNS」設定、Wi‑Fi、エミュレータの再作成を確認してください。',
            );
          }
        }
        rethrow;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[Rakuten] response status=${response.statusCode} page=$page '
        'bytes=${response.bodyBytes.length}',
      );
      debugPrint('[RECOMMEND_TRACE] apiStatus=${response.statusCode}');
    }

    Map<String, dynamic>? bodyMap;
    try {
      final d = jsonDecode(response.body);
      if (d is Map<String, dynamic>) {
        bodyMap = d;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Rakuten] json decode error page=$page: $e');
      }
    }

    if (response.statusCode != 200) {
      final detail =
          _rakutenErrorMessage(bodyMap) ?? _truncateBody(response.body);
      if (_isInvalidApplicationIdError(
        detail,
        httpStatus: response.statusCode,
      )) {
        throw Exception(_invalidApplicationIdUserMessage(detail));
      }
      throw RakutenApiTransportException(
        statusCode: response.statusCode,
        message:
            '楽天API呼び出しに失敗しました (${response.statusCode})'
            '${detail.isNotEmpty ? ': $detail' : ''}',
      );
    }

    if (bodyMap == null) {
      if (kDebugMode) {
        debugPrint(
          '[Rakuten] parse error: body is not a JSON object page=$page',
        );
      }
      throw Exception('楽天APIレスポンス形式が不正です');
    }
    // 旧VPS応答互換: { ok: true, data: <rakutenResponse> } を受けた場合は data を展開する。
    final wrapped = bodyMap['data'];
    if (wrapped is Map<String, dynamic>) {
      bodyMap = wrapped;
    } else if (wrapped is Map) {
      bodyMap = Map<String, dynamic>.from(wrapped);
    }
    final errMsg = _rakutenErrorMessage(bodyMap);
    if (errMsg != null) {
      if (kDebugMode) {
        debugPrint('[Rakuten] API logical error page=$page: $errMsg');
      }
      if (_isInvalidApplicationIdError(
        errMsg,
        httpStatus: response.statusCode,
      )) {
        throw Exception(_invalidApplicationIdUserMessage(errMsg));
      }
      throw Exception('楽天API: $errMsg');
    }
    if (kDebugMode) {
      final items = bodyMap['Items'];
      final rawCount = items is List ? items.length : 0;
      debugPrint('[RECOMMEND_TRACE] rawCount=$rawCount');
    }
    return bodyMap;
  }

  Future<http.Response> _getSearchResponse({
    required String baseUrl,
    required Map<String, String> params,
    required Map<String, String> headers,
  }) {
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    if (kDebugMode) {
      final path = Uri.parse(baseUrl).path;
      final hasOrigin = headers.containsKey('Origin');
      final hasReferer = headers.containsKey('Referer');
      final usesProxy = path.endsWith(_proxyPath);
      debugPrint(
        '[Rakuten] GET $path … '
        'proxy=${usesProxy ? 'yes' : 'no'} '
        'headers: User-Agent=set Origin=${hasOrigin ? 'set' : 'omit'} '
        'Referer=${hasReferer ? 'set' : 'omit'}',
      );
    }
    return http.get(uri, headers: headers).timeout(_requestTimeout);
  }
}

bool _isLikelyDnsFailure(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('failed host lookup') ||
      s.contains('no address associated with hostname');
}

/// 通信層のHTTPステータス（リトライ判定・ROOM補完の 429 検知など）。
class RakutenApiTransportException implements Exception {
  RakutenApiTransportException({
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
  if (e is RakutenApiTransportException) {
    final c = e.statusCode;
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

String _truncateBody(String body, [int max = 200]) {
  final t = body.trim();
  if (t.isEmpty) return '';
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

bool _isInvalidApplicationIdError(String detail, {required int httpStatus}) {
  final d = detail.toLowerCase();
  if (d.contains('specify valid applicationid')) return true;
  if (httpStatus == 400 &&
      (d.contains('applicationid') || d.contains('application id'))) {
    return true;
  }
  return false;
}

String _invalidApplicationIdUserMessage(String technicalDetail) {
  return '楽天のアプリIDが無効です（$technicalDetail）。'
      '楽天ウェブサービスで発行した「アプリID」を、'
      'ターミナルなら flutter run --dart-define=RAKUTEN_APP_ID=（アプリID） のように渡し、'
      'Cursor/VS Code なら環境変数 RAKUTEN_APP_ID を設定するか .vscode/launch.json の toolArgs を編集してから '
      'アプリを再ビルド（ホットリロードでは反映されません）してください。';
}
