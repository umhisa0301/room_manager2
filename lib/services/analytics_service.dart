import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';
import '../models/analytics_params.dart';
import '../models/post_style_settings.dart';
import '../models/rakuten_product_search_condition.dart';
import 'post_comment_generation_exception.dart';

/// Firebase Analytics への送信を抽象化するサービス。
///
/// 画面・Provider からは [FirebaseAnalytics.instance] を直接呼ばず、
/// 必ずこのサービス経由でイベントを送る。
abstract class AnalyticsService {
  Future<void> setConsentGranted(bool granted);

  Future<void> logAppOpen();

  Future<void> logLegalConsentAccepted();

  Future<void> logOnboardingRoute({required String route});

  Future<void> logSearchExecuted({
    required AnalyticsSearchSource source,
    required bool hasKeyword,
    required bool hasGenre,
  });

  Future<void> logSearchResultLoaded({
    required AnalyticsSearchSource source,
    required int resultCount,
  });

  Future<void> logSearchFailed({
    required AnalyticsSearchSource source,
    required AnalyticsSearchErrorType errorType,
  });

  Future<void> logCandidateAdded({
    required AnalyticsCandidateSource source,
    bool? alreadySaved,
    int? candidateCountAfter,
  });

  Future<void> logPostPrepareOpened({
    required AnalyticsPostPrepareSource source,
    bool? hasSavedStyle,
  });

  Future<void> logAiCommentGenerateStart({
    required AnalyticsAiCommentSource source,
    int? remainingCountBefore,
    bool? styleConfigured,
  });

  Future<void> logAiCommentGenerateSuccess({
    required AnalyticsAiCommentSource source,
    required AnalyticsGeneratedLengthBucket generatedLengthBucket,
    int? remainingCountAfter,
  });

  Future<void> logAiCommentGenerateError({
    required AnalyticsAiCommentSource source,
    required AnalyticsAiCommentErrorType errorType,
  });

  Future<void> logAiCommentCopied({
    required AnalyticsAiCommentSource source,
    required AnalyticsAiCommentTextType textType,
  });

  Future<void> logRoomLaunchTapped({
    required AnalyticsRoomLaunchSource source,
    AnalyticsRoomLaunchType? launchType,
  });

  Future<void> logRecommendationsOpened({
    required int itemCount,
    bool? generatedToday,
  });

  Future<void> logRecommendationItemTapped({
    required int position,
    required AnalyticsRecommendationAction action,
  });

  Future<void> logMonetizationPlanOpened({
    AnalyticsMonetizationPlanSource? source,
    String? currentPlan,
  });
}

/// テストや Firebase 未初期化時に使う no-op 実装。
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> setConsentGranted(bool granted) async {}

  @override
  Future<void> logAppOpen() async {}

  @override
  Future<void> logLegalConsentAccepted() async {}

  @override
  Future<void> logOnboardingRoute({required String route}) async {}

  @override
  Future<void> logSearchExecuted({
    required AnalyticsSearchSource source,
    required bool hasKeyword,
    required bool hasGenre,
  }) async {}

  @override
  Future<void> logSearchResultLoaded({
    required AnalyticsSearchSource source,
    required int resultCount,
  }) async {}

  @override
  Future<void> logSearchFailed({
    required AnalyticsSearchSource source,
    required AnalyticsSearchErrorType errorType,
  }) async {}

  @override
  Future<void> logCandidateAdded({
    required AnalyticsCandidateSource source,
    bool? alreadySaved,
    int? candidateCountAfter,
  }) async {}

  @override
  Future<void> logPostPrepareOpened({
    required AnalyticsPostPrepareSource source,
    bool? hasSavedStyle,
  }) async {}

  @override
  Future<void> logAiCommentGenerateStart({
    required AnalyticsAiCommentSource source,
    int? remainingCountBefore,
    bool? styleConfigured,
  }) async {}

  @override
  Future<void> logAiCommentGenerateSuccess({
    required AnalyticsAiCommentSource source,
    required AnalyticsGeneratedLengthBucket generatedLengthBucket,
    int? remainingCountAfter,
  }) async {}

  @override
  Future<void> logAiCommentGenerateError({
    required AnalyticsAiCommentSource source,
    required AnalyticsAiCommentErrorType errorType,
  }) async {}

  @override
  Future<void> logAiCommentCopied({
    required AnalyticsAiCommentSource source,
    required AnalyticsAiCommentTextType textType,
  }) async {}

  @override
  Future<void> logRoomLaunchTapped({
    required AnalyticsRoomLaunchSource source,
    AnalyticsRoomLaunchType? launchType,
  }) async {}

  @override
  Future<void> logRecommendationsOpened({
    required int itemCount,
    bool? generatedToday,
  }) async {}

  @override
  Future<void> logRecommendationItemTapped({
    required int position,
    required AnalyticsRecommendationAction action,
  }) async {}

  @override
  Future<void> logMonetizationPlanOpened({
    AnalyticsMonetizationPlanSource? source,
    String? currentPlan,
  }) async {}
}

/// グローバル参照用レジストリ（Provider 外からも NoOp がデフォルト）。
abstract final class AnalyticsServiceRegistry {
  static AnalyticsService _instance = const NoOpAnalyticsService();

  static AnalyticsService get instance => _instance;

  static void install(AnalyticsService service) {
    _instance = service;
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = const NoOpAnalyticsService();
  }
}

/// Firebase Analytics 実装（consent gate + release-only 送信）。
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({
    required FirebaseAnalytics analytics,
    bool? telemetryEnabled,
  }) : _analytics = analytics,
       _telemetryEnabled = telemetryEnabled ?? FirebaseConfig.isTelemetryEnabled;

  final FirebaseAnalytics _analytics;
  final bool _telemetryEnabled;

  bool _consentGranted = false;
  bool _appOpenLogged = false;
  String? _lastOnboardingRouteSignature;

  bool get _canSend => _telemetryEnabled && _consentGranted;

  @override
  Future<void> setConsentGranted(bool granted) async {
    _consentGranted = granted;
    if (!_telemetryEnabled) {
      return;
    }
    try {
      await _analytics.setAnalyticsCollectionEnabled(granted);
    } catch (error, stackTrace) {
      _logSendFailure('setConsentGranted', error, stackTrace);
    }
  }

  @override
  Future<void> logAppOpen() async {
    if (!_canSend || _appOpenLogged) {
      return;
    }
    _appOpenLogged = true;
    await _logEvent(FirebaseConfig.eventAppOpen);
  }

  @override
  Future<void> logLegalConsentAccepted() async {
    if (!_canSend) {
      return;
    }
    await _logEvent(FirebaseConfig.eventLegalConsentAccepted);
  }

  @override
  Future<void> logOnboardingRoute({required String route}) async {
    if (!_canSend) {
      return;
    }
    final normalizedRoute = _normalizeOnboardingRoute(route);
    if (normalizedRoute == null) {
      return;
    }
    final signature = normalizedRoute;
    if (_lastOnboardingRouteSignature == signature) {
      return;
    }
    _lastOnboardingRouteSignature = signature;
    await _logEvent(
      FirebaseConfig.eventOnboardingRoute,
      parameters: {FirebaseConfig.paramRoute: normalizedRoute},
    );
  }

  @override
  Future<void> logSearchExecuted({
    required AnalyticsSearchSource source,
    required bool hasKeyword,
    required bool hasGenre,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventSearchExecuted,
      parameters: {
        FirebaseConfig.paramSource: wireSearchSource(source),
        FirebaseConfig.paramHasKeyword: hasKeyword,
        FirebaseConfig.paramHasGenre: hasGenre,
      },
    );
  }

  @override
  Future<void> logSearchResultLoaded({
    required AnalyticsSearchSource source,
    required int resultCount,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventSearchResultLoaded,
      parameters: {
        FirebaseConfig.paramSource: wireSearchSource(source),
        FirebaseConfig.paramResultCount: resultCount.clamp(0, 1000000),
      },
    );
  }

  @override
  Future<void> logSearchFailed({
    required AnalyticsSearchSource source,
    required AnalyticsSearchErrorType errorType,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventSearchFailed,
      parameters: {
        FirebaseConfig.paramSource: wireSearchSource(source),
        FirebaseConfig.paramErrorType: wireSearchErrorType(errorType),
      },
    );
  }

  @override
  Future<void> logCandidateAdded({
    required AnalyticsCandidateSource source,
    bool? alreadySaved,
    int? candidateCountAfter,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventCandidateAdded,
      parameters: _nonNullParams({
        FirebaseConfig.paramSource: wireCandidateSource(source),
        FirebaseConfig.paramAlreadySaved: alreadySaved,
        FirebaseConfig.paramCandidateCountAfter: candidateCountAfter
            ?.clamp(0, 1000000),
      }),
    );
  }

  @override
  Future<void> logPostPrepareOpened({
    required AnalyticsPostPrepareSource source,
    bool? hasSavedStyle,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventPostPrepareOpened,
      parameters: _nonNullParams({
        FirebaseConfig.paramSource: wirePostPrepareSource(source),
        FirebaseConfig.paramHasSavedStyle: hasSavedStyle,
      }),
    );
  }

  @override
  Future<void> logAiCommentGenerateStart({
    required AnalyticsAiCommentSource source,
    int? remainingCountBefore,
    bool? styleConfigured,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventAiCommentGenerateStart,
      parameters: _nonNullParams({
        FirebaseConfig.paramSource: wireAiCommentSource(source),
        FirebaseConfig.paramRemainingCountBefore: remainingCountBefore
            ?.clamp(0, 1000000),
        FirebaseConfig.paramStyleConfigured: styleConfigured,
      }),
    );
  }

  @override
  Future<void> logAiCommentGenerateSuccess({
    required AnalyticsAiCommentSource source,
    required AnalyticsGeneratedLengthBucket generatedLengthBucket,
    int? remainingCountAfter,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventAiCommentGenerateSuccess,
      parameters: _nonNullParams({
        FirebaseConfig.paramSource: wireAiCommentSource(source),
        FirebaseConfig.paramGeneratedLengthBucket: wireGeneratedLengthBucket(
          generatedLengthBucket,
        ),
        FirebaseConfig.paramRemainingCountAfter: remainingCountAfter
            ?.clamp(0, 1000000),
      }),
    );
  }

  @override
  Future<void> logAiCommentGenerateError({
    required AnalyticsAiCommentSource source,
    required AnalyticsAiCommentErrorType errorType,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventAiCommentGenerateError,
      parameters: {
        FirebaseConfig.paramSource: wireAiCommentSource(source),
        FirebaseConfig.paramErrorType: wireAiCommentErrorType(errorType),
      },
    );
  }

  @override
  Future<void> logAiCommentCopied({
    required AnalyticsAiCommentSource source,
    required AnalyticsAiCommentTextType textType,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventAiCommentCopied,
      parameters: {
        FirebaseConfig.paramSource: wireAiCommentSource(source),
        FirebaseConfig.paramTextType: wireAiCommentTextType(textType),
      },
    );
  }

  @override
  Future<void> logRoomLaunchTapped({
    required AnalyticsRoomLaunchSource source,
    AnalyticsRoomLaunchType? launchType,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventRoomLaunchTapped,
      parameters: _nonNullParams({
        FirebaseConfig.paramSource: wireRoomLaunchSource(source),
        FirebaseConfig.paramLaunchType: launchType == null
            ? null
            : wireRoomLaunchType(launchType),
      }),
    );
  }

  @override
  Future<void> logRecommendationsOpened({
    required int itemCount,
    bool? generatedToday,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventRecommendationsOpened,
      parameters: _nonNullParams({
        FirebaseConfig.paramItemCount: itemCount.clamp(0, 1000000),
        FirebaseConfig.paramGeneratedToday: generatedToday,
      }),
    );
  }

  @override
  Future<void> logRecommendationItemTapped({
    required int position,
    required AnalyticsRecommendationAction action,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventRecommendationItemTapped,
      parameters: {
        FirebaseConfig.paramPosition: position.clamp(0, 1000000),
        FirebaseConfig.paramAction: wireRecommendationAction(action),
      },
    );
  }

  @override
  Future<void> logMonetizationPlanOpened({
    AnalyticsMonetizationPlanSource? source,
    String? currentPlan,
  }) async {
    if (!_canSend) return;
    await _logEvent(
      FirebaseConfig.eventMonetizationPlanOpened,
      parameters: _nonNullParams({
        FirebaseConfig.paramSource: source == null
            ? null
            : wireMonetizationPlanSource(source),
        FirebaseConfig.paramCurrentPlan: _normalizeCurrentPlan(currentPlan),
      }),
    );
  }

  String? _normalizeOnboardingRoute(String route) {
    switch (route) {
      case FirebaseConfig.onboardingRouteLegal:
      case FirebaseConfig.onboardingRouteHome:
        return route;
      default:
        if (kDebugMode) {
          debugPrint('[ANALYTICS] ignored onboarding_route=$route');
        }
        return null;
    }
  }

  String? _normalizeCurrentPlan(String? plan) {
    final normalized = (plan ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'free':
      case 'basic':
      case 'pro':
        return normalized;
      default:
        return normalized.isEmpty ? 'unknown' : 'unknown';
    }
  }

  Future<void> _logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error, stackTrace) {
      _logSendFailure(name, error, stackTrace);
    }
  }

  void _logSendFailure(String context, Object error, StackTrace stackTrace) {
    debugPrint('[ANALYTICS] send failed context=$context error=$error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Map<String, Object> _nonNullParams(Map<String, Object?> params) {
    final out = <String, Object>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value != null) {
        out[entry.key] = value;
      }
    }
    return out;
  }
}

/// 検索条件から Analytics 用の source を解決する。
AnalyticsSearchSource resolveAnalyticsSearchSource(
  RakutenProductSearchCondition condition,
) {
  final normalized = condition.normalized();
  final hasKeyword = normalized.keyword.isNotEmpty;
  final hasGenre =
      normalized.genreId != null && normalized.genreId!.trim().isNotEmpty;
  final hasShop =
      normalized.shopCode != null && normalized.shopCode!.trim().isNotEmpty;
  final hasItem =
      normalized.itemCode != null && normalized.itemCode!.trim().isNotEmpty;
  if (hasItem) return AnalyticsSearchSource.url;
  if (hasShop) return AnalyticsSearchSource.shop;
  if (hasGenre && !hasKeyword) return AnalyticsSearchSource.genre;
  if (hasKeyword) return AnalyticsSearchSource.keyword;
  if (hasGenre) return AnalyticsSearchSource.genre;
  return AnalyticsSearchSource.unknown;
}

AnalyticsSearchErrorType classifyAnalyticsSearchError({
  required Object error,
  int? httpStatus,
}) {
  final raw = error.toString();
  final body = raw.startsWith('Exception: ')
      ? raw.substring('Exception: '.length).trim()
      : raw.trim();
  final status =
      httpStatus ??
      int.tryParse(RegExp(r'\((\d{3})\)').firstMatch(body)?.group(1) ?? '');
  if (status == 429 || body.contains('429')) {
    return AnalyticsSearchErrorType.rateLimit;
  }
  if (_looksLikeUnsupportedUrlSearchError(body)) {
    return AnalyticsSearchErrorType.unsupportedUrl;
  }
  if (_looksLikeNetworkSearchError(body, error)) {
    return AnalyticsSearchErrorType.network;
  }
  if (status == 400 || body.startsWith('楽天API:')) {
    return AnalyticsSearchErrorType.api;
  }
  return AnalyticsSearchErrorType.unknown;
}

bool _looksLikeUnsupportedUrlSearchError(String body) {
  final lower = body.toLowerCase();
  return lower.contains('unsupported') ||
      lower.contains('非対応') ||
      lower.contains('url') && lower.contains('対応');
}

bool _looksLikeNetworkSearchError(String body, Object error) {
  final type = error.runtimeType.toString().toLowerCase();
  if (type.contains('socket') ||
      type.contains('timeout') ||
      type.contains('connection')) {
    return true;
  }
  return body.contains('SocketException') ||
      body.contains('TimeoutException') ||
      body.contains('Connection') ||
      body.contains('Network');
}

AnalyticsAiCommentErrorType classifyAnalyticsAiCommentError(
  PostCommentGenerationException error,
) {
  switch (error.code) {
    case 'RATE_LIMIT_EXCEEDED':
    case 'daily_limit_reached':
    case 'product_already_generated':
      return AnalyticsAiCommentErrorType.limit;
    case 'AI_GENERATION_DISABLED':
    case 'SERVICE_UNAVAILABLE':
      return AnalyticsAiCommentErrorType.serverUnavailable;
    case 'TIMEOUT':
    case 'NETWORK_ERROR':
      return AnalyticsAiCommentErrorType.network;
    default:
      final status = error.httpStatus;
      if (status == 503 || status == 502 || status == 504) {
        return AnalyticsAiCommentErrorType.serverUnavailable;
      }
      if (status != null && status >= 500) {
        return AnalyticsAiCommentErrorType.api;
      }
      return AnalyticsAiCommentErrorType.unknown;
  }
}

AnalyticsGeneratedLengthBucket bucketGeneratedTextLength(int length) {
  if (length < 100) return AnalyticsGeneratedLengthBucket.short;
  if (length < 300) return AnalyticsGeneratedLengthBucket.medium;
  return AnalyticsGeneratedLengthBucket.long;
}

bool isPostStyleConfigured(PostStyleSettings settings) {
  final defaults = PostStyleSettings.defaults();
  if ((settings.styleExample ?? '').trim().isNotEmpty) return true;
  return settings.updatedAt.isAfter(defaults.updatedAt);
}

AnalyticsAiCommentTextType resolveAiCommentTextType({
  required String bodyText,
  required bool userEditedBody,
}) {
  if (userEditedBody) return AnalyticsAiCommentTextType.manual;
  if (bodyText.trim().isNotEmpty) return AnalyticsAiCommentTextType.generated;
  return AnalyticsAiCommentTextType.unknown;
}

String wireSearchSource(AnalyticsSearchSource source) {
  switch (source) {
    case AnalyticsSearchSource.keyword:
      return 'keyword';
    case AnalyticsSearchSource.url:
      return 'url';
    case AnalyticsSearchSource.genre:
      return 'genre';
    case AnalyticsSearchSource.shop:
      return 'shop';
    case AnalyticsSearchSource.unknown:
      return 'unknown';
  }
}

String wireSearchErrorType(AnalyticsSearchErrorType errorType) {
  switch (errorType) {
    case AnalyticsSearchErrorType.rateLimit:
      return 'rate_limit';
    case AnalyticsSearchErrorType.unsupportedUrl:
      return 'unsupported_url';
    case AnalyticsSearchErrorType.network:
      return 'network';
    case AnalyticsSearchErrorType.api:
      return 'api';
    case AnalyticsSearchErrorType.unknown:
      return 'unknown';
  }
}

String wireCandidateSource(AnalyticsCandidateSource source) {
  switch (source) {
    case AnalyticsCandidateSource.search:
      return 'search';
    case AnalyticsCandidateSource.recommendation:
      return 'recommendation';
    case AnalyticsCandidateSource.manual:
      return 'manual';
    case AnalyticsCandidateSource.unknown:
      return 'unknown';
  }
}

String wirePostPrepareSource(AnalyticsPostPrepareSource source) {
  switch (source) {
    case AnalyticsPostPrepareSource.search:
      return 'search';
    case AnalyticsPostPrepareSource.recommendation:
      return 'recommendation';
    case AnalyticsPostPrepareSource.candidate:
      return 'candidate';
    case AnalyticsPostPrepareSource.collected:
      return 'collected';
    case AnalyticsPostPrepareSource.unknown:
      return 'unknown';
  }
}

String wireAiCommentSource(AnalyticsAiCommentSource source) {
  switch (source) {
    case AnalyticsAiCommentSource.postPrepare:
      return 'post_prepare';
    case AnalyticsAiCommentSource.unknown:
      return 'unknown';
  }
}

String wireAiCommentErrorType(AnalyticsAiCommentErrorType errorType) {
  switch (errorType) {
    case AnalyticsAiCommentErrorType.limit:
      return 'limit';
    case AnalyticsAiCommentErrorType.serverUnavailable:
      return 'server_unavailable';
    case AnalyticsAiCommentErrorType.network:
      return 'network';
    case AnalyticsAiCommentErrorType.api:
      return 'api';
    case AnalyticsAiCommentErrorType.unknown:
      return 'unknown';
  }
}

String wireAiCommentTextType(AnalyticsAiCommentTextType textType) {
  switch (textType) {
    case AnalyticsAiCommentTextType.generated:
      return 'generated';
    case AnalyticsAiCommentTextType.manual:
      return 'manual';
    case AnalyticsAiCommentTextType.unknown:
      return 'unknown';
  }
}

String wireRoomLaunchSource(AnalyticsRoomLaunchSource source) {
  switch (source) {
    case AnalyticsRoomLaunchSource.postPrepare:
      return 'post_prepare';
    case AnalyticsRoomLaunchSource.search:
      return 'search';
    case AnalyticsRoomLaunchSource.recommendation:
      return 'recommendation';
    case AnalyticsRoomLaunchSource.candidate:
      return 'candidate';
    case AnalyticsRoomLaunchSource.unknown:
      return 'unknown';
  }
}

String wireRoomLaunchType(AnalyticsRoomLaunchType launchType) {
  switch (launchType) {
    case AnalyticsRoomLaunchType.room:
      return 'room';
    case AnalyticsRoomLaunchType.rakuten:
      return 'rakuten';
    case AnalyticsRoomLaunchType.browser:
      return 'browser';
    case AnalyticsRoomLaunchType.unknown:
      return 'unknown';
  }
}

String wireRecommendationAction(AnalyticsRecommendationAction action) {
  switch (action) {
    case AnalyticsRecommendationAction.openDetail:
      return 'open_detail';
    case AnalyticsRecommendationAction.postPrepare:
      return 'post_prepare';
    case AnalyticsRecommendationAction.addCandidate:
      return 'add_candidate';
    case AnalyticsRecommendationAction.unknown:
      return 'unknown';
  }
}

String wireMonetizationPlanSource(AnalyticsMonetizationPlanSource source) {
  switch (source) {
    case AnalyticsMonetizationPlanSource.mypage:
      return 'mypage';
    case AnalyticsMonetizationPlanSource.limitDialog:
      return 'limit_dialog';
    case AnalyticsMonetizationPlanSource.unknown:
      return 'unknown';
  }
}

String wireGeneratedLengthBucket(AnalyticsGeneratedLengthBucket bucket) {
  switch (bucket) {
    case AnalyticsGeneratedLengthBucket.short:
      return 'short';
    case AnalyticsGeneratedLengthBucket.medium:
      return 'medium';
    case AnalyticsGeneratedLengthBucket.long:
      return 'long';
  }
}
