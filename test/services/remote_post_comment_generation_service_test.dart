import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/services/post_comment_generation_exception.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
import 'package:room_manager2/services/remote_post_comment_generation_service.dart';

void main() {
  final input = PostCommentGenerationInput(
    itemName: 'テスト商品',
    recommendationReason: '売れ筋',
    itemPrice: 1500,
    reviewAverage: 4.5,
    reviewCount: 10,
    styleSettings: PostStyleSettings.defaults(),
  );

  const successResponse = {
    'success': true,
    'appId': 'room_management',
    'taskId': 'room_post_comment',
    'promptVersion': 'v1',
    'data': {
      'body': '毎日の家事がちょっと楽になるキッチングッズです。',
      'hashtags': ['#キッチン用品', '#時短家事', '#楽天ROOM'],
      'full_text':
          '毎日の家事がちょっと楽になるキッチングッズです。\n\n#キッチン用品 #時短家事 #楽天ROOM',
    },
    'meta': {
      'truncated': false,
      'sanitized': false,
      'generationMode': 'mock',
    },
  };

  http.Response successHttpResponse() {
    return http.Response.bytes(
      utf8.encode(jsonEncode(successResponse)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  group('RemotePostCommentGenerationService', () {
    test('returns PostCommentGenerationResult on success response', () async {
      final client = MockClient((request) async => successHttpResponse());
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      final result = await service.generate(input);

      expect(result.body, '毎日の家事がちょっと楽になるキッチングッズです。');
      expect(result.hashtags, ['#キッチン用品', '#時短家事', '#楽天ROOM']);
      expect(
        result.fullText,
        '毎日の家事がちょっと楽になるキッチングッズです。\n\n#キッチン用品 #時短家事 #楽天ROOM',
      );
      expect(result.displayText, contains('#楽天ROOM'));
    });

    test('POSTs to /api/ai/generate', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return successHttpResponse();
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      await service.generate(input);

      expect(capturedUri?.path, '/api/ai/generate');
    });

    test('sends x-stepbyte-app-key header', () async {
      String? capturedKey;
      final client = MockClient((request) async {
        capturedKey = request.headers['x-stepbyte-app-key'];
        return successHttpResponse();
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'room-test-key',
        client: client,
      );

      await service.generate(input);

      expect(capturedKey, 'room-test-key');
    });

    test('request body includes appId and taskId', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody =
            Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return successHttpResponse();
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      await service.generate(input);

      expect(capturedBody?['appId'], 'room_management');
      expect(capturedBody?['taskId'], 'room_post_comment');
    });

    test('throws PostCommentGenerationException when success is false', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'OUTPUT_TOO_LONG',
              'message': 'Generated body exceeded max_body_chars.',
            },
          }),
          400,
        );
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        service.generate(input),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'OUTPUT_TOO_LONG'),
        ),
      );
    });

    test('throws PostCommentGenerationException on HTTP 500', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'INTERNAL_ERROR',
              'message': 'Internal server error.',
            },
          }),
          500,
        );
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        service.generate(input),
        throwsA(isA<PostCommentGenerationException>()),
      );
    });

    test('throws PostCommentGenerationException on timeout', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return successHttpResponse();
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
        timeout: Duration.zero,
      );

      await expectLater(
        service.generate(input),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'TIMEOUT'),
        ),
      );
    });

    test('throws PostCommentGenerationException on invalid JSON', () async {
      final client = MockClient((_) async {
        return http.Response('not-json', 200);
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        service.generate(input),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'INVALID_JSON'),
        ),
      );
    });

    test('throws PostCommentGenerationException on network error', () async {
      final client = MockClient((_) async {
        throw http.ClientException('Connection refused');
      });
      final service = RemotePostCommentGenerationService(
        baseUri: Uri.parse('http://10.0.2.2:3000'),
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        service.generate(input),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'NETWORK_ERROR'),
        ),
      );
    });
  });
}
