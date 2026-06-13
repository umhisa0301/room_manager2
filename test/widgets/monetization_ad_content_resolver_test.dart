import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/widgets/monetization/monetization_ad_content_resolver.dart';
import 'package:room_manager2/widgets/monetization/monetization_ad_placement.dart';

void main() {
  group('resolveMonetizationAdContent', () {
    test('returns none when ads disabled', () {
      expect(
        resolveMonetizationAdContent(
          placement: MonetizationAdPlacement.homeBottomBanner,
          adsEnabled: false,
        ),
        MonetizationAdContentKind.none,
      );
      expect(
        resolveMonetizationAdContent(
          placement: MonetizationAdPlacement.todayRecommendationSummaryBanner,
          adsEnabled: false,
        ),
        MonetizationAdContentKind.none,
      );
    });

    test('homeBottomBanner uses admobBanner when ads enabled', () {
      expect(
        resolveMonetizationAdContent(
          placement: MonetizationAdPlacement.homeBottomBanner,
          adsEnabled: true,
        ),
        MonetizationAdContentKind.admobBanner,
      );
    });

    test('non-home placements stay placeholder when ads enabled', () {
      for (final placement in [
        MonetizationAdPlacement.todayRecommendationSummaryBanner,
        MonetizationAdPlacement.rakutenSearchNativeList,
        MonetizationAdPlacement.rewardedRecommendationRefresh,
      ]) {
        expect(
          resolveMonetizationAdContent(
            placement: placement,
            adsEnabled: true,
          ),
          MonetizationAdContentKind.placeholder,
        );
      }
    });
  });
}
