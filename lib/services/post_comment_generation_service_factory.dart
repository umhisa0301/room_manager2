import '../config/ai_gateway_config.dart';
import 'post_comment_generation_service.dart';
import 'remote_post_comment_generation_service.dart';

/// 投稿文生成サービスの生成（Stub / Remote 切り替え）。
abstract final class PostCommentGenerationServiceFactory {
  PostCommentGenerationServiceFactory._();

  static PostCommentGenerationService create({
    bool? useRemote,
    String? baseUrl,
    String? appKey,
  }) {
    final remoteEnabled =
        useRemote ?? AiGatewayConfig.useRemotePostCommentGeneration;
    final key = (appKey ?? AiGatewayConfig.appKey).trim();

    if (remoteEnabled && key.isNotEmpty) {
      final url = (baseUrl ?? AiGatewayConfig.baseUrl).trim();
      return RemotePostCommentGenerationService(
        baseUri: Uri.parse(url),
        apiKey: key,
      );
    }

    return const StubPostCommentGenerationService();
  }
}
