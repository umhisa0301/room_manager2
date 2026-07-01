import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_generation_limit.dart';

void main() {
  group('PostCommentGenerationLimit', () {
    test('allows generation when enforcement is off', () {
      final state = resolvePostCommentGenerationAvailability(
        usedCount: 5,
        enforcementEnabled: false,
      );
      expect(state.allowed, isTrue);
      expect(state.reasonCode, isNull);
    });

    test('blocks when daily limit reached', () {
      final state = resolvePostCommentGenerationAvailability(
        usedCount: 1,
        enforcementEnabled: true,
      );
      expect(state.allowed, isFalse);
      expect(state.reasonCode, kPostCommentDailyLimitReasonCode);
      expect(state.usedCount, 1);
      expect(state.limit, kPostCommentGenerationDailyLimit);
    });

    test('allows first generation of the day', () {
      final state = resolvePostCommentGenerationAvailability(
        usedCount: 0,
        enforcementEnabled: true,
      );
      expect(state.allowed, isTrue);
      expect(state.reasonCode, isNull);
    });

    test('daily limit blocked message matches spec', () {
      expect(
        buildPostCommentGenerationDailyLimitBlockedMessage(),
        '本日のAI生成回数の上限に達しました。明日またお試しください。',
      );
    });
  });
}
