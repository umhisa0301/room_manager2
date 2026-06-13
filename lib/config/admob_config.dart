import 'dart:io';

/// AdMob 広告ユニット ID 設定（テストのみ）。
///
/// App ID は Android [AndroidManifest.xml] / 将来の iOS Info.plist にのみ配置する。
/// 本番 ID は Monetization-5 以降で差し替える。
abstract final class AdMobConfig {
  /// Google 公式テスト用バナー広告ユニット ID（Android）。
  static const String testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Google 公式テスト用バナー広告ユニット ID（iOS）。
  static const String testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  // TODO(Monetization-5): 本番バナー広告ユニット ID をプラットフォーム別に追加

  /// [MonetizationAdPlacement.homeBottomBanner] 用のバナー広告ユニット ID。
  static String? homeBottomBannerAdUnitId() {
    if (Platform.isAndroid) {
      return testAndroidBannerAdUnitId;
    }
    if (Platform.isIOS) {
      return testIosBannerAdUnitId;
    }
    return null;
  }
}
