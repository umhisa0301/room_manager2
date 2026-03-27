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
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'format': 'json',
        'applicationId': RakutenApiConfig.applicationId,
        'affiliateId': RakutenApiConfig.affiliateId,
        'keyword': keyword,
        'page': '$page',
        'hits': '$hits',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('楽天API呼び出しに失敗しました (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('楽天APIレスポンス形式が不正です');
    }
    return decoded;
  }
}

