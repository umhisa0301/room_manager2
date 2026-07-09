import 'package:flutter/foundation.dart';

/// Firebase / Crashlytics / Analytics の送信可否を集約する設定。
abstract final class FirebaseConfig {
  /// 本番 release ビルドでのみ Firebase 送信を有効にする。
  static bool get isTelemetryEnabled => kReleaseMode;

  /// Analytics イベント名（Firebase 予約語・既存アプリ内 analytics 命名と衝突しない接頭辞）。
  static const String eventAppOpen = 'rm_app_open';
  static const String eventLegalConsentAccepted = 'legal_consent_accepted';
  static const String eventOnboardingRoute = 'onboarding_route';

  // Phase 2: 価値導線イベント
  static const String eventSearchExecuted = 'search_executed';
  static const String eventSearchResultLoaded = 'search_result_loaded';
  static const String eventSearchFailed = 'search_failed';
  static const String eventCandidateAdded = 'candidate_added';
  static const String eventPostPrepareOpened = 'post_prepare_opened';
  static const String eventAiCommentGenerateStart = 'ai_comment_generate_start';
  static const String eventAiCommentGenerateSuccess =
      'ai_comment_generate_success';
  static const String eventAiCommentGenerateError = 'ai_comment_generate_error';
  static const String eventAiCommentCopied = 'ai_comment_copied';
  static const String eventRoomLaunchTapped = 'room_launch_tapped';
  static const String eventRecommendationsOpened = 'recommendations_opened';
  static const String eventRecommendationItemTapped =
      'recommendation_item_tapped';
  static const String eventMonetizationPlanOpened = 'monetization_plan_opened';

  /// [eventOnboardingRoute] の route パラメータ値。
  static const String onboardingRouteLegal = 'legal';
  static const String onboardingRouteHome = 'home';

  static const String paramRoute = 'route';

  // Phase 2 パラメータ名
  static const String paramSource = 'source';
  static const String paramHasKeyword = 'has_keyword';
  static const String paramHasGenre = 'has_genre';
  static const String paramResultCount = 'result_count';
  static const String paramErrorType = 'error_type';
  static const String paramAlreadySaved = 'already_saved';
  static const String paramCandidateCountAfter = 'candidate_count_after';
  static const String paramHasSavedStyle = 'has_saved_style';
  static const String paramRemainingCountBefore = 'remaining_count_before';
  static const String paramStyleConfigured = 'style_configured';
  static const String paramGeneratedLengthBucket = 'generated_length_bucket';
  static const String paramRemainingCountAfter = 'remaining_count_after';
  static const String paramTextType = 'text_type';
  static const String paramLaunchType = 'launch_type';
  static const String paramItemCount = 'item_count';
  static const String paramGeneratedToday = 'generated_today';
  static const String paramPosition = 'position';
  static const String paramAction = 'action';
  static const String paramCurrentPlan = 'current_plan';
}
