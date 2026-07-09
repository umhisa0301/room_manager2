import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/firebase_config.dart';
import 'package:room_manager2/models/analytics_params.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/services/analytics_service.dart';
import 'package:room_manager2/services/post_comment_generation_exception.dart';

void main() {
  group('NoOpAnalyticsService', () {
    test('does not throw for phase 1 events', () async {
      const service = NoOpAnalyticsService();
      await service.setConsentGranted(true);
      await service.logAppOpen();
      await service.logLegalConsentAccepted();
      await service.logOnboardingRoute(
        route: FirebaseConfig.onboardingRouteHome,
      );
    });

    test('does not throw for phase 2 events', () async {
      const service = NoOpAnalyticsService();
      await service.logSearchExecuted(
        source: AnalyticsSearchSource.keyword,
        hasKeyword: true,
        hasGenre: false,
      );
      await service.logSearchResultLoaded(
        source: AnalyticsSearchSource.keyword,
        resultCount: 3,
      );
      await service.logSearchFailed(
        source: AnalyticsSearchSource.shop,
        errorType: AnalyticsSearchErrorType.rateLimit,
      );
      await service.logCandidateAdded(
        source: AnalyticsCandidateSource.search,
        alreadySaved: false,
        candidateCountAfter: 1,
      );
      await service.logPostPrepareOpened(
        source: AnalyticsPostPrepareSource.recommendation,
        hasSavedStyle: true,
      );
      await service.logAiCommentGenerateStart(
        source: AnalyticsAiCommentSource.postPrepare,
        remainingCountBefore: 2,
        styleConfigured: true,
      );
      await service.logAiCommentGenerateSuccess(
        source: AnalyticsAiCommentSource.postPrepare,
        generatedLengthBucket: AnalyticsGeneratedLengthBucket.medium,
        remainingCountAfter: 1,
      );
      await service.logAiCommentGenerateError(
        source: AnalyticsAiCommentSource.postPrepare,
        errorType: AnalyticsAiCommentErrorType.limit,
      );
      await service.logAiCommentCopied(
        source: AnalyticsAiCommentSource.postPrepare,
        textType: AnalyticsAiCommentTextType.generated,
      );
      await service.logRoomLaunchTapped(
        source: AnalyticsRoomLaunchSource.postPrepare,
        launchType: AnalyticsRoomLaunchType.room,
      );
      await service.logRecommendationsOpened(
        itemCount: 5,
        generatedToday: true,
      );
      await service.logRecommendationItemTapped(
        position: 0,
        action: AnalyticsRecommendationAction.addCandidate,
      );
      await service.logMonetizationPlanOpened(
        source: AnalyticsMonetizationPlanSource.mypage,
        currentPlan: 'free',
      );
    });
  });

  group('AnalyticsServiceRegistry', () {
    tearDown(AnalyticsServiceRegistry.resetForTesting);

    test('defaults to NoOpAnalyticsService', () {
      AnalyticsServiceRegistry.resetForTesting();
      expect(AnalyticsServiceRegistry.instance, isA<NoOpAnalyticsService>());
    });

    test('install replaces instance', () {
      const replacement = NoOpAnalyticsService();
      AnalyticsServiceRegistry.install(replacement);
      expect(identical(AnalyticsServiceRegistry.instance, replacement), isTrue);
    });
  });

  group('analytics normalization helpers', () {
    test('resolveAnalyticsSearchSource maps condition fields', () {
      expect(
        resolveAnalyticsSearchSource(
          const RakutenProductSearchCondition(keyword: 'bag'),
        ),
        AnalyticsSearchSource.keyword,
      );
      expect(
        resolveAnalyticsSearchSource(
          const RakutenProductSearchCondition(genreId: '100'),
        ),
        AnalyticsSearchSource.genre,
      );
      expect(
        resolveAnalyticsSearchSource(
          const RakutenProductSearchCondition(shopCode: 'shop'),
        ),
        AnalyticsSearchSource.shop,
      );
      expect(
        resolveAnalyticsSearchSource(
          const RakutenProductSearchCondition(itemCode: 'shop:item'),
        ),
        AnalyticsSearchSource.url,
      );
    });

    test('classifyAnalyticsSearchError maps rate limit', () {
      expect(
        classifyAnalyticsSearchError(
          error: Exception('楽天API: (429)'),
          httpStatus: 429,
        ),
        AnalyticsSearchErrorType.rateLimit,
      );
    });

    test('classifyAnalyticsAiCommentError maps limit codes', () {
      expect(
        classifyAnalyticsAiCommentError(
          const PostCommentGenerationException(
            'daily_limit_reached',
            'limit',
          ),
        ),
        AnalyticsAiCommentErrorType.limit,
      );
    });

    test('bucketGeneratedTextLength buckets by length', () {
      expect(
        bucketGeneratedTextLength(50),
        AnalyticsGeneratedLengthBucket.short,
      );
      expect(
        bucketGeneratedTextLength(150),
        AnalyticsGeneratedLengthBucket.medium,
      );
      expect(
        bucketGeneratedTextLength(400),
        AnalyticsGeneratedLengthBucket.long,
      );
    });

    test('wire helpers return stable snake_case values', () {
      expect(wireSearchSource(AnalyticsSearchSource.keyword), 'keyword');
      expect(wireSearchErrorType(AnalyticsSearchErrorType.rateLimit), 'rate_limit');
      expect(
        wireRecommendationAction(AnalyticsRecommendationAction.postPrepare),
        'post_prepare',
      );
    });
  });
}
