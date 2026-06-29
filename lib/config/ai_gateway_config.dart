/// stepbyte-api-server AI Gateway 接続設定。
///
/// 本番 API キーはコミットしないこと。ローカル検証時は [appKey] に
/// サーバー側 `ROOM_MANAGEMENT_AI_GATEWAY_KEY` と同じ値を一時的に設定する。
///
/// - Android Emulator → ホスト PC: [baseUrl] は `http://10.0.2.2:3000`
/// - 実機 → ホスト PC: PC の LAN IP（例 `http://192.168.x.x:3000`）に変更
class AiGatewayConfig {
  AiGatewayConfig._();

  /// `true` のとき [RemotePostCommentGenerationService] を使う（[appKey] 必須）。
  static const bool useRemotePostCommentGeneration = false;

  /// stepbyte-api-server のベース URL（パスなし）。
  static const String baseUrl = 'http://10.0.2.2:3000';

  /// `x-stepbyte-app-key` ヘッダー値。空のときは Stub にフォールバック。
  static const String appKey = '';
}
