/// 楽天API設定。
/// 本番キーは `--dart-define=RAKUTEN_APP_ID=...` で注入する。
/// ジャンル検索APIには [accessKey] も必要（楽天ウェブサービスのアプリ管理画面で確認）。
class RakutenApiConfig {
  RakutenApiConfig._();

  static const String applicationId = String.fromEnvironment(
    'RAKUTEN_APP_ID',
    defaultValue: '',
  );

  /// 楽天市場ジャンル検索API等でアプリIDと併用。
  static const String accessKey = String.fromEnvironment(
    'RAKUTEN_ACCESS_KEY',
    defaultValue: '',
  );

  static const String affiliateId = String.fromEnvironment(
    'RAKUTEN_AFFILIATE_ID',
    defaultValue: '',
  );

  static bool get hasValidAppId => applicationId.trim().isNotEmpty;

  static bool get hasValidAccessKey => accessKey.trim().isNotEmpty;

  /// リクエストクエリに `affiliateId` を付与するか（ビルド時の define 由来）。
  static bool get requestIncludesAffiliateId => affiliateId.trim().isNotEmpty;
}
