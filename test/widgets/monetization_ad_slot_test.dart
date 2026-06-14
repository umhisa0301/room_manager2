import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/widgets/monetization/admob_banner_ad_slot.dart';
import 'package:room_manager2/widgets/monetization/monetization_ad_slot.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  group('MonetizationAdSlot', () {
    testWidgets('returns SizedBox.shrink when adsEnabledOverride is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            adsEnabledOverride: false,
          ),
        ),
      );

      expect(find.byType(MonetizationAdSlot), findsOneWidget);
      expect(find.byKey(const Key('monetization_ad_slot_homeBottomBanner')),
          findsNothing);
      expect(tester.getSize(find.byType(MonetizationAdSlot)), Size.zero);
    });

    testWidgets('shows AdMob banner slot when adsEnabledOverride is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            adsEnabledOverride: true,
            loadAdMobForTesting: false,
          ),
        ),
      );

      expect(find.byType(AdMobBannerAdSlot), findsOneWidget);
      expect(
        find.byKey(const Key('monetization_ad_slot_homeBottomBanner')),
        findsNothing,
      );
    });

    testWidgets(
      'MONETIZATION_ENABLED=false / ADS_ENABLED=true equivalent hides slot',
      (tester) async {
        final flags = resolveMonetizationFlags(
          monetizationEnabled: false,
          adsEnabled: true,
          subscriptionEnabled: false,
          freePlanLimitsEnabled: false,
          proPlanEnabled: false,
        );
        expect(flags.isAdsEnabled, isFalse);

        await tester.pumpWidget(
          _wrap(
            MonetizationAdSlot(
              placement: MonetizationAdPlacement.homeBottomBanner,
              adsEnabledOverride: flags.isAdsEnabled,
            ),
          ),
        );

        expect(
          find.byKey(const Key('monetization_ad_slot_homeBottomBanner')),
          findsNothing,
        );
      },
    );

    testWidgets('homeBottomBanner routes to AdMob banner slot in debug mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            adsEnabledOverride: true,
            loadAdMobForTesting: false,
          ),
        ),
      );

      expect(find.byType(AdMobBannerAdSlot), findsOneWidget);
      expect(find.text('Sponsored placeholder'), findsNothing);
    });

    testWidgets('todayRecommendationSummaryBanner routes to AdMob banner slot',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement:
                MonetizationAdPlacement.todayRecommendationSummaryBanner,
            adsEnabledOverride: true,
            loadAdMobForTesting: false,
          ),
        ),
      );

      expect(find.byType(AdMobBannerAdSlot), findsOneWidget);
      expect(find.text('広告枠'), findsNothing);
    });

    testWidgets('rakutenSearchNativeList shows native placeholder with ad label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.rakutenSearchNativeList,
            adsEnabledOverride: true,
          ),
        ),
      );

      expect(
        find.byKey(const Key('monetization_ad_slot_rakutenSearchNativeList')),
        findsOneWidget,
      );
      expect(find.text('広告'), findsOneWidget);
      expect(find.text('広告枠'), findsOneWidget);
      expect(find.text('Sponsored placeholder'), findsOneWidget);
    });

    testWidgets('placeholder does not respond to tap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.rakutenSearchNativeList,
            adsEnabledOverride: true,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('monetization_ad_slot_rakutenSearchNativeList')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not create AdMob banner slot when ads disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            adsEnabledOverride: false,
          ),
        ),
      );

      expect(find.byType(AdMobBannerAdSlot), findsNothing);
    });

    testWidgets('compile-time ADS_ENABLED=false uses shrink by default', (
      tester,
    ) async {
      expect(MonetizationFlags.isAdsEnabled, isFalse);

      await tester.pumpWidget(
        _wrap(
          const MonetizationAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
          ),
        ),
      );

      expect(
        find.byKey(const Key('monetization_ad_slot_homeBottomBanner')),
        findsNothing,
      );
      expect(find.byType(AdMobBannerAdSlot), findsNothing);
    });
  });

  group('RakutenSearchNativeAdListIndex', () {
    test('does not insert ad when product count is below threshold', () {
      expect(
        RakutenSearchNativeAdListIndex.shouldInsertNativeAd(
          productCount: 4,
          adsEnabled: true,
        ),
        isFalse,
      );
      expect(
        RakutenSearchNativeAdListIndex.virtualItemCount(
          productCount: 4,
          adsEnabled: true,
        ),
        4,
      );
    });

    test('inserts one virtual slot after fifth product when ads enabled', () {
      expect(
        RakutenSearchNativeAdListIndex.virtualItemCount(
          productCount: 5,
          adsEnabled: true,
        ),
        6,
      );
      expect(
        RakutenSearchNativeAdListIndex.isAdVirtualIndex(
          virtualIndex: 5,
          productCount: 5,
          adsEnabled: true,
        ),
        isTrue,
      );
      expect(
        RakutenSearchNativeAdListIndex.productIndexForVirtualIndex(
          virtualIndex: 4,
          productCount: 5,
          adsEnabled: true,
        ),
        4,
      );
      expect(
        RakutenSearchNativeAdListIndex.productIndexForVirtualIndex(
          virtualIndex: 6,
          productCount: 6,
          adsEnabled: true,
        ),
        5,
      );
    });

    test('does not insert ad when ads disabled', () {
      expect(
        RakutenSearchNativeAdListIndex.shouldInsertNativeAd(
          productCount: 10,
          adsEnabled: false,
        ),
        isFalse,
      );
      expect(
        RakutenSearchNativeAdListIndex.productIndexForVirtualIndex(
          virtualIndex: 7,
          productCount: 10,
          adsEnabled: false,
        ),
        7,
      );
    });
  });
}
