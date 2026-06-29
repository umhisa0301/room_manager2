import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_api_response_parser.dart';
import 'package:room_manager2/services/post_comment_generation_exception.dart';

void main() {
  group('PostCommentApiResponseParser', () {
    const parser = PostCommentApiResponseParser();

    test('parses success response into PostCommentGenerationResult', () {
      final result = parser.parse({
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
          'body_char_count': 28,
          'hashtag_count': 3,
          'total_char_count': 52,
          'truncated': false,
        },
        'error': null,
      });

      expect(result.body, '毎日の家事がちょっと楽になるキッチングッズです。');
      expect(result.hashtags, ['#キッチン用品', '#時短家事', '#楽天ROOM']);
      expect(
        result.fullText,
        '毎日の家事がちょっと楽になるキッチングッズです。\n\n#キッチン用品 #時短家事 #楽天ROOM',
      );
      expect(result.truncated, isFalse);
    });

    test('accepts hashtags with hash prefix as-is', () {
      final result = parser.parse({
        'success': true,
        'data': {
          'body': '本文',
          'hashtags': ['#tag1', 'tag2'],
        },
      });

      expect(result.hashtags, ['#tag1', 'tag2']);
    });

    test('reflects meta.truncated', () {
      final result = parser.parse({
        'success': true,
        'data': {
          'body': '本文',
          'hashtags': [],
        },
        'meta': {
          'truncated': true,
        },
      });

      expect(result.truncated, isTrue);
    });

    test('throws PostCommentGenerationException on success false', () {
      expect(
        () => parser.parse({
          'success': false,
          'data': null,
          'error': {
            'code': 'OUTPUT_TOO_LONG',
            'message': 'Generated body exceeded max_body_chars.',
          },
        }),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'OUTPUT_TOO_LONG')
              .having(
                (e) => e.message,
                'message',
                'Generated body exceeded max_body_chars.',
              ),
        ),
      );
    });

    test('throws PostCommentGenerationException when data.body is missing', () {
      expect(
        () => parser.parse({
          'success': true,
          'data': {
            'hashtags': ['#tag'],
          },
        }),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'MISSING_BODY'),
        ),
      );
    });

    test('treats missing data.hashtags as empty array', () {
      final result = parser.parse({
        'success': true,
        'data': {
          'body': '本文のみ',
        },
      });

      expect(result.hashtags, isEmpty);
    });

    test('throws on invalid data object', () {
      expect(
        () => parser.parse({
          'success': true,
          'data': 'invalid',
        }),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
    });

    test('throws UNKNOWN_ERROR when error details are missing', () {
      expect(
        () => parser.parse({'success': false}),
        throwsA(
          isA<PostCommentGenerationException>()
              .having((e) => e.code, 'code', 'UNKNOWN_ERROR'),
        ),
      );
    });
  });
}
