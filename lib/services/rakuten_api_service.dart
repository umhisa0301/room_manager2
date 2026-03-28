import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/rakuten_api_config.dart';

/// 楽天商品検索APIとの通信だけを担当するサービス。
class RakutenApiService {
  static const String _baseUrl =
      'https://app.rakuten.co.jp/services/api/IchibaItem/Search/20220601';

  Future<Map<String, dynamic>> searchItems({
    required String keyword,
    int page = 1,
    int hits = 20,
  }) async {
    if (!RakutenApiConfig.hasValidAppId) {
      throw Exception('楽天APIのアプリIDが未設定です。');
    }
    final params = <String, String>{
      'format': 'json',
      'applicationId': RakutenApiConfig.applicationId.trim(),
      'keyword': keyword,
      'page': '$page',
      'hits': '$hits',
    };
    final aff = RakutenApiConfig.affiliateId.trim();
    if (aff.isNotEmpty) {
      params['affiliateId'] = aff;
    }
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: const {'User-Agent': 'RoomManager/1.0 (Flutter)'},
    );
    Map<String, dynamic>? bodyMap;
    try {
      final d = jsonDecode(response.body);
      if (d is Map<String, dynamic>) {
        bodyMap = d;
      }
    } catch (_) {}

    if (response.statusCode != 200) {
      final detail = _rakutenErrorMessage(bodyMap) ?? _truncateBody(response.body);
      if (_isInvalidApplicationIdError(detail, httpStatus: response.statusCode)) {
        throw Exception(_invalidApplicationIdUserMessage(detail));
      }
      throw Exception(
        '楽天API呼び出しに失敗しました (${response.statusCode})'
        '${detail.isNotEmpty ? ': $detail' : ''}',
      );
    }
    if (bodyMap == null) {
      throw Exception('楽天APIレスポンス形式が不正です');
    }
    final errMsg = _rakutenErrorMessage(bodyMap);
    if (errMsg != null) {
      if (_isInvalidApplicationIdError(errMsg, httpStatus: response.statusCode)) {
        throw Exception(_invalidApplicationIdUserMessage(errMsg));
      }
      throw Exception('楽天API: $errMsg');
    }
    return bodyMap;
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

