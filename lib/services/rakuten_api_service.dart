import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/rakuten_api_config.dart';
import '../models/rakuten_product_search_condition.dart';

/// 楽天商品検索APIとの通信だけを担当するサービス。
class RakutenApiService {
  static const String _baseUrl =
      'https://app.rakuten.co.jp/services/api/IchibaItem/Search/20220601';

  static const Duration _requestTimeout = Duration(seconds: 28);

  Future<Map<String, dynamic>> searchItems({
    required RakutenProductSearchCondition condition,
    int page = 1,
    int hits = 20,
  }) async {
    if (!RakutenApiConfig.hasValidAppId) {
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

  Future<Map<String, dynamic>> _searchItemsOnce({
    required RakutenProductSearchCondition condition,
    required int page,
    required int hits,
  }) async {
    final normalized = condition.normalized();
    final params = <String, String>{
      'format': 'json',
      'applicationId': RakutenApiConfig.applicationId.trim(),
      'page': '$page',
      'hits': '$hits',
    };

    final keywordTrimmed = normalized.keyword.trim();
    final genreTrimmed = normalized.genreId?.trim() ?? '';
    final shopTrimmed = normalized.shopCode?.trim() ?? '';
    final hasGenre = genreTrimmed.isNotEmpty;
    final hasShop = shopTrimmed.isNotEmpty;

    if (keywordTrimmed.isNotEmpty) {
      params['keyword'] = keywordTrimmed;
    } else if (!hasGenre && !hasShop) {
      throw Exception('楽天API: キーワードが空のときは genreId または shopCode が必要です。');
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
    if (hasGenre) {
      params['genreId'] = genreTrimmed;
    }
    final aff = RakutenApiConfig.affiliateId.trim();
    if (aff.isNotEmpty) {
      params['affiliateId'] = aff;
    }
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    if (kDebugMode) {
      debugPrint(
        '[Rakuten] request start page=$page hits=$hits '
        'keyword=${keywordTrimmed.isEmpty ? '(omit)' : keywordTrimmed} '
        'genreId=${hasGenre ? genreTrimmed : '-'} '
        'shopCode=${hasShop ? shopTrimmed : '-'} '
        'shopName=未送信(APIはshopCodeのみ)',
      );
    }

    http.Response response;
    try {
      response = await http
          .get(uri, headers: const {'User-Agent': 'RoomManager/1.0 (Flutter)'})
          .timeout(_requestTimeout);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Rakuten] network error page=$page: $e');
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint(
        '[Rakuten] response status=${response.statusCode} page=$page '
        'bytes=${response.bodyBytes.length}',
      );
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
      throw _RakutenApiTransportException(
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
    return bodyMap;
  }
}

/// 通信層のHTTPステータス（リトライ判定用）。同一ファイル内のみ。
class _RakutenApiTransportException implements Exception {
  _RakutenApiTransportException({
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
  if (e is _RakutenApiTransportException) {
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
