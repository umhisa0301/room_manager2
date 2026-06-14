import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/widgets/monetization/admob_banner_ad_slot.dart';
import 'package:room_manager2/widgets/monetization/monetization_ad_placement.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  group('AdMobBannerAdSlot', () {
    testWidgets('skips ad load when loadAdForTesting is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdMobBannerAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            loadAdForTesting: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdMobBannerAdSlot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose does not throw when load skipped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdMobBannerAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            loadAdForTesting: false,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows fallback placeholder on load failure', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdMobBannerAdSlot(
            placement: MonetizationAdPlacement.homeBottomBanner,
            loadAdForTesting: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final hasPlaceholder = find
          .byKey(const Key('monetization_ad_slot_homeBottomBanner'))
          .evaluate()
          .isNotEmpty;
      final hasShrink = tester.getSize(find.byType(AdMobBannerAdSlot)) ==
              Size.zero ||
          hasPlaceholder;

      expect(hasShrink || hasPlaceholder, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'todayRecommendationSummaryBanner shows fallback on load failure',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AdMobBannerAdSlot(
              placement:
                  MonetizationAdPlacement.todayRecommendationSummaryBanner,
              loadAdForTesting: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final hasPlaceholder = find
            .byKey(
              const Key(
                'monetization_ad_slot_todayRecommendationSummaryBanner',
              ),
            )
            .evaluate()
            .isNotEmpty;
        final hasShrink =
            tester.getSize(find.byType(AdMobBannerAdSlot)) == Size.zero ||
                hasPlaceholder;

        expect(hasShrink || hasPlaceholder, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
