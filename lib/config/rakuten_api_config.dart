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

  /// `openapi.rakuten.co.jp` は `Origin` / `Referer` 無しだと 403
  /// `REQUEST_CONTEXT_BODY_HTTP_REFERRER_MISSING` になることがある。
  /// 管理画面の「許可されたWebサイト」と揃える場合は `--dart-define` で上書き。
  static const String httpOrigin = String.fromEnvironment(
    'RAKUTEN_HTTP_ORIGIN',
    defaultValue: 'https://www.rakuten.co.jp/',
  );
  static const String httpReferer = String.fromEnvironment(
    'RAKUTEN_HTTP_REFERER',
    defaultValue: 'https://www.rakuten.co.jp/',
  );

  static bool get hasValidAppId => applicationId.trim().isNotEmpty;

  static bool get hasValidAccessKey => accessKey.trim().isNotEmpty;

  /// リクエストクエリに `affiliateId` を付与するか（ビルド時の define 由来）。
  static bool get requestIncludesAffiliateId => affiliateId.trim().isNotEmpty;

  /// 楽天 OpenAPI（商品検索・ジャンル検索等）用の共通 HTTP ヘッダー。
  static Map<String, String> openApiHttpHeaders({
    String userAgent = 'RoomManager/1.0 (Flutter)',
  }) {
    final o = httpOrigin.trim().isEmpty
        ? 'https://www.rakuten.co.jp/'
        : httpOrigin.trim();
    final r = httpReferer.trim().isEmpty
        ? 'https://www.rakuten.co.jp/'
        : httpReferer.trim();
    return <String, String>{
      'User-Agent': userAgent,
      'Origin': o,
      'Referer': r,
    };
  }
}
