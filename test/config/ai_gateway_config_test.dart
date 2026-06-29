import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/ai_gateway_config.dart';

void main() {
  group('AiGatewayConfig', () {
    test('useRemotePostCommentGeneration is false when define omitted', () {
      if (const bool.fromEnvironment('USE_REMOTE_POST_COMMENT_GENERATION')) {
        return;
      }
      expect(AiGatewayConfig.useRemotePostCommentGeneration, isFalse);
    });

    test('appKey is empty when define omitted', () {
      if (const String.fromEnvironment('AI_GATEWAY_APP_KEY', defaultValue: '')
          .isNotEmpty) {
        return;
      }
      expect(AiGatewayConfig.appKey, isEmpty);
    });

    test('baseUrl defaults to Android emulator host when define omitted', () {
      const defineBaseUrl = String.fromEnvironment(
        'AI_GATEWAY_BASE_URL',
        defaultValue: '',
      );
      if (defineBaseUrl.isNotEmpty) {
        expect(AiGatewayConfig.baseUrl, defineBaseUrl);
        return;
      }
      expect(AiGatewayConfig.baseUrl, 'http://10.0.2.2:3000');
    });

    test('baseUrl matches AI_GATEWAY_BASE_URL when define is set', () {
      const defineBaseUrl = String.fromEnvironment(
        'AI_GATEWAY_BASE_URL',
        defaultValue: '',
      );
      if (defineBaseUrl.isEmpty) return;
      expect(AiGatewayConfig.baseUrl, defineBaseUrl);
    });
  });
}
