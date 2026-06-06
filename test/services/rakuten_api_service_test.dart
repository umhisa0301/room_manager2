import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';

void main() {
  const successBody = '{"Items":[],"count":0,"page":1}';
  const rateLimitBody =
      '{"error":"too_many_requests","error_description":"Rate limit is exceeded."}';

  group('RakutenApiService.searchItems rate limit retry', () {
    test('429 のときだけ1回リトライして成功すれば通常レスポンスを返す', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(rateLimitBody, 429);
        }
        return http.Response(successBody, 200);
      });
      final service = RakutenApiService(
        httpClient: client,
        rateLimitRetryDelay: Duration.zero,
      );

      final result = await service.searchItems(
        condition: const RakutenProductSearchCondition(keyword: '水筒'),
        page: 2,
      );

      expect(calls, 2);
      expect(result['Items'], isA<List<dynamic>>());
    });

    test('429 が2回続くときは失敗扱いになる', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(rateLimitBody, 429);
      });
      final service = RakutenApiService(
        httpClient: client,
        rateLimitRetryDelay: Duration.zero,
      );

      await expectLater(
        service.searchItems(
          condition: const RakutenProductSearchCondition(keyword: '水筒'),
          page: 2,
        ),
        throwsA(
          isA<RakutenApiTransportException>().having(
            (e) => e.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
      expect(calls, 2);
    });

    test('429 以外の HTTP エラーではリトライしない', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"error":"bad_request"}', 400);
      });
      final service = RakutenApiService(
        httpClient: client,
        rateLimitRetryDelay: Duration.zero,
      );

      await expectLater(
        service.searchItems(
          condition: const RakutenProductSearchCondition(keyword: '水筒'),
        ),
        throwsA(
          isA<RakutenApiTransportException>().having(
            (e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
      expect(calls, 1);
    });

    test('shopCode 検索でも 429 のときだけ1回リトライする', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(rateLimitBody, 429);
        }
        return http.Response(successBody, 200);
      });
      final service = RakutenApiService(
        httpClient: client,
        rateLimitRetryDelay: Duration.zero,
      );

      final result = await service.searchItems(
        condition: const RakutenProductSearchCondition(shopCode: 'k-kitchen'),
        page: 1,
      );

      expect(calls, 2);
      expect(result['Items'], isA<List<dynamic>>());
    });
  });
}
