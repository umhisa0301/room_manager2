import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/ai_gateway_config.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
import 'package:room_manager2/services/post_comment_generation_service_factory.dart';
import 'package:room_manager2/services/remote_post_comment_generation_service.dart';

void main() {
  group('PostCommentGenerationServiceFactory', () {
    test('returns Stub with default config when dart-define omitted', () {
      if (AiGatewayConfig.useRemotePostCommentGeneration) return;
      final service = PostCommentGenerationServiceFactory.create();
      expect(service, isA<StubPostCommentGenerationService>());
    });

    test(
      'returns Remote with default config when remote enabled and appKey set',
      () {
        if (!AiGatewayConfig.useRemotePostCommentGeneration) return;
        if (AiGatewayConfig.appKey.trim().isEmpty) return;
        final service = PostCommentGenerationServiceFactory.create();
        expect(service, isA<RemotePostCommentGenerationService>());
      },
    );

    test(
      'returns Stub with default config when remote enabled but appKey empty',
      () {
        if (!AiGatewayConfig.useRemotePostCommentGeneration) return;
        if (AiGatewayConfig.appKey.trim().isNotEmpty) return;
        final service = PostCommentGenerationServiceFactory.create();
        expect(service, isA<StubPostCommentGenerationService>());
      },
    );

    test('returns Stub when useRemote is false', () {
      final service = PostCommentGenerationServiceFactory.create(
        useRemote: false,
        appKey: 'any-key',
      );

      expect(service, isA<StubPostCommentGenerationService>());
      expect(service, isNot(isA<RemotePostCommentGenerationService>()));
    });

    test('returns Remote when useRemote is true and appKey is set', () {
      final service = PostCommentGenerationServiceFactory.create(
        useRemote: true,
        baseUrl: 'http://10.0.2.2:3000',
        appKey: 'test-key',
      );

      expect(service, isA<RemotePostCommentGenerationService>());
    });

    test('returns Stub when useRemote is true but appKey is empty', () {
      final service = PostCommentGenerationServiceFactory.create(
        useRemote: true,
        appKey: '',
      );

      expect(service, isA<StubPostCommentGenerationService>());
    });

    test('returns Stub when useRemote is true but appKey is whitespace', () {
      final service = PostCommentGenerationServiceFactory.create(
        useRemote: true,
        appKey: '   ',
      );

      expect(service, isA<StubPostCommentGenerationService>());
    });
  });
}
