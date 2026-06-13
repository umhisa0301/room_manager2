import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/admob_config.dart';

void main() {
  group('resolveAdMobEnvironment', () {
    test('debug build always uses test environment', () {
      expect(
        resolveAdMobEnvironment(
          useProductionAdIds: false,
          productionAndroidBannerConfigured: false,
          productionIosBannerConfigured: false,
          isAndroid: true,
          isIos: false,
        ),
        AdMobEnvironment.test,
      );
    });

    test('profile-equivalent build uses test environment even if production configured',
        () {
      expect(
        resolveAdMobEnvironment(
          useProductionAdIds: false,
          productionAndroidBannerConfigured: true,
          productionIosBannerConfigured: true,
          isAndroid: true,
          isIos: false,
        ),
        AdMobEnvironment.test,
      );
    });

    test('release android uses production when configured', () {
      expect(
        resolveAdMobEnvironment(
          useProductionAdIds: true,
          productionAndroidBannerConfigured: true,
          productionIosBannerConfigured: false,
          isAndroid: true,
          isIos: false,
        ),
        AdMobEnvironment.production,
      );
    });

    test('release android without production ID returns null', () {
      expect(
        resolveAdMobEnvironment(
          useProductionAdIds: true,
          productionAndroidBannerConfigured: false,
          productionIosBannerConfigured: false,
          isAndroid: true,
          isIos: false,
        ),
        isNull,
      );
    });

    test('release ios uses production when configured', () {
      expect(
        resolveAdMobEnvironment(
          useProductionAdIds: true,
          productionAndroidBannerConfigured: false,
          productionIosBannerConfigured: true,
          isAndroid: false,
          isIos: true,
        ),
        AdMobEnvironment.production,
      );
    });

    test('release without platform match returns null', () {
      expect(
        resolveAdMobEnvironment(
          useProductionAdIds: true,
          productionAndroidBannerConfigured: true,
          productionIosBannerConfigured: true,
          isAndroid: false,
          isIos: false,
        ),
        isNull,
      );
    });
  });

  group('resolveHomeBottomBannerAdUnitId', () {
    const testAndroid = 'ca-app-pub-3940256099942544/6300978111';
    const testIos = 'ca-app-pub-3940256099942544/2934735716';
    const prodAndroid = 'ca-app-pub-1111111111111111/2222222222';
    const prodIos = 'ca-app-pub-3333333333333333/4444444444';

    test('null environment returns null', () {
      expect(
        resolveHomeBottomBannerAdUnitId(
          environment: null,
          isAndroid: true,
          isIos: false,
          testAndroidBannerAdUnitId: testAndroid,
          testIosBannerAdUnitId: testIos,
          productionAndroidBannerAdUnitId: prodAndroid,
          productionIosBannerAdUnitId: prodIos,
        ),
        isNull,
      );
    });

    test('test environment on android returns test android unit', () {
      expect(
        resolveHomeBottomBannerAdUnitId(
          environment: AdMobEnvironment.test,
          isAndroid: true,
          isIos: false,
          testAndroidBannerAdUnitId: testAndroid,
          testIosBannerAdUnitId: testIos,
          productionAndroidBannerAdUnitId: prodAndroid,
          productionIosBannerAdUnitId: prodIos,
        ),
        testAndroid,
      );
    });

    test('production environment on android returns production android unit', () {
      expect(
        resolveHomeBottomBannerAdUnitId(
          environment: AdMobEnvironment.production,
          isAndroid: true,
          isIos: false,
          testAndroidBannerAdUnitId: testAndroid,
          testIosBannerAdUnitId: testIos,
          productionAndroidBannerAdUnitId: prodAndroid,
          productionIosBannerAdUnitId: prodIos,
        ),
        prodAndroid,
      );
    });

    test('unsupported platform returns null', () {
      expect(
        resolveHomeBottomBannerAdUnitId(
          environment: AdMobEnvironment.test,
          isAndroid: false,
          isIos: false,
          testAndroidBannerAdUnitId: testAndroid,
          testIosBannerAdUnitId: testIos,
          productionAndroidBannerAdUnitId: prodAndroid,
          productionIosBannerAdUnitId: prodIos,
        ),
        isNull,
      );
    });
  });

  group('AdMobConfig production guard', () {
    test('kReleaseAdMobIdsEnabled is true after Monetization-6B setup', () {
      expect(AdMobConfig.kReleaseAdMobIdsEnabled, isTrue);
    });

    test('production android banner is configured with non-test unit ID', () {
      expect(AdMobConfig.isProductionAndroidBannerAdUnitIdConfigured, isTrue);
      expect(AdMobConfig.productionAndroidBannerAdUnitId, isNotEmpty);
      expect(
        AdMobConfig.productionAndroidBannerAdUnitId,
        'ca-app-pub-3311460421786551/5377056540',
      );
      expect(
        AdMobConfig.productionAndroidBannerAdUnitId,
        isNot(AdMobConfig.testAndroidBannerAdUnitId),
      );
    });
  });
}
