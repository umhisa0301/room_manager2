import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob の実行環境（テスト広告 / 本番広告）。
enum AdMobEnvironment {
  test,
  production,
}

/// AdMob 広告ユニット ID 設定。
///
/// - **App ID**（`ca-app-pub-…~…`）は Android [strings.xml] / 将来の iOS Info.plist のみ。
/// - **バナー広告ユニット ID**（`ca-app-pub-…/…`）は本ファイルのみ。
/// - テスト ID と本番 ID は定数で明確に分離する。
/// - 本番 ID は [kReleaseAdMobIdsEnabled] を true にし、各 production 定数へ実値を入れたときのみ有効。
abstract final class AdMobConfig {
  /// 本番 AdMob ID を release ビルドで使うか。
  ///
  /// false のままでは release でも広告ユニット ID は返さず、SDK 初期化もスキップする。
  /// 本番 ID を strings.xml / 下記 production 定数へ設定したあと true にする。
  static const bool kReleaseAdMobIdsEnabled = true;

  // --- Google 公式テスト ID（変更しない） ---

  static const String testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';

  static const String testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static const String testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  /// おすすめコレ画面下部バナー用 Google 公式テスト ID（Android）。
  static const String testAndroidTodayRecommendationBannerAdUnitId =
      testAndroidBannerAdUnitId;

  /// おすすめコレ画面下部バナー用 Google 公式テスト ID（iOS）。
  static const String testIosTodayRecommendationBannerAdUnitId =
      testIosBannerAdUnitId;

  // --- 本番 ID（AdMob 管理画面の実値を入れる。ダミー値は入れない） ---

  static const String productionAndroidBannerAdUnitId =
      'ca-app-pub-3311460421786551/5377056540';

  /// おすすめコレ画面下部バナー用本番 ID（AdMob 管理画面で作成後に設定）。
  static const String productionAndroidTodayRecommendationBannerAdUnitId =
      'ca-app-pub-3311460421786551/5377056540';

  static const String productionIosTodayRecommendationBannerAdUnitId = '';

  // TODO(Monetization-6A): iOS 対応時に Info.plist の GADApplicationIdentifier と
  // 本番バナー広告ユニット ID を設定する。
  static const String productionIosBannerAdUnitId = '';

  /// Android 本番バナー広告ユニット ID が利用可能か。
  static bool get isProductionAndroidBannerAdUnitIdConfigured =>
      kReleaseAdMobIdsEnabled && productionAndroidBannerAdUnitId.isNotEmpty;

  /// iOS 本番バナー広告ユニット ID が利用可能か。
  static bool get isProductionIosBannerAdUnitIdConfigured =>
      kReleaseAdMobIdsEnabled && productionIosBannerAdUnitId.isNotEmpty;

  /// Android おすすめコレ下部バナー本番 ID が利用可能か。
  static bool
      get isProductionAndroidTodayRecommendationBannerAdUnitIdConfigured =>
          kReleaseAdMobIdsEnabled &&
          productionAndroidTodayRecommendationBannerAdUnitId.isNotEmpty;

  /// iOS おすすめコレ下部バナー本番 ID が利用可能か。
  static bool get isProductionIosTodayRecommendationBannerAdUnitIdConfigured =>
      kReleaseAdMobIdsEnabled &&
      productionIosTodayRecommendationBannerAdUnitId.isNotEmpty;

  /// 現ビルドで広告ロードに使う環境。未設定 release では `null`（ロードしない）。
  static AdMobEnvironment? resolveEnvironment() {
    return resolveAdMobEnvironment(
      useProductionAdIds: kReleaseMode && !kProfileMode,
      productionAndroidBannerConfigured:
          isProductionAndroidBannerAdUnitIdConfigured,
      productionIosBannerConfigured: isProductionIosBannerAdUnitIdConfigured,
      isAndroid: Platform.isAndroid,
      isIos: Platform.isIOS,
    );
  }

  /// [MonetizationAdPlacement.homeBottomBanner] 用のバナー広告ユニット ID。
  static String? homeBottomBannerAdUnitId() {
    return resolveHomeBottomBannerAdUnitId(
      environment: resolveEnvironment(),
      isAndroid: Platform.isAndroid,
      isIos: Platform.isIOS,
      testAndroidBannerAdUnitId: testAndroidBannerAdUnitId,
      testIosBannerAdUnitId: testIosBannerAdUnitId,
      productionAndroidBannerAdUnitId: productionAndroidBannerAdUnitId,
      productionIosBannerAdUnitId: productionIosBannerAdUnitId,
    );
  }

  /// おすすめコレ画面下部バナー用の広告ユニット ID。
  static String? todayRecommendationSummaryBannerAdUnitId() {
    return resolveTodayRecommendationSummaryBannerAdUnitId(
      environment: resolveTodayRecommendationBannerEnvironment(),
      isAndroid: Platform.isAndroid,
      isIos: Platform.isIOS,
      testAndroidBannerAdUnitId: testAndroidTodayRecommendationBannerAdUnitId,
      testIosBannerAdUnitId: testIosTodayRecommendationBannerAdUnitId,
      productionAndroidBannerAdUnitId:
          productionAndroidTodayRecommendationBannerAdUnitId,
      productionIosBannerAdUnitId: productionIosTodayRecommendationBannerAdUnitId,
    );
  }

  /// おすすめコレ下部バナー用の AdMob 実行環境。
  static AdMobEnvironment? resolveTodayRecommendationBannerEnvironment() {
    return resolveAdMobEnvironment(
      useProductionAdIds: kReleaseMode && !kProfileMode,
      productionAndroidBannerConfigured:
          isProductionAndroidTodayRecommendationBannerAdUnitIdConfigured,
      productionIosBannerConfigured:
          isProductionIosTodayRecommendationBannerAdUnitIdConfigured,
      isAndroid: Platform.isAndroid,
      isIos: Platform.isIOS,
    );
  }

  /// debug ログ用（ID 本体は出さない）。
  static String get environmentLogLabel {
    final env = resolveEnvironment();
    if (env == null) {
      return 'unconfigured-release';
    }
    return env.name;
  }
}

/// 単体テスト用の純粋関数。
///
/// [useProductionAdIds] は Flutter の release ビルドのみ true（profile は false）。
AdMobEnvironment? resolveAdMobEnvironment({
  required bool useProductionAdIds,
  required bool productionAndroidBannerConfigured,
  required bool productionIosBannerConfigured,
  required bool isAndroid,
  required bool isIos,
}) {
  if (!useProductionAdIds) {
    return AdMobEnvironment.test;
  }
  if (isAndroid && productionAndroidBannerConfigured) {
    return AdMobEnvironment.production;
  }
  if (isIos && productionIosBannerConfigured) {
    return AdMobEnvironment.production;
  }
  return null;
}

/// 単体テスト用の純粋関数。
String? resolveHomeBottomBannerAdUnitId({
  required AdMobEnvironment? environment,
  required bool isAndroid,
  required bool isIos,
  required String testAndroidBannerAdUnitId,
  required String testIosBannerAdUnitId,
  required String productionAndroidBannerAdUnitId,
  required String productionIosBannerAdUnitId,
}) {
  if (environment == null) {
    return null;
  }
  if (isAndroid) {
    return environment == AdMobEnvironment.production
        ? productionAndroidBannerAdUnitId
        : testAndroidBannerAdUnitId;
  }
  if (isIos) {
    return environment == AdMobEnvironment.production
        ? productionIosBannerAdUnitId
        : testIosBannerAdUnitId;
  }
  return null;
}

/// 単体テスト用の純粋関数。
String? resolveTodayRecommendationSummaryBannerAdUnitId({
  required AdMobEnvironment? environment,
  required bool isAndroid,
  required bool isIos,
  required String testAndroidBannerAdUnitId,
  required String testIosBannerAdUnitId,
  required String productionAndroidBannerAdUnitId,
  required String productionIosBannerAdUnitId,
}) {
  if (environment == null) {
    return null;
  }
  if (isAndroid) {
    return environment == AdMobEnvironment.production
        ? productionAndroidBannerAdUnitId
        : testAndroidBannerAdUnitId;
  }
  if (isIos) {
    return environment == AdMobEnvironment.production
        ? productionIosBannerAdUnitId
        : testIosBannerAdUnitId;
  }
  return null;
}
