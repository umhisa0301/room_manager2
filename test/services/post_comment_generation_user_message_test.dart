import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_generation_exception.dart';
import 'package:room_manager2/services/post_comment_generation_user_message.dart';

void main() {
  group('postCommentGenerationUserMessage', () {
    test('RATE_LIMIT_EXCEEDED', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'RATE_LIMIT_EXCEEDED',
            'Daily limit.',
          ),
        ),
        kPostCommentGenerationDailyLimitMessage,
      );
    });

    test('daily_limit_reached', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'daily_limit_reached',
            'Client limit.',
          ),
        ),
        kPostCommentGenerationDailyLimitMessage,
      );
    });

    test('product_already_generated', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'product_already_generated',
            'Already generated.',
          ),
        ),
        kPostCommentGenerationProductAlreadyGeneratedMessage,
      );
    });

    test('AI_GENERATION_DISABLED', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'AI_GENERATION_DISABLED',
            'Disabled.',
          ),
        ),
        kPostCommentGenerationDisabledMessage,
      );
    });

    test('503 via httpStatus', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'UNKNOWN_ERROR',
            'Unavailable.',
            httpStatus: 503,
          ),
        ),
        kPostCommentGenerationDisabledMessage,
      );
    });

    test('TIMEOUT', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException('TIMEOUT', 'Timed out.'),
        ),
        kPostCommentGenerationNetworkMessage,
      );
    });

    test('NETWORK_ERROR', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'NETWORK_ERROR',
            'Connection refused.',
          ),
        ),
        kPostCommentGenerationNetworkMessage,
      );
    });

    test('LLM_REQUEST_FAILED with timeout message', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'LLM_REQUEST_FAILED',
            'Request timed out after 30000ms.',
          ),
        ),
        kPostCommentGenerationNetworkMessage,
      );
    });

    test('LLM_REQUEST_FAILED with Timeout message (case insensitive)', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'LLM_REQUEST_FAILED',
            'OpenAI Timeout error.',
          ),
        ),
        kPostCommentGenerationNetworkMessage,
      );
    });

    test('LLM_REQUEST_FAILED without timeout uses generic message', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'LLM_REQUEST_FAILED',
            'Invalid response from model.',
          ),
        ),
        kPostCommentGenerationGenericErrorMessage,
      );
    });

    test('generic fallback', () {
      expect(
        postCommentGenerationUserMessage(
          const PostCommentGenerationException(
            'OUTPUT_TOO_LONG',
            'Too long.',
          ),
        ),
        kPostCommentGenerationGenericErrorMessage,
      );
    });
  });
}
