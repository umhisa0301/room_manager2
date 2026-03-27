/// 楽天API設定。
/// 本番キーは `--dart-define=RAKUTEN_APP_ID=...` で注入する。
class RakutenApiConfig {
  RakutenApiConfig._();

  static const String applicationId =
      String.fromEnvironment('RAKUTEN_APP_ID', defaultValue: '');

  static const String affiliateId =
      String.fromEnvironment('RAKUTEN_AFFILIATE_ID', defaultValue: '');

  static bool get hasValidAppId => applicationId.trim().isNotEmpty;
}

