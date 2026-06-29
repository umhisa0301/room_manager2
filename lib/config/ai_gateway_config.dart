/// stepbyte-api-server AI Gateway 接続設定。
///
/// 本番 API キーはコミットしないこと。ローカル検証時は `--dart-define` で渡す。
///
/// 例:
/// ```text
/// flutter run \
///   --dart-define=USE_REMOTE_POST_COMMENT_GENERATION=true \
///   --dart-define=AI_GATEWAY_APP_KEY=your-local-key \
///   --dart-define=AI_GATEWAY_BASE_URL=http://10.0.2.2:3000
/// ```
///
/// - Android Emulator → ホスト PC: [baseUrl] は `http://10.0.2.2:3000`
/// - 実機 → ホスト PC: PC の LAN IP（例 `http://192.168.x.x:3000`）を [AI_GATEWAY_BASE_URL] に指定
class AiGatewayConfig {
  AiGatewayConfig._();

  /// `true` のとき [RemotePostCommentGenerationService] を使う（[appKey] 必須）。
  static const bool useRemotePostCommentGeneration = bool.fromEnvironment(
    'USE_REMOTE_POST_COMMENT_GENERATION',
  );

  /// stepbyte-api-server のベース URL（パスなし）。
  static const String baseUrl = String.fromEnvironment(
    'AI_GATEWAY_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// `x-stepbyte-app-key` ヘッダー値。空のときは Stub にフォールバック。
  static const String appKey = String.fromEnvironment(
    'AI_GATEWAY_APP_KEY',
    defaultValue: '',
  );
}
