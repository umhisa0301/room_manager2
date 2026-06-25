import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/product_catalog_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/room_recommendation_profile.dart';
import '../models/today_recommendation.dart';
import '../models/user_profile.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../utils/api_request_coordinator.dart';
import '../repository/today_recommendation_repository.dart';
import '../utils/catalog_product_mapper.dart';
import '../utils/genre_pref_log.dart';
import '../utils/recommend_cooldown_policy.dart';
import '../utils/favorite_genre_selection_policy.dart';
import '../utils/product_safety_filter.dart';
import '../utils/search_result_quality_filter.dart';
import '../utils/today_recommendation_policy.dart';
import '../utils/today_recommendation_exposure_policy.dart';
import '../utils/today_recommendation_genre_distribution.dart';
import '../utils/today_recommendation_genre_page_store.dart';
import '../utils/profile_recommendation_integration.dart';
import '../utils/today_recommendation_catalog.dart';
import '../config/debug_log_flags.dart';
import '../utils/app_debug_log.dart';
import '../utils/user_profile_preferred_genre_words.dart';
import '../services/recommendation_generation_limit.dart';
import '../services/recommendation_scoring_service.dart';
import 'rakuten_managed_product_provider.dart';

enum TodayRecommendationGenerationStatus {
  idle,
  loading,
  ready,
  empty,
  partialSuccess,
  failedRateLimit,
  failedApiError,
}

class TodayRecommendationProvider extends ChangeNotifier {
  TodayRecommendationProvider({
    required TodayRecommendationRepository repository,
    required RakutenSearchRepository searchRepository,
    ProductCatalogRepository? productCatalogRepository,
  }) : _repository = repository,
       _searchRepository = searchRepository,
       _productCatalogRepository = productCatalogRepository {
    _bundle = _repository.load();
    _seedRegenerateCooldownFromBundle();
  }

  final TodayRecommendationRepository _repository;
  final RakutenSearchRepository _searchRepository;
  final ProductCatalogRepository? _productCatalogRepository;

  TodayRecommendationBundle? _bundle;
  bool _isLoading = false;
  String? _errorMessage;
  TodayRecommendationGenerationStatus _generationStatus =
      TodayRecommendationGenerationStatus.idle;
  DateTime? _cooldownUntil;
  DateTime? _lastEnsureAt;
  String? _lastEnsureSource;
  DateTime? _lastRegenerateAt;
  bool _lastRateLimitFailure = false;
  String? _lastGuardReason;
  Timer? _regenerateCooldownTimer;
  String? _lastRegenerateButtonLogSignature;
  DateTime? _lastRegenerateButtonLogAt;
  static const Duration _recentEnsureWindow = Duration(seconds: 3);
  static const Duration _regenerateButtonLogMinInterval = Duration(seconds: 30);
  static const Duration _manualRegenerateCooldown =
      RecommendCooldownPolicy.manualRegenerateCooldown;
  static const Duration _recentGenerateCooldown =
      RecommendCooldownPolicy.recentGenerateCooldown;
  static const Duration _rateLimitCooldown =
      RecommendCooldownPolicy.rateLimitCooldown;
  static const String _logTagTrigger = '[RECOMMEND_TRIGGER]';
  static const String _logTagGuard = '[RECOMMEND_GUARD]';
  static const String _logTagGenerate = '[RECOMMEND_GENERATE]';
  static const String _logTagApi = '[RECOMMEND_API]';
  static const String _logTagSummary = '[RECOMMEND_SUMMARY]';

  TodayRecommendationBundle? get bundle => _bundle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TodayRecommendationGenerationStatus get generationStatus => _generationStatus;
  bool get isInCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
  DateTime? get lastEnsureAt => _lastEnsureAt;
  String? get lastEnsureSource => _lastEnsureSource;
  DateTime? get lastRegenerateAt => _lastRegenerateAt;
  String? get lastGuardReason => _lastGuardReason;

  /// 手動再生成のクールダウン残り（null なら再生成可能）。
  RecommendRegenerateCooldownStatus manualRegenerateCooldownStatus({
    DateTime? now,
  }) {
    return RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
      clock: now ?? DateTime.now(),
      lastRegenerateAt: _lastRegenerateAt,
      rateLimitCooldownUntil: _cooldownUntil,
      lastRateLimitFailure: _lastRateLimitFailure,
    );
  }

  RegenerateButtonUiState regenerateButtonUiState({DateTime? now}) {
    final cooldown = manualRegenerateCooldownStatus(now: now);
    return RecommendCooldownPolicyUi.resolveRegenerateButtonUiState(
      cooldown: cooldown,
      completed: isCompleted,
      isLoading: _isLoading,
    );
  }

  void logRegenerateButtonState({String trigger = 'ui'}) {
    if (!kDebugMode) return;
    final cooldown = manualRegenerateCooldownStatus();
    final ui = regenerateButtonUiState();
    final signature =
        '${ui.canPress}|${ui.blockReason}|${cooldown.remainingSeconds}|'
        '$isCompleted|$_isLoading|$totalCount|${totalCount - pendingCount}';
    final now = DateTime.now();
    if (_lastRegenerateButtonLogSignature == signature &&
        _lastRegenerateButtonLogAt != null &&
        now.difference(_lastRegenerateButtonLogAt!) <
            _regenerateButtonLogMinInterval) {
      return;
    }
    _lastRegenerateButtonLogSignature = signature;
    _lastRegenerateButtonLogAt = now;
    debugPrint(
      '[REGENERATE_BUTTON] trigger=$trigger '
      'canPress=${ui.canPress} '
      'cooldownCanRegenerate=${cooldown.canRegenerate} '
      'completed=$isCompleted '
      'guardReason=${ui.blockReason} '
      'remainingMs=${cooldown.remainingSeconds * 1000} '
      'isLoading=$_isLoading '
      'hasBundle=${_bundle != null} '
      'candidates=$totalCount '
      'completedCount=${totalCount - pendingCount} '
      'lastRegenerateAt=${_lastRegenerateAt?.toIso8601String() ?? '-'} '
      'bundleGeneratedAt=${_bundle?.generatedAt.toIso8601String() ?? '-'}',
    );
  }

  void _seedRegenerateCooldownFromBundle() {
    final bundle = _bundle;
    if (bundle == null || bundle.entries.isEmpty) return;
    final todayKey = _localDateKey(DateTime.now());
    if (bundle.localDateKey != todayKey) return;

    final generatedAt = bundle.generatedAt;
    final elapsed = DateTime.now().difference(generatedAt);
    if (elapsed >= _manualRegenerateCooldown && !_lastRateLimitFailure) return;

    if (_lastRegenerateAt == null ||
        generatedAt.isAfter(_lastRegenerateAt!)) {
      _lastRegenerateAt = generatedAt;
    }
    _syncRegenerateCooldownTimer();
  }

  void _syncRegenerateCooldownTimer() {
    _regenerateCooldownTimer?.cancel();
    _regenerateCooldownTimer = null;
    final status = manualRegenerateCooldownStatus();
    if (status.canRegenerate) return;

    final wait = _regenerateCooldownTimerDelay(status);
    _regenerateCooldownTimer = Timer(wait, () {
      notifyListeners();
      _syncRegenerateCooldownTimer();
    });
  }

  Duration _regenerateCooldownTimerDelay(RecommendRegenerateCooldownStatus status) {
    final nextAt = status.nextAvailableAt;
    if (nextAt != null) {
      final remaining = nextAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        return const Duration(milliseconds: 100);
      }
      if (remaining < const Duration(seconds: 1)) {
        return remaining;
      }
      if (remaining <= const Duration(seconds: 30)) {
        return remaining;
      }
      return const Duration(seconds: 30);
    }
    final waitSeconds = status.remainingSeconds <= 0
        ? 1
        : (status.remainingSeconds <= 30 ? status.remainingSeconds + 1 : 30);
    return Duration(seconds: waitSeconds);
  }

  @override
  void dispose() {
    _regenerateCooldownTimer?.cancel();
    super.dispose();
  }

  int get totalCount => _bundle?.entries.length ?? 0;
  int get pendingCount => _bundle?.pendingCount ?? 0;
  bool get isCompleted => _bundle?.isCompleted ?? false;

  /// 永続化済みバンドルを再読込（他画面での更新や pull-to-refresh 後の表示同期用）。
  void reloadBundleFromStorage() {
    _bundle = _repository.load();
    _errorMessage = null;
    _generationStatus = _bundle == null
        ? TodayRecommendationGenerationStatus.idle
        : (_bundle!.entries.isEmpty
              ? TodayRecommendationGenerationStatus.empty
              : TodayRecommendationGenerationStatus.ready);
    _seedRegenerateCooldownFromBundle();
    notifyListeners();
  }

  /// 本日バンドルのローカル日キー（YYYY-MM-DD）。永続化・日付またぎ判定に使用。
  String? get activeLocalDateKey => _bundle?.localDateKey;

  /// ホーム等の短い日付表記（例: 4月1日）。バンドルが無いときは null。
  String? get activeDateLabelJp {
    final key = _bundle?.localDateKey;
    if (key == null || key.isEmpty) return null;
    final p = key.split('-');
    if (p.length != 3) return null;
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (m == null || d == null) return null;
    return '$m月$d日';
  }

  bool get hasTodayBundle {
    final b = _bundle;
    if (b == null) return false;
    return b.localDateKey == _localDateKey(DateTime.now());
  }

  bool get hasTodayBundleWithEntries {
    final b = _bundle;
    if (b == null) return false;
    if (b.localDateKey != _localDateKey(DateTime.now())) return false;
    return b.entries.isNotEmpty;
  }

  Future<void> ensureToday({
    required UserProfile profile,
    required List<RakutenManagedProduct> managedItems,
    required List<SavedShop> savedShops,
    RoomRecommendationProfile? recommendationProfile,
    String trigger = 'ensure',
  }) async {
    final now = DateTime.now();
    final previousEnsureAt = _lastEnsureAt;
    final previousEnsureSource = _lastEnsureSource;
    _lastEnsureAt = now;
    _lastEnsureSource = trigger;
    _trigger(source: trigger);
    _trace('trigger=$trigger');
    _trace('action=ensureToday');
    _trace('alreadyGenerating=$_isLoading');
    _trace(
      'lastGeneratedAt=${_bundle?.generatedAt.toIso8601String() ?? 'null'}',
    );
    final todayKey = _localDateKey(now);
    if (trigger == 'screenOpen' &&
        previousEnsureAt != null &&
        previousEnsureSource != null &&
        previousEnsureSource != 'screenOpen' &&
        now.difference(previousEnsureAt) < _recentEnsureWindow) {
      _guard('skipReason=recentEnsure');
      return;
    }
    if (_bundle != null && _bundle!.localDateKey == todayKey) {
      _trace('shouldSkipBecauseRecentlyTried=true');
      _guard('skipReason=sameDay');
      return;
    }
    _trace('shouldSkipBecauseRecentlyTried=false');
    if (ApiRequestCoordinator.manualSearchRunning) {
      _guard('skipReason=manualSearchActive');
      if (kDebugMode) {
        recommendAuditLog(
          '[SEARCH_BACKGROUND_CONFLICT_AUDIT] manualSearchRunning=true '
          'todayRecommendRunning=false roomImportRunning=false '
          'metadataEnrichRunning=false priority=manualSearch',
        );
      }
      return;
    }
    await regenerateToday(
      profile: profile,
      managedItems: managedItems,
      savedShops: savedShops,
      recommendationProfile: recommendationProfile,
      trigger: trigger,
    );
  }

  Future<void> regenerateToday({
    required UserProfile profile,
    required List<RakutenManagedProduct> managedItems,
    required List<SavedShop> savedShops,
    RoomRecommendationProfile? recommendationProfile,
    String trigger = 'unknown',
    bool manual = false,
  }) async {
    final now = DateTime.now();
    _lastGuardReason = null;
    _trigger(source: trigger);
    _trace('trigger=$trigger');
    _trace('action=regenerateToday');
    _trace('alreadyGenerating=$_isLoading');
    _trace(
      'lastGeneratedAt=${_bundle?.generatedAt.toIso8601String() ?? 'null'}',
    );
    if (_isLoading) {
      _guard('skipReason=alreadyGenerating');
      return;
    }
    if (_lastRateLimitFailure && isInCooldown) {
      _guard('skipReason=rateLimitCooldown');
      return;
    }
    if (manual &&
        _lastRegenerateAt != null &&
        now.difference(_lastRegenerateAt!) < _manualRegenerateCooldown) {
      _guard('skipReason=manualCooldown');
      logTodayRecommendCooldown(trigger: 'manual');
      return;
    }
    if (!manual &&
        _lastRegenerateAt != null &&
        now.difference(_lastRegenerateAt!) < _recentGenerateCooldown) {
      _guard('skipReason=recentlyGenerated');
      return;
    }
    if (!manual && isInCooldown) {
      _guard('skipReason=cooldown');
      return;
    }
    final todayKey = _localDateKey(now);
    final countsAsPrimaryGeneration = isPrimaryRecommendationGeneration(
      manual: manual,
      bundleBefore: _bundle,
      todayLocalDateKey: todayKey,
    );
    if (countsAsPrimaryGeneration) {
      final limitState =
          await resolveRecommendationGenerationAvailabilityForToday(now: now);
      if (!limitState.allowed) {
        _guard('skipReason=monetizationDailyLimit');
        return;
      }
    }
    _lastRegenerateAt = now;
    _isLoading = true;
    _errorMessage = null;
    _generationStatus = TodayRecommendationGenerationStatus.loading;
    notifyListeners();
    try {
      final previousBundle = _bundle;
      if (previousBundle != null && previousBundle.entries.isNotEmpty) {
        await _repository.recordExposureShown(
          previousBundle.entries,
          shownAt: now,
        );
      }
      final generated = await _generate(
        profile: profile,
        managedItems: managedItems,
        savedShops: savedShops,
        recommendationProfile: recommendationProfile,
      );
      _cooldownUntil = null;
      _lastRateLimitFailure = false;
      _bundle = generated;
      final canSaveEmpty =
          generated.entries.isEmpty &&
          generated.localDateKey == _localDateKey(DateTime.now());
      if (generated.entries.isNotEmpty || canSaveEmpty) {
        await _repository.save(generated);
        _saveLog(saved: true, count: generated.entries.length);
      } else {
        _saveLog(saved: false, reason: 'noEntriesNotSaved');
      }
      _generationStatus = generated.entries.isEmpty
          ? TodayRecommendationGenerationStatus.empty
          : (generated.entries.length < 10
                ? TodayRecommendationGenerationStatus.partialSuccess
                : TodayRecommendationGenerationStatus.ready);
      if (countsAsPrimaryGeneration) {
        await recordSuccessfulRecommendationGeneration(now: now);
      }
    } catch (e, st) {
      if (kDebugMode) {
        importantDebugLog('[TodayRecommendation] regenerateToday failed: $e');
        importantDebugLog('$st');
      }
      final isRateLimit = _isRateLimitError(e);
      if (isRateLimit) {
        _cooldownUntil = DateTime.now().add(_rateLimitCooldown);
        _lastRateLimitFailure = true;
      }
      if (_bundle != null && _bundle!.entries.isNotEmpty) {
        _errorMessage = null;
        _generationStatus = _bundle!.entries.length < 10
            ? TodayRecommendationGenerationStatus.partialSuccess
            : TodayRecommendationGenerationStatus.ready;
        _saveLog(keepPreviousBundle: true, reason: _failureTypeFromError(e));
        _resultLog(
          status: 'partialSuccess',
          count: _bundle!.entries.length,
          reason: 'keepPreviousBundle',
        );
      } else {
        final msg = e.toString().toLowerCase();
        if (msg.contains('(429)') ||
            msg.contains('allowed requests has been exceeded')) {
          _generationStatus = TodayRecommendationGenerationStatus.failedRateLimit;
          _cooldownUntil = DateTime.now().add(_rateLimitCooldown);
          _lastRateLimitFailure = true;
        } else {
          _generationStatus = TodayRecommendationGenerationStatus.failedApiError;
          _lastRateLimitFailure = false;
        }
        _errorMessage = 'おすすめを準備できませんでした。少し時間をおいて再試行してください';
        _resultLog(status: 'failed', reason: _failureTypeFromError(e), count: 0);
        _saveLog(saved: false, reason: _failureTypeFromError(e));
      }
    } finally {
      _isLoading = false;
      final generatedAt = _bundle?.generatedAt;
      if (generatedAt != null && (_bundle?.entries.isNotEmpty ?? false)) {
        _lastRegenerateAt = generatedAt;
      }
      notifyListeners();
      _syncRegenerateCooldownTimer();
    }
  }

  Future<void> markSkipped(String productId) async {
    final b = _bundle;
    if (b == null) return;
    TodayRecommendationEntry? skippedEntry;
    final nextEntries = b.entries
        .map((e) {
          if (e.item.productId != productId) return e;
          if (e.decision != TodayRecommendationDecision.pending) return e;
          skippedEntry = e;
          return e.copyWith(decision: TodayRecommendationDecision.skipped);
        })
        .toList(growable: false);
    _bundle = b.copyWith(entries: nextEntries);
    await _repository.save(_bundle!);
    if (skippedEntry != null) {
      await _repository.recordExposureDismissed(
        productId: skippedEntry!.item.productId,
        itemUrl: skippedEntry!.item.itemUrl,
        dismissedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  Future<String?> markAddedCandidate({
    required RakutenManagedProductProvider managedProvider,
    required RakutenSearchItem item,
  }) async {
    final err = await managedProvider.registerCandidate(item);
    if (err != null) return err;
    final b = _bundle;
    if (b == null) return null;
    final nextEntries = b.entries
        .map((e) {
          if (e.item.productId != item.productId) return e;
          return e.copyWith(
            decision: TodayRecommendationDecision.addedCandidate,
          );
        })
        .toList(growable: false);
    _bundle = b.copyWith(entries: nextEntries);
    await _repository.save(_bundle!);
    notifyListeners();
    return null;
  }

  Future<TodayRecommendationBundle> _generate({
    required UserProfile profile,
    required List<RakutenManagedProduct> managedItems,
    required List<SavedShop> savedShops,
    RoomRecommendationProfile? recommendationProfile,
  }) async {
    final generateStartedAt = DateTime.now();
    _trace('generate start');
    _trace('profile nickname=${profile.displayName.trim()}');
    final excludeIds = managedItems
        .where(
          (e) =>
              e.status == RakutenManagedProductStatus.candidate ||
              e.status == RakutenManagedProductStatus.done,
        )
        .map((e) => e.productId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final exposureRecords = _repository.loadExposureRecords();
    var excludedDismissed = 0;
    var excludedShownRecently = 0;
    var excludedZeroReview = 0;
    final pagesUsed = <int>[];
    var genrePageCursors = _repository.loadGenrePageCursors();
    final savedShopIds = savedShops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final favoriteGenreIds = profile.favoriteGenreIdList
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(FavoriteGenreSelectionPolicy.maxForRecommendGeneration)
        .toSet();
    final selectedStyle = profile.selectedSearchStyle;
    final postStyles = <String>{selectedStyle};
    if (kDebugMode) {
      recommendAuditLog('[RECOMMEND_STYLE] selected=$selectedStyle');
      recommendAuditLog('[SEARCH_STYLE_TRACE] selectedStyle=$selectedStyle');
    }
    _trace('favoriteGenreIds=${favoriteGenreIds.join(',')}');
    GenrePrefLog.logLoad(
      favoriteGenreIds: profile.favoriteGenreIdList,
      favoriteGenreNames: profile.favoriteGenres.split(RegExp(r'[、,]+')),
      source: 'recommend',
    );
    _trace('searchPreferences=${postStyles.join(',')}');
    _trace('savedShopCount=${savedShops.length}');
    final keywords = _buildKeywords(profile, managedItems);
    final doneItems = managedItems
        .where((e) => e.status == RakutenManagedProductStatus.done)
        .toList(growable: false);
    final candidateItems = managedItems
        .where((e) => e.status == RakutenManagedProductStatus.candidate)
        .toList(growable: false);
    _trace('doneProductCount=${doneItems.length}');
    _trace('candidateProductCount=${candidateItems.length}');
    final soldOutcomeItems = doneItems
        .where((e) => e.feedbackSoldAt != null)
        .toList(growable: false);
    final reactedOutcomeItems = doneItems
        .where((e) => e.feedbackSoldAt != null || e.feedbackLikedAt != null)
        .toList(growable: false);
    final likedOnlyOutcomeItems = reactedOutcomeItems
        .where((e) => e.feedbackLikedAt != null && e.feedbackSoldAt == null)
        .toList(growable: false);
    final now = DateTime.now();
    final recentCandidates = candidateItems
        .where((c) {
          final d = c.addedAt;
          final day = DateTime(d.year, d.month, d.day);
          final today = DateTime(now.year, now.month, now.day);
          return today.difference(day).inDays <= 14;
        })
        .toList(growable: false);
    final staleCandidates = candidateItems
        .where((c) {
          try {
            final day = DateTime(
              c.addedAt.year,
              c.addedAt.month,
              c.addedAt.day,
            );
            final today = DateTime(now.year, now.month, now.day);
            return today.difference(day).inDays >= 3;
          } catch (_) {
            return false;
          }
        })
        .toList(growable: false);
    if (kDebugMode) {
      recommendAuditLog(
        '[RECOMMEND_START] genreCount=${favoriteGenreIds.length} '
        'savedShopCount=${savedShops.length} doneCount=${doneItems.length} '
        'candidateCount=${candidateItems.length} selectedStyle=$selectedStyle',
      );
    }

    final rawHistoryGenres = _topGenresFromHistory(
      doneItems,
      candidateItems,
      limit: 4,
    );
    final historyGenres = GenrePrefLog.filterHistoryGenresForSearch(
      historyGenreIds: rawHistoryGenres,
      favoriteGenreIds: favoriteGenreIds.toList(growable: false),
      source: 'recommend',
    );
    final reactionProfileForPlans = _buildReactionProfile(
      managedItems: managedItems,
      doneItems: doneItems,
      candidateItems: candidateItems,
    );
    final planSet = TodayRecommendationPlanBuilder.buildPlanSet(
      favoriteGenreIds: favoriteGenreIds.toList(growable: false),
      savedShops: savedShops,
      doneItems: doneItems,
      candidateItems: candidateItems,
      keywords: keywords,
      reactionCommentGenreIds: reactionProfileForPlans.commentGenres,
      reactionLikeGenreIds: reactionProfileForPlans.likeGenres,
      reactionCommentShopIds: reactionProfileForPlans.commentShops,
      reactionLikeShopIds: reactionProfileForPlans.likeShops,
      historyGenreIdsFiltered: historyGenres,
    );
    final profileDiagnosed = recommendationProfile?.isDiagnosed ?? false;
    final mandatoryGenrePlans = profileDiagnosed
        ? ProfileRecommendationIntegration.buildSearchPlans(
                recommendationProfile!,
              )
              .map(_RecommendSearchPlan.fromSpec)
              .toList(growable: false)
        : planSet.favoriteGenrePlans
            .map(_RecommendSearchPlan.fromSpec)
            .toList(growable: false);
    final assistPlan = profileDiagnosed
        ? null
        : planSet.assistPlan != null
        ? _RecommendSearchPlan.fromSpec(planSet.assistPlan!)
        : null;
    final fallbackPlan = profileDiagnosed
        ? null
        : planSet.fallbackPlan != null
            ? _RecommendSearchPlan.fromSpec(planSet.fallbackPlan!)
            : null;
    final plans = <_RecommendSearchPlan>[
      ...mandatoryGenrePlans,
      if (assistPlan != null) assistPlan,
      if (fallbackPlan != null) fallbackPlan,
    ];
    _planLogCount(plans.length);
    _generateLog(
      stage: 'start',
      requestCount: 0,
      planCount: plans.length,
    );

    final pool = <String, RakutenSearchItem>{};
    final metaById = <String, _ItemPoolMeta>{};
    var apiCalls = 0;
    var genreSearchCalls = 0;
    var shopSearchCalls = 0;
    var keywordSearchCalls = 0;
    var excludedCount = 0;
    var excludedBySafety = 0;
    var excludedByDuplicate = 0;
    var excludedNoImage = 0;
    var excludedNoPrice = 0;
    var excludedNoUrl = 0;
    var excludedNoName = 0;
    var allPlansNoItems = true;
    var rateLimited = false;
    var fallbackUsed = false;
    const maxApiHard = TodayRecommendationPolicy.maxApiCallsPerGeneration;
    final sessionId = DateTime.now().millisecondsSinceEpoch;

    final genreWords = UserProfilePreferredGenreWords.fromProfile(profile);
    final reactionProfile = reactionProfileForPlans;
    var assistPlanUsed = false;
    var executedFavoriteGenrePlans = 0;
    var skippedFavoriteGenrePlans = 0;
    String? earlyStopReason;
    var assistPlanExecuted = false;
    var planIndex = 0;
    var apiSkippedByCatalog = false;
    var catalogCollect = const TodayRecommendCatalogCollectResult.empty();
    if (_productCatalogRepository != null &&
        ProductCatalogConfig.kProductCatalogEnabled) {
      final catalogRepo = _productCatalogRepository;
      catalogCollect = TodayRecommendationCatalog.collectIntoPool(
        repository: catalogRepo,
        pool: pool,
        onAcceptMeta: (id, sourceGenreId) {
          final m = metaById.putIfAbsent(id, () => _ItemPoolMeta());
          m.sourceGenreId = sourceGenreId;
        },
        favoriteGenreIds: favoriteGenreIds,
        excludeIds: excludeIds,
        exposureRecords: exposureRecords,
        doneItems: doneItems,
        candidateItems: candidateItems,
        now: now,
      );
      if (TodayRecommendationCatalogPolicy.shouldSkipAllApiPlans(
        catalog: catalogCollect,
        favoriteGenreIds: favoriteGenreIds,
      )) {
        apiSkippedByCatalog = true;
        earlyStopReason = 'catalogSufficient';
      }
    }

    Future<bool> runPlan(_RecommendSearchPlan p) async {
      planIndex += 1;
      final idx = planIndex;
      if (p.phase == 'fallback') fallbackUsed = true;
      if (p.source == 'reactionGenre' ||
          p.source == 'reactionShop' ||
          p.source == 'savedShop' ||
          p.source == 'historyGenre') {
        assistPlanUsed = true;
        assistPlanExecuted = true;
      }
      _phaseLog(p.phase);
      final condition = _conditionWithPostStyles(
        keyword: p.keyword,
        postStyles: postStyles,
        genreId: p.genreId,
        shopCode: p.shopCode,
        relaxLevel: p.relaxLevel,
        sortOverride: p.sortOverride,
      );
      final sortKey = condition.sort ?? TodayRecommendationPolicy.defaultApiSort;
      var startPage = 1;
      String? genrePageKey;
      if (p.genreId != null && p.genreId!.trim().isNotEmpty) {
        genrePageKey = TodayRecommendGenrePageStore.cursorKey(
          p.genreId!.trim(),
          sortKey,
        );
        startPage = TodayRecommendGenrePageStore.resolveNextPage(
          cursor: genrePageCursors[genrePageKey],
          sort: sortKey,
          now: now,
        );
      }
      _planLogDetailed(
        index: idx,
        phase: p.phase,
        relaxLevel: p.relaxLevel,
        source: p.source,
        keyword: p.keyword,
        genreId: p.genreId,
        shopCode: p.shopCode,
        condition: condition,
        postStyles: postStyles,
      );
      _apiLogDetailed(
        planIndex: idx,
        keyword: p.keyword,
        genreId: p.genreId,
        shopCode: p.shopCode,
        page: startPage,
      );

      List<RakutenSearchItem> list;
      try {
        list = await _runSearchPlan(
          phase: p.phase,
          source: p.source,
          planIndex: idx,
          condition: condition,
          excludeIds: excludeIds,
          exposureRecords: exposureRecords,
          startPage: startPage,
          onExposureExclude: (reason) {
            if (reason.startsWith('dismissed')) {
              excludedDismissed += 1;
            } else if (reason.contains('shown')) {
              excludedShownRecently += 1;
            }
          },
          onZeroReviewExclude: () => excludedZeroReview += 1,
        );
      } catch (e) {
        if (_isRateLimitError(e)) {
          rateLimited = true;
          return false;
        }
        recommendAuditLog('[RECOMMEND] planFailed planIndex=$idx error=$e');
        apiCalls += 1;
        return true;
      }
      apiCalls += 1;
      pagesUsed.add(startPage);
      if (genrePageKey != null) {
        var usable = 0;
        for (final item in list) {
          final exclusion = _excludeReason(
            item: item,
            excludeIds: excludeIds,
            doneItems: doneItems,
            candidateItems: candidateItems,
            dedup: const {},
            checkDedup: false,
            condition: condition,
            exposureRecords: exposureRecords,
          );
          if (exclusion == null) usable += 1;
        }
        genrePageCursors[genrePageKey] = TodayRecommendGenrePageStore.advance(
          previous: genrePageCursors[genrePageKey],
          sort: sortKey,
          pageUsed: startPage,
          rawCount: list.length,
          usableCount: usable,
          managedExcludedCount: list.length - usable,
          now: now,
        );
      }
      if (p.genreId != null && p.genreId!.trim().isNotEmpty) {
        genreSearchCalls += 1;
      } else if (p.shopCode != null && p.shopCode!.trim().isNotEmpty) {
        shopSearchCalls += 1;
      } else {
        keywordSearchCalls += 1;
      }
      if (list.isNotEmpty) allPlansNoItems = false;
      for (final item in list) {
        _trace('raw item itemCode=${item.productId} title=${item.itemName}');
        final exclusion = _excludeReason(
          item: item,
          excludeIds: excludeIds,
          doneItems: doneItems,
          candidateItems: candidateItems,
          dedup: pool,
          condition: condition,
          exposureRecords: exposureRecords,
        );
        if (exclusion != null) {
          excludedCount += 1;
          switch (exclusion) {
            case 'safetyBlocked':
              excludedBySafety += 1;
            case 'noImage':
              excludedNoImage += 1;
            case 'noPrice':
              excludedNoPrice += 1;
            case 'noUrl':
              excludedNoUrl += 1;
            case 'missingTitle':
              excludedNoName += 1;
            case 'lowReviewCount':
            case 'lowReviewAverage':
            case 'zeroReview':
              excludedZeroReview += 1;
            case 'dismissedRecently':
            case 'dismissedUrlMatch':
              excludedDismissed += 1;
            case 'shownRecently':
            case 'shownUrlMatch':
              excludedShownRecently += 1;
            case 'duplicate':
            case 'alreadyCandidate':
            case 'alreadyDone':
              excludedByDuplicate += 1;
            default:
              break;
          }
          _trace('exclude reason=$exclusion');
          continue;
        }
        _trace('accepted itemCode=${item.productId} title=${item.itemName}');
        final id = item.productId.trim();
        pool[id] = item;
        final m = metaById.putIfAbsent(id, () => _ItemPoolMeta());
        if (p.genreId != null && p.genreId!.trim().isNotEmpty) {
          m.sourceGenreId = p.genreId!.trim();
        }
        if (p.phase == 'personal' || p.phase == 'fallback') {
          m.fromPersonalPhase = true;
        }
        if (p.phase == 'relaxed') m.fromRelaxedPhase = true;
        if (p.phase == 'discovery') m.fromDiscoveryPhase = true;
        if (p.source == 'shop') m.fromShopPlan = true;
      }
      return true;
    }

    if (!apiSkippedByCatalog) {
      for (var i = 0; i < mandatoryGenrePlans.length; i++) {
        if (TodayRecommendationExecutionPolicy.shouldSkipMandatoryGenrePlan(
          apiCallsSoFar: apiCalls,
        )) {
          earlyStopReason = 'apiCapReachedBeforeRemainingGenres';
          break;
        }
        final ok = await runPlan(mandatoryGenrePlans[i]);
        if (!ok) break;
        executedFavoriteGenrePlans += 1;
      }
    }

    skippedFavoriteGenrePlans =
        mandatoryGenrePlans.length - executedFavoriteGenrePlans;

    final recentlyShownProductIds = exposureRecords.entries
        .where((e) => e.value.shownAt != null)
        .map((e) => e.key.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final previewAfterGenres = _finalizeFromPool(
      pool: pool,
      metaById: metaById,
      favoriteGenreIds: favoriteGenreIds,
      favoriteGenreIdList: favoriteGenreIds.toList(growable: false),
      savedShopIds: savedShopIds,
      preferredGenreWords: genreWords,
      doneItems: doneItems,
      candidateItems: candidateItems,
      postStyles: postStyles,
      soldOutcomeItems: soldOutcomeItems,
      reactedOutcomeItems: reactedOutcomeItems,
      likedOnlyOutcomeItems: likedOnlyOutcomeItems,
      recentCandidatesForBridge: recentCandidates,
      staleCandidatesForBridge: staleCandidates,
      reactionProfile: reactionProfile,
      recommendationProfile: recommendationProfile,
      excludeProductIds: excludeIds,
      recentlyShownProductIds: recentlyShownProductIds,
    );

    if (!apiSkippedByCatalog &&
        assistPlan != null &&
        TodayRecommendationExecutionPolicy.shouldRunAssistPlan(
          finalizedEntryCount: previewAfterGenres.entries.length,
          hasAssistPlan: true,
          apiCallsSoFar: apiCalls,
        )) {
      final ok = await runPlan(assistPlan);
      if (!ok) {
        // rate limited
      }
    } else if (assistPlan != null &&
        previewAfterGenres.entries.length >=
            TodayRecommendationPolicy.displayCap) {
      earlyStopReason ??= 'assistSkippedSufficientFinalItems';
    }

    if (!apiSkippedByCatalog && fallbackPlan != null && apiCalls < maxApiHard) {
      await runPlan(fallbackPlan);
    }

    _planExecutionSummaryLog(
      plannedFavoriteGenres: mandatoryGenrePlans.length,
      executedFavoriteGenrePlans: executedFavoriteGenrePlans,
      skippedFavoriteGenrePlans: skippedFavoriteGenrePlans,
      assistPlanExecuted: assistPlanExecuted,
      apiCalls: apiCalls,
      earlyStopReason: earlyStopReason,
    );

    final finalized = _finalizeFromPool(
      pool: pool,
      metaById: metaById,
      favoriteGenreIds: favoriteGenreIds,
      favoriteGenreIdList: favoriteGenreIds.toList(growable: false),
      savedShopIds: savedShopIds,
      preferredGenreWords: genreWords,
      doneItems: doneItems,
      candidateItems: candidateItems,
      postStyles: postStyles,
      soldOutcomeItems: soldOutcomeItems,
      reactedOutcomeItems: reactedOutcomeItems,
      likedOnlyOutcomeItems: likedOnlyOutcomeItems,
      recentCandidatesForBridge: recentCandidates,
      staleCandidatesForBridge: staleCandidates,
      reactionProfile: reactionProfile,
      recommendationProfile: recommendationProfile,
      excludeProductIds: excludeIds,
      recentlyShownProductIds: recentlyShownProductIds,
    );

    if (pool.isEmpty && allPlansNoItems) {
      _resultLog(status: 'failed', reason: 'allPlansNoItems', count: 0);
    }

    await _repository.saveGenrePageCursors(genrePageCursors);

    final entries = finalized.entries;

    if (kDebugMode) {
      recommendAuditLog('[RECOMMEND] apiCalls=$apiCalls poolSize=${pool.length}');
      recommendAuditLog('[RECOMMEND] final count: ${entries.length}');
      recommendAuditLog(
        '[RECOMMEND_BUCKET] personal=${finalized.personalCount} '
        'relaxed=${finalized.relaxedCount} discovery=${finalized.discoveryCount} '
        'total=${entries.length}',
      );
      if (entries.isEmpty) {
        importantDebugLog('[RECOMMEND_RESULT] status=failed count=0');
      }
      recommendAuditLog(
        '[RECOMMEND_RESULT] style=$selectedStyle personalCount=${finalized.personalCount} '
        'discoveryCount=${finalized.discoveryCount} total=${entries.length}',
      );
    }
    _trace('finalCandidateCount=${entries.length}');
    _trace('failureType=${entries.isEmpty ? 'empty' : 'none'}');
    if (rateLimited && entries.isNotEmpty) {
      _resultLog(status: 'partialSuccess', count: entries.length);
    } else {
      _resultLog(
        status: entries.isEmpty ? 'failed' : 'success',
        count: entries.length,
        reason: entries.isEmpty ? 'allPlansNoItems' : null,
      );
    }
    if (rateLimited && entries.isEmpty) {
      throw Exception('Rakuten API rate limit (429)');
    }
    final durationMs = DateTime.now().difference(generateStartedAt).inMilliseconds;
    _generateLog(
      stage: 'end',
      requestCount: apiCalls,
      planCount: plans.length,
    );
    _summaryLog(
      totalApiRequests: apiCalls,
      totalPlans: plans.length,
      selectedCount: entries.length,
      excludedCount: excludedCount,
      durationMs: durationMs,
    );
    logTodayRecommendApiUsage(
      sessionId: sessionId,
      phase: 'finalize',
      apiCalls: apiCalls,
      genreSearchCalls: genreSearchCalls,
      shopSearchCalls: shopSearchCalls,
      keywordSearchCalls: keywordSearchCalls,
      excludedBySafety: excludedBySafety,
      excludedByDuplicate: excludedByDuplicate,
      finalItems: entries.length,
    );
    _finalQualitySummaryLog(entries: entries);
    _generationSummaryLog(
      plannedFavoriteGenres: mandatoryGenrePlans.length,
      executedFavoriteGenrePlans: executedFavoriteGenrePlans,
      apiCalls: apiCalls,
      pagesUsed: pagesUsed,
      rawItems: pool.length,
      excludedManaged: excludedByDuplicate,
      excludedDismissed: excludedDismissed,
      excludedShownRecently: excludedShownRecently,
      excludedNoImage: excludedNoImage,
      excludedNoPrice: excludedNoPrice,
      excludedSafety: excludedBySafety,
      excludedZeroReview: excludedZeroReview,
      finalItems: entries.length,
      finalGenreDistribution: finalized.sourceGenreDistribution,
      finalShopDistribution: finalized.shopDistribution,
      fallbackUsed: fallbackUsed,
      assistPlanUsed: assistPlanUsed,
    );
    _qualitySummaryLog(
      plans: plans.length,
      apiCalls: apiCalls,
      rawItems: pool.length,
      excludedManaged: excludedByDuplicate,
      excludedNoImage: excludedNoImage,
      excludedNoPrice: excludedNoPrice,
      excludedNoName: excludedNoName,
      excludedNoUrl: excludedNoUrl,
      excludedSafety: excludedBySafety,
      deduped: pool.length,
      finalItems: entries.length,
      plannedFavoriteGenres: mandatoryGenrePlans.length,
      executedFavoriteGenrePlans: executedFavoriteGenrePlans,
      skippedFavoriteGenrePlans: skippedFavoriteGenrePlans,
      usedAssistPlan: assistPlanUsed,
      fallbackUsed: fallbackUsed,
    );
    _todayRecommendCatalogSummaryLog(
      enabled: ProductCatalogConfig.kProductCatalogEnabled &&
          _productCatalogRepository != null,
      catalog: catalogCollect,
      apiSkippedByCatalog: apiSkippedByCatalog,
      apiCalls: apiCalls,
      finalItems: entries.length,
    );
    _scheduleRecommendCatalogUpsert(pool.values);
    return TodayRecommendationBundle(
      localDateKey: _localDateKey(DateTime.now()),
      generatedAt: DateTime.now(),
      entries: entries,
    );
  }

  List<String> _topGenresFromHistory(
    List<RakutenManagedProduct> doneItems,
    List<RakutenManagedProduct> candidateItems, {
    required int limit,
  }) {
    final counts = <String, int>{};
    for (final e in [...doneItems, ...candidateItems]) {
      final gid = e.genreId.trim();
      if (gid.isEmpty) continue;
      counts[gid] = (counts[gid] ?? 0) + 1;
    }
    if (counts.isEmpty) return const [];
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList(growable: false);
  }

  bool _passesBackfillQualityGate(
    RakutenSearchItem item, {
    required Set<String> postStyles,
  }) {
    if (!SearchResultQualityFilter.passesDisplayQuality(item)) return false;
    if (_recommendRejectReason(item, postStyles: postStyles) != null) {
      return false;
    }
    if (item.itemPrice < 500 || item.itemPrice >= 50000) return false;
    return item.reviewCount >= 3 || item.reviewAverage >= 4.0;
  }

  ({
    List<TodayRecommendationEntry> entries,
    int personalCount,
    int relaxedCount,
    int discoveryCount,
    Map<String, int> sourceGenreDistribution,
    Map<String, int> shopDistribution,
  })
  _finalizeFromPool({
    required Map<String, RakutenSearchItem> pool,
    required Map<String, _ItemPoolMeta> metaById,
    required Set<String> favoriteGenreIds,
    required List<String> favoriteGenreIdList,
    required Set<String> savedShopIds,
    required Set<String> preferredGenreWords,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required Set<String> postStyles,
    required List<RakutenManagedProduct> soldOutcomeItems,
    required List<RakutenManagedProduct> reactedOutcomeItems,
    required List<RakutenManagedProduct> likedOnlyOutcomeItems,
    required List<RakutenManagedProduct> recentCandidatesForBridge,
    required List<RakutenManagedProduct> staleCandidatesForBridge,
    required _ReactionProfile reactionProfile,
    RoomRecommendationProfile? recommendationProfile,
    Set<String> excludeProductIds = const {},
    Set<String> recentlyShownProductIds = const {},
  }) {
    final scored = <_ScoredRecommendation>[];
    for (final item in pool.values) {
      var scoredItem = _scoreRecommendationForBucket(
        item,
        meta: metaById[item.productId.trim()] ?? _ItemPoolMeta(),
        favoriteGenreIds: favoriteGenreIds,
        savedShopIds: savedShopIds,
        preferredGenreWords: preferredGenreWords,
        doneItems: doneItems,
        candidateItems: candidateItems,
        postStyles: postStyles,
        soldOutcomeItems: soldOutcomeItems,
        reactedOutcomeItems: reactedOutcomeItems,
        likedOnlyOutcomeItems: likedOnlyOutcomeItems,
        recentCandidatesForBridge: recentCandidatesForBridge,
        staleCandidatesForBridge: staleCandidatesForBridge,
        reactionProfile: reactionProfile,
      );
      if (scoredItem != null &&
          (recommendationProfile?.isDiagnosed ?? false)) {
        final blended = ProfileRecommendationIntegration.blendScore(
          item: item,
          profile: recommendationProfile!,
          baseScore: scoredItem.score,
          excludeProductIds: excludeProductIds,
          recentlyShownProductIds: recentlyShownProductIds,
          collectedProductIds: excludeProductIds,
        );
        if (blended.blendedScore == double.negativeInfinity) {
          scoredItem = null;
        } else {
          scoredItem = _ScoredRecommendation(
            item: scoredItem.item,
            score: blended.blendedScore,
            priceScore: scoredItem.priceScore,
            reason: scoredItem.reason,
            section: scoredItem.section,
          );
        }
      }
      if (scoredItem != null) scored.add(scoredItem);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (kDebugMode) {
      recommendAuditLog(
        '[RECOMMEND_POOL] raw=${pool.length} valid=${scored.length} scored=${scored.length}',
      );
    }

    if (recommendationProfile?.isDiagnosed ?? false) {
      final profileCandidates = <({
        RakutenSearchItem item,
        double score,
        double priceScore,
        TodayRecommendationSection section,
        RecommendationScoreResult profileScore,
      })>[];
      for (final e in scored) {
        final profileScore = RecommendationScoringService.score(
          item: e.item,
          profile: recommendationProfile!,
          excludeProductIds: excludeProductIds,
          recentlyShownProductIds: recentlyShownProductIds,
          collectedProductIds: excludeProductIds,
        );
        if (profileScore.totalScore == double.negativeInfinity) continue;
        profileCandidates.add((
          item: e.item,
          score: e.score,
          priceScore: e.priceScore,
          section: e.section,
          profileScore: profileScore,
        ));
      }
      final profileEntries = ProfileRecommendationIntegration.pickTopThreeWithRoles(
        candidates: profileCandidates,
        profile: recommendationProfile!,
      );
      final shopDistribution = <String, int>{};
      for (final e in profileEntries) {
        final shop = e.item.shopName.trim().isEmpty
            ? (e.item.shopCode.trim().isEmpty ? '-' : e.item.shopCode.trim())
            : e.item.shopName.trim();
        shopDistribution[shop] = (shopDistribution[shop] ?? 0) + 1;
      }
      return (
        entries: profileEntries,
        personalCount: profileEntries
            .where((e) => e.section == TodayRecommendationSection.sellable)
            .length,
        relaxedCount: profileEntries
            .where((e) => e.section == TodayRecommendationSection.popular)
            .length,
        discoveryCount: profileEntries
            .where((e) => e.section == TodayRecommendationSection.fresh)
            .length,
        sourceGenreDistribution: const {},
        shopDistribution: shopDistribution,
      );
    }

    final picked = _pickBalancedBySection(
      scored,
      favoriteGenreIdList: favoriteGenreIdList,
      metaById: metaById,
    );
    if (kDebugMode) {
      recommendAuditLog('[RECOMMEND_SELECT] strictSelected=${picked.length}');
    }
    final entryList = picked
        .map(
          (e) => TodayRecommendationEntry(
            item: e.item,
            reason: e.reason,
            section: e.section,
            score: e.score,
            priceScore: e.priceScore,
          ),
        )
        .toList(growable: true);

    if (entryList.length < 10) {
      final selectedIds = entryList.map((e) => e.item.productId.trim()).toSet();
      var added = 0;
      for (final e in scored) {
        if (entryList.length >= 10) break;
        final id = e.item.productId.trim();
        if (id.isEmpty || selectedIds.contains(id)) continue;
        if (!_passesBackfillQualityGate(e.item, postStyles: postStyles)) continue;
        entryList.add(
          TodayRecommendationEntry(
            item: e.item,
            reason: e.reason,
            section: e.section,
            score: e.score,
            priceScore: e.priceScore,
          ),
        );
        selectedIds.add(id);
        added += 1;
      }
      if (kDebugMode && added > 0) {
        recommendAuditLog('[RECOMMEND_BACKFILL] fromExistingPool=true added=$added');
        recommendAuditLog('[RECOMMEND_BACKFILL] reason=diversityRelaxed');
        recommendAuditLog('[RECOMMEND_BACKFILL] added=$added total=${entryList.length}');
      }
    }
    final entries = entryList
        .where((e) => _passesRecommendFinalDisplayGate(e.item))
        .toList(growable: false);

    final sourceGenreByProductId = <String, String>{};
    for (final e in entries) {
      final id = e.item.productId.trim();
      if (id.isEmpty) continue;
      sourceGenreByProductId[id] =
          metaById[id]?.sourceGenreId.trim() ?? '';
    }
    final sourceGenreDistribution =
        TodayRecommendationGenreDistribution.distributionBySourceGenre(
      pickedProductIds: entries.map((e) => e.item.productId.trim()).toList(),
      sourceGenreByProductId: sourceGenreByProductId,
      favoriteGenreIds: favoriteGenreIdList,
    );
    final shopDistribution = <String, int>{};
    for (final e in entries) {
      final shop = e.item.shopName.trim().isEmpty
          ? (e.item.shopCode.trim().isEmpty ? '-' : e.item.shopCode.trim())
          : e.item.shopName.trim();
      shopDistribution[shop] = (shopDistribution[shop] ?? 0) + 1;
    }

    final personalCount = entries
        .where((e) => e.section == TodayRecommendationSection.popular)
        .length;
    final relaxedCount = entries
        .where((e) => e.section == TodayRecommendationSection.sellable)
        .length;
    final discoveryCount = entries
        .where((e) => e.section == TodayRecommendationSection.fresh)
        .length;
    return (
      entries: entries,
      personalCount: personalCount,
      relaxedCount: relaxedCount,
      discoveryCount: discoveryCount,
      sourceGenreDistribution: sourceGenreDistribution,
      shopDistribution: shopDistribution,
    );
  }

  /// あなた向け〜7、保存ショップ枠〜3、発掘〜3 を優先しつつ最大10件。
  /// 保存ジャンル（sourceGenreId）の分散を優先する。
  List<_ScoredRecommendation> _pickBalancedBySection(
    List<_ScoredRecommendation> scored, {
    required List<String> favoriteGenreIdList,
    required Map<String, _ItemPoolMeta> metaById,
  }) {
    if (scored.isEmpty) return const [];

    final pickInputs = scored
        .map(
          (e) => TodayRecommendPickCandidate(
            productId: e.item.productId.trim(),
            score: e.score,
            sourceGenreId:
                metaById[e.item.productId.trim()]?.sourceGenreId ?? '',
            itemGenreId: e.item.genreId.trim(),
            shopCode: e.item.shopCode.trim(),
            mainTopicKey: _mainTopicKey(e.item.itemName),
            titleToken: _titleCoreToken(e.item.itemName),
            priceBand: _priceBand(e.item.itemPrice),
          ),
        )
        .where((e) => e.productId.isNotEmpty)
        .toList(growable: false);

    final pickedIds = TodayRecommendationGenreDistribution.pickProductIds(
      candidates: pickInputs,
      favoriteGenreIds: favoriteGenreIdList,
    );
    final byId = {for (final e in scored) e.item.productId.trim(): e};
    final selected = <_ScoredRecommendation>[];
    for (final id in pickedIds) {
      final item = byId[id];
      if (item != null) selected.add(item);
    }
    if (kDebugMode) {
      final dist =
          TodayRecommendationGenreDistribution.distributionBySourceGenre(
        pickedProductIds: pickedIds,
        sourceGenreByProductId: {
          for (final id in pickedIds)
            id: metaById[id]?.sourceGenreId.trim() ?? '',
        },
        favoriteGenreIds: favoriteGenreIdList,
      );
      recommendAuditLog(
        '[TODAY_RECOMMEND_FINAL_DISTRIBUTION] '
        'finalItems=${selected.length} sourceGenreDistribution='
        '${dist.entries.map((e) => '${e.key}:${e.value}').join('|')}',
      );
    }
    return selected;
  }

  Future<List<RakutenSearchItem>> _runSearchPlan({
    required String phase,
    required String source,
    required int planIndex,
    required RakutenProductSearchCondition condition,
    required Set<String> excludeIds,
    required Map<String, TodayRecommendExposureRecord> exposureRecords,
    required int startPage,
    void Function(String reason)? onExposureExclude,
    void Function()? onZeroReviewExclude,
  }) async {
    _apiLogStart(index: planIndex, page: startPage, phase: phase);
    if (ApiRequestCoordinator.manualSearchRunning) {
      final ready = await ApiRequestCoordinator.waitForManualSearchIdle();
      if (!ready) {
        if (kDebugMode) {
          recommendAuditLog(
            '[SEARCH_BACKGROUND_CONFLICT_AUDIT] manualSearchRunning=true '
            'todayRecommendRunning=true roomImportRunning=false '
            'metadataEnrichRunning=false priority=manualSearch '
            'recommendPlanDeferred=true',
          );
        }
        return const <RakutenSearchItem>[];
      }
    }
    try {
      final list = await _searchRepository.search(
        condition: condition,
        maxPages: 1,
        startPage: startPage,
        searchPurpose: RakutenSearchPurpose.recommendation,
      );
      _apiLogStatus(phase: phase, status: 200, rawCount: list.length);
      final reasonCounts = <String, int>{};
      final afterExclude = list.where((e) {
        final reason = _excludeReason(
          item: e,
          excludeIds: excludeIds,
          doneItems: const <RakutenManagedProduct>[],
          candidateItems: const <RakutenManagedProduct>[],
          dedup: const <String, RakutenSearchItem>{},
          checkDedup: false,
          condition: condition,
          exposureRecords: exposureRecords,
        );
        if (reason == null) return true;
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        if (reason.startsWith('dismissed') || reason.contains('shown')) {
          onExposureExclude?.call(reason);
        }
        if (reason == 'zeroReview') {
          onZeroReviewExclude?.call();
        }
        return false;
      }).length;
      _filterLog(
        raw: list.length,
        afterExclude: afterExclude,
        reasonCounts: reasonCounts,
      );
      return list;
    } catch (e) {
      final msg = e.toString();
      final apiStatus = _extractStatusCode(msg) ?? 'error';
      _apiLogStatus(phase: phase, status: apiStatus, rawCount: 0);
      if (msg.contains('(429)') ||
          msg.toLowerCase().contains('allowed requests has been exceeded')) {
        _resultLog(status: 'failed', reason: 'rateLimit', count: 0);
      } else if (msg.contains('(400)') || msg.contains('(500)')) {
        _resultLog(status: 'failed', reason: 'apiError', count: 0);
      } else {
        _resultLog(status: 'failed', reason: 'exception', count: 0);
      }
      rethrow;
    }
  }

  String? _extractStatusCode(String message) {
    final m = RegExp(r'\((\d{3})\)').firstMatch(message);
    return m?.group(1);
  }

  void _trace(String message) {
    recommendAuditLog('[RECOMMEND_TRACE] $message');
  }

  String? _excludeReason({
    required RakutenSearchItem item,
    required Set<String> excludeIds,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required Map<String, RakutenSearchItem> dedup,
    bool checkDedup = true,
    RakutenProductSearchCondition? condition,
    Map<String, TodayRecommendExposureRecord> exposureRecords =
        const {},
  }) {
    final id = item.productId.trim();
    if (id.isEmpty) return 'missingItemCode';
    if (item.reviewCount <= 0 || item.reviewAverage <= 0) {
      return 'zeroReview';
    }
    final quality = SearchResultQualityFilter.exclusionReason(
      item,
      condition: condition,
      checkSafety: false,
    );
    if (quality != null) {
      return switch (quality) {
        SearchQualityExcludeReason.noName => 'missingTitle',
        SearchQualityExcludeReason.noUrl => 'noUrl',
        SearchQualityExcludeReason.noImage => 'noImage',
        SearchQualityExcludeReason.noPrice => 'noPrice',
        SearchQualityExcludeReason.safety => 'safetyBlocked',
        SearchQualityExcludeReason.reviewCount => 'lowReviewCount',
        SearchQualityExcludeReason.reviewAverage => 'lowReviewAverage',
      };
    }
    if (excludeIds.contains(id)) {
      if (doneItems.any((e) => e.productId.trim() == id)) return 'alreadyDone';
      if (candidateItems.any((e) => e.productId.trim() == id)) {
        return 'alreadyCandidate';
      }
      return 'other';
    }
    if (checkDedup && dedup.containsKey(id)) return 'duplicate';
    final exposureReason = TodayRecommendExposurePolicy.exclusionReason(
      productId: id,
      itemUrl: item.itemUrl,
      recordsById: exposureRecords,
      now: DateTime.now(),
    );
    if (exposureReason != null) return exposureReason;
    if (ProductSafetyFilter.isBlockedProduct(
      itemName: item.itemName,
      shopName: item.shopName,
      genreName: item.genreName,
      itemUrl: item.itemUrl,
      affiliateUrl: item.affiliateUrl,
    )) {
      final reasons = ProductSafetyFilter.blockedReasons(
        itemName: item.itemName,
        shopName: item.shopName,
        genreName: item.genreName,
      );
      ProductSafetyFilter.logFilter(
        source: 'recommend',
        itemCode: id,
        title: item.itemName,
        shopName: item.shopName,
        genreName: item.genreName,
        blocked: true,
        reasons: reasons,
      );
      return 'safetyBlocked';
    }
    return null;
  }

  void _planLogCount(int count) {
    recommendAuditLog('[RECOMMEND_PLAN] count=$count');
  }

  void _phaseLog(String phase) {
    recommendAuditLog('[RECOMMEND_PHASE] phase=$phase');
  }

  void _planLogDetailed({
    required int index,
    required String phase,
    required int relaxLevel,
    required String source,
    required String keyword,
    required String? genreId,
    required String? shopCode,
    required RakutenProductSearchCondition condition,
    required Set<String> postStyles,
  }) {
    final styleKey = _resolvePrimaryStyle(postStyles);
    recommendAuditLog(
      '[RECOMMEND_PLAN] phase=$phase relax=$relaxLevel source=$source index=$index '
      'keyword=$keyword genreId=${genreId ?? ''} shopCode=${shopCode ?? ''} '
      'style=$styleKey minPrice=${condition.minPrice ?? ''} '
      'maxPrice=${condition.maxPrice ?? ''} sort=${condition.sort ?? ''}',
    );
  }

  void _apiLogStart({
    required int index,
    required int page,
    required String phase,
  }) {
    recommendAuditLog('$_logTagApi phase=$phase start index=$index page=$page');
  }

  void _apiLogStatus({
    required String phase,
    required Object status,
    required int rawCount,
  }) {
    recommendAuditLog('$_logTagApi phase=$phase status=$status rawCount=$rawCount');
  }

  void _apiLogDetailed({
    required int planIndex,
    required String keyword,
    required String? genreId,
    required String? shopCode,
    required int page,
  }) {
    recommendAuditLog(
      '$_logTagApi planIndex=$planIndex keyword=$keyword '
      'genreId=${genreId ?? ''} shopCode=${shopCode ?? ''} page=$page',
    );
  }

  void _filterLog({
    required int raw,
    required int afterExclude,
    required Map<String, int> reasonCounts,
  }) {
    recommendAuditLog(
      '[RECOMMEND_FILTER] raw=$raw afterExclude=$afterExclude reasonCounts=$reasonCounts',
    );
  }

  void _resultLog({required String status, String? reason, int? count}) {
    final isImportant =
        status == 'failed' ||
        status == 'partialSuccess' ||
        (reason != null && reason.isNotEmpty);
    final emit = isImportant ? importantDebugLog : recommendAuditLog;
    if (reason != null && count != null) {
      emit('[RECOMMEND_RESULT] status=$status count=$count reason=$reason');
      return;
    }
    if (reason != null) {
      emit('[RECOMMEND_RESULT] status=$status reason=$reason');
      return;
    }
    emit('[RECOMMEND_RESULT] status=$status count=${count ?? 0}');
  }

  void _saveLog({
    bool? saved,
    bool keepPreviousBundle = false,
    String? reason,
    int? count,
  }) {
    if (keepPreviousBundle) {
      importantDebugLog(
        '[RECOMMEND_SAVE] keepPreviousBundle=true reason=${reason ?? ''}',
      );
      return;
    }
    if (saved == true) {
      recommendAuditLog('[RECOMMEND_SAVE] savedBundle=true count=${count ?? 0}');
      return;
    }
    importantDebugLog(
      '[RECOMMEND_SAVE] savedBundle=false reason=${reason ?? 'unknown'}',
    );
  }

  bool _isRateLimitError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('(429)') ||
        msg.contains('allowed requests has been exceeded');
  }

  void _guard(String message) {
    _lastGuardReason = message.trim();
    importantDebugLog('$_logTagGuard $message');
  }

  void logTodayRecommendCooldown({required String trigger}) {
    final status = manualRegenerateCooldownStatus();
    importantDebugLog(
      '[TODAY_RECOMMEND_COOLDOWN] canRegenerate=${status.canRegenerate} '
      'remainingSeconds=${status.remainingSeconds} '
      'remainingMinutes=${status.remainingMinutes} '
      'nextAvailableAt=${status.nextAvailableAt?.toIso8601String() ?? '-'} '
      'reason=${status.reason.isEmpty ? trigger : status.reason}',
    );
  }

  void _generationSummaryLog({
    required int plannedFavoriteGenres,
    required int executedFavoriteGenrePlans,
    required int apiCalls,
    required List<int> pagesUsed,
    required int rawItems,
    required int excludedManaged,
    required int excludedDismissed,
    required int excludedShownRecently,
    required int excludedNoImage,
    required int excludedNoPrice,
    required int excludedSafety,
    required int excludedZeroReview,
    required int finalItems,
    required Map<String, int> finalGenreDistribution,
    required Map<String, int> finalShopDistribution,
    required bool fallbackUsed,
    required bool assistPlanUsed,
  }) {
    debugSummaryLog(
      '[TODAY_RECOMMEND_GENERATION_SUMMARY] '
      'plannedFavoriteGenres=$plannedFavoriteGenres '
      'executedFavoriteGenrePlans=$executedFavoriteGenrePlans '
      'apiCalls=$apiCalls pagesUsed=${pagesUsed.join(',')} '
      'rawItems=$rawItems excludedManaged=$excludedManaged '
      'excludedDismissed=$excludedDismissed '
      'excludedShownRecently=$excludedShownRecently '
      'excludedNoImage=$excludedNoImage excludedNoPrice=$excludedNoPrice '
      'excludedSafety=$excludedSafety excludedZeroReview=$excludedZeroReview '
      'finalItems=$finalItems fallbackUsed=$fallbackUsed '
      'assistPlanUsed=$assistPlanUsed',
    );
    debugSummaryLog(
      '[TODAY_RECOMMEND_FINAL_DISTRIBUTION] '
      'finalGenreDistribution='
      '${finalGenreDistribution.entries.map((e) => '${e.key}:${e.value}').join('|')} '
      'finalShopDistribution='
      '${finalShopDistribution.entries.map((e) => '${e.key}:${e.value}').join('|')}',
    );
  }

  void _planExecutionSummaryLog({
    required int plannedFavoriteGenres,
    required int executedFavoriteGenrePlans,
    required int skippedFavoriteGenrePlans,
    required bool assistPlanExecuted,
    required int apiCalls,
    required String? earlyStopReason,
  }) {
    debugSummaryLog(
      '[TODAY_RECOMMEND_PLAN_EXECUTION_SUMMARY] '
      'plannedFavoriteGenres=$plannedFavoriteGenres '
      'executedFavoriteGenrePlans=$executedFavoriteGenrePlans '
      'skippedFavoriteGenrePlans=$skippedFavoriteGenrePlans '
      'assistPlanExecuted=$assistPlanExecuted apiCalls=$apiCalls '
      'earlyStopReason=${earlyStopReason ?? '-'}',
    );
  }

  void _finalQualitySummaryLog({
    required List<TodayRecommendationEntry> entries,
  }) {
    var zeroReview = 0;
    var missingImage = 0;
    var missingPrice = 0;
    final genreDist = <String, int>{};
    final shopDist = <String, int>{};
    for (final e in entries) {
      final item = e.item;
      if (item.reviewCount <= 0 || item.reviewAverage <= 0) zeroReview += 1;
      if (!SearchResultQualityFilter.hasDisplayableImage(item)) {
        missingImage += 1;
      }
      if (!SearchResultQualityFilter.hasDisplayablePrice(item)) missingPrice += 1;
      final g = item.genreName.trim().isNotEmpty
          ? item.genreName.trim()
          : (item.genreId.trim().isEmpty ? '-' : item.genreId.trim());
      genreDist[g] = (genreDist[g] ?? 0) + 1;
      final s = item.shopName.trim().isEmpty ? '-' : item.shopName.trim();
      shopDist[s] = (shopDist[s] ?? 0) + 1;
    }
    debugSummaryLog(
      '[TODAY_RECOMMEND_FINAL_QUALITY_SUMMARY] finalItems=${entries.length} '
      'zeroReviewItems=$zeroReview missingImageItems=$missingImage '
      'missingPriceItems=$missingPrice '
      'genreDistribution=${genreDist.entries.map((e) => '${e.key}:${e.value}').join('|')} '
      'shopDistribution=${shopDist.entries.map((e) => '${e.key}:${e.value}').join('|')}',
    );
  }

  void _qualitySummaryLog({
    required int plans,
    required int apiCalls,
    required int rawItems,
    required int excludedManaged,
    required int excludedNoImage,
    required int excludedNoPrice,
    required int excludedNoName,
    required int excludedNoUrl,
    required int excludedSafety,
    required int deduped,
    required int finalItems,
    required int plannedFavoriteGenres,
    required int executedFavoriteGenrePlans,
    required int skippedFavoriteGenrePlans,
    required bool usedAssistPlan,
    required bool fallbackUsed,
  }) {
    final cooldown = manualRegenerateCooldownStatus();
    recommendAuditLog(
      '[TODAY_RECOMMEND_QUALITY_SUMMARY] plans=$plans apiCalls=$apiCalls '
      'rawItems=$rawItems excludedManaged=$excludedManaged '
      'excludedNoImage=$excludedNoImage excludedNoPrice=$excludedNoPrice '
      'excludedNoName=$excludedNoName excludedNoUrl=$excludedNoUrl '
      'excludedSafety=$excludedSafety deduped=$deduped finalItems=$finalItems '
      'plannedFavoriteGenres=$plannedFavoriteGenres '
      'executedFavoriteGenrePlans=$executedFavoriteGenrePlans '
      'skippedFavoriteGenrePlans=$skippedFavoriteGenrePlans '
      'usedAssistPlan=$usedAssistPlan fallbackUsed=$fallbackUsed '
      'cooldownCanRegenerate=${cooldown.canRegenerate} '
      'cooldownRemainingSec=${cooldown.remainingSeconds}',
    );
  }

  bool _passesRecommendFinalDisplayGate(RakutenSearchItem item) {
    if (!SearchResultQualityFilter.passesDisplayQuality(
      item,
      checkSafety: true,
    )) {
      return false;
    }
    if (item.reviewCount <= 0 || item.reviewAverage <= 0) {
      return false;
    }
    return true;
  }

  void _todayRecommendCatalogSummaryLog({
    required bool enabled,
    required TodayRecommendCatalogCollectResult catalog,
    required bool apiSkippedByCatalog,
    required int apiCalls,
    required int finalItems,
  }) {
    if (!enabled) return;
    debugSummaryLog(
      '[TODAY_RECOMMEND_CATALOG_SUMMARY] enabled=true '
      'catalogCount=${catalog.catalogCount} '
      'catalogCandidates=${catalog.catalogCandidates} '
      'catalogAccepted=${catalog.catalogAccepted} '
      'catalogRejectedStale=${catalog.catalogRejectedStale} '
      'catalogRejectedQuality=${catalog.catalogRejectedQuality} '
      'catalogRejectedManaged=${catalog.catalogRejectedManaged} '
      'catalogRejectedGenre=${catalog.catalogRejectedGenre} '
      'catalogRejectedTrust=${catalog.catalogRejectedTrust} '
      'apiSkippedByCatalog=$apiSkippedByCatalog '
      'apiCalls=$apiCalls '
      'finalItems=$finalItems',
    );
    if (DebugLogFlags.kCatalogAuditLogsEnabled ||
        DebugLogFlags.kRecommendAuditLogsEnabled) {
      recommendAuditLog(
        '[TODAY_RECOMMEND_CATALOG_DETAIL] '
        'catalogRejectedDuplicate=${catalog.catalogRejectedDuplicate} '
        'sourceGenreIds=${catalog.sourceGenreIds.join(',')}',
      );
    }
  }

  void _scheduleRecommendCatalogUpsert(Iterable<RakutenSearchItem> items) {
    final repo = _productCatalogRepository;
    if (repo == null || !ProductCatalogConfig.kProductCatalogEnabled) return;
    final list = items.toList(growable: false);
    if (list.isEmpty) return;
    unawaited(() async {
      try {
        await upsertCatalogFromRecommendItems(repo, list);
      } catch (e) {
        importantDebugLog('[PRODUCT_CATALOG_RECOMMEND_UPSERT] failed: $e');
      }
    }());
  }

  void logTodayRecommendApiUsage({
    required int sessionId,
    required String phase,
    required int apiCalls,
    required int genreSearchCalls,
    required int shopSearchCalls,
    required int keywordSearchCalls,
    required int excludedBySafety,
    required int excludedByDuplicate,
    required int finalItems,
  }) {
    recommendAuditLog(
      '[TODAY_RECOMMEND_API_USAGE] sessionId=$sessionId phase=$phase '
      'apiCalls=$apiCalls genreSearchCalls=$genreSearchCalls '
      'shopSearchCalls=$shopSearchCalls keywordSearchCalls=$keywordSearchCalls '
      'excludedBySafety=$excludedBySafety excludedByDuplicate=$excludedByDuplicate '
      'finalItems=$finalItems',
    );
  }

  void _trigger({required String source}) {
    recommendAuditLog('$_logTagTrigger source=$source');
  }

  void _generateLog({
    required String stage,
    required int requestCount,
    required int planCount,
  }) {
    recommendAuditLog(
      '$_logTagGenerate $stage requestCount=$requestCount planCount=$planCount',
    );
  }

  void _summaryLog({
    required int totalApiRequests,
    required int totalPlans,
    required int selectedCount,
    required int excludedCount,
    required int durationMs,
  }) {
    recommendAuditLog(
      '$_logTagSummary totalApiRequests=$totalApiRequests totalPlans=$totalPlans '
      'selectedCount=$selectedCount excludedCount=$excludedCount durationMs=$durationMs',
    );
  }

  String _failureTypeFromError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('(429)') ||
        msg.contains('allowed requests has been exceeded')) {
      return 'rateLimit';
    }
    if (msg.contains('(400)') ||
        msg.contains('(401)') ||
        msg.contains('(403)') ||
        msg.contains('(500)') ||
        msg.contains('api')) {
      return 'apiError';
    }
    return 'exception';
  }

  List<String> _buildKeywords(
    UserProfile profile,
    List<RakutenManagedProduct> managedItems,
  ) {
    final out = <String>[];
    out.addAll(UserProfilePreferredGenreWords.fromProfile(profile));
    for (final p in managedItems.take(40)) {
      final n = p.itemName.trim();
      if (n.isEmpty) continue;
      final words = n.split(RegExp(r'[\s　]+'));
      for (final w in words) {
        final t = w.trim();
        if (t.length < 2) continue;
        if (RegExp(r'^[0-9]+$').hasMatch(t)) continue;
        out.add(t);
      }
      if (out.length >= 20) break;
    }
    final uniq = <String>{};
    final normalized = <String>[];
    for (final w in out) {
      final t = w.trim();
      if (t.isEmpty) continue;
      if (uniq.add(t)) normalized.add(t);
      if (normalized.length >= 8) break;
    }
    if (normalized.isEmpty) {
      return const ['人気', '売れ筋', 'ランキング'];
    }
    return normalized;
  }

  RakutenProductSearchCondition _conditionWithPostStyles({
    required String keyword,
    required Set<String> postStyles,
    String? genreId,
    String? shopCode,
    int relaxLevel = 0,
    String? sortOverride,
  }) {
    var rawMinPrice = postStyles.contains(UserProfile.postStyleAffordable)
        ? 500
        : (postStyles.contains(UserProfile.postStylePremium) ? 3000 : null);
    var rawMaxPrice = postStyles.contains(UserProfile.postStyleAffordable)
        ? 10000
        : (postStyles.contains(UserProfile.postStylePremium) ? 50000 : null);

    if (relaxLevel >= 3) {
      rawMinPrice = null;
      rawMaxPrice = null;
    } else if (relaxLevel >= 2 &&
        (postStyles.contains(UserProfile.postStyleAffordable) ||
            postStyles.contains(UserProfile.postStylePremium))) {
      rawMinPrice = null;
      rawMaxPrice = null;
    }

    final sanitizedPrice = _sanitizePriceRange(
      minPrice: rawMinPrice,
      maxPrice: rawMaxPrice,
    );
    final searchPreference = sortOverride ?? _sortForPostStyles(postStyles);

    var minReviewCount =
        postStyles.contains(UserProfile.postStyleHighlyRated) ||
            postStyles.contains(UserProfile.postStyleReviewRich)
        ? 20
        : 10;
    var minReviewAverage = postStyles.contains(UserProfile.postStyleHighlyRated)
        ? 4.2
        : 3.6;

    if (relaxLevel >= 3) {
      minReviewCount = 0;
      minReviewAverage = 0;
    } else if (relaxLevel == 2) {
      minReviewCount = (minReviewCount - 12).clamp(3, 1000);
      minReviewAverage = (minReviewAverage - 0.8).clamp(3.2, 5.0);
    } else if (relaxLevel == 1) {
      minReviewCount = (minReviewCount - 5).clamp(5, 1000);
      minReviewAverage = (minReviewAverage - 0.4).clamp(3.4, 5.0);
    }

    // API が 0 を不正とする場合に備え、緩和後はレビュー下限を送らない。
    final sendReviewCount = relaxLevel >= 3 || minReviewCount <= 0
        ? null
        : minReviewCount;
    final sendReviewAverage = relaxLevel >= 3 || minReviewAverage <= 0
        ? null
        : minReviewAverage;

    _logRecommendSearchParams(
      keyword: keyword,
      genreId: genreId,
      searchPreference: searchPreference,
      minPrice: rawMinPrice,
      maxPrice: rawMaxPrice,
      sanitizedMinPrice: sanitizedPrice.minPrice,
      sanitizedMaxPrice: sanitizedPrice.maxPrice,
    );
    return RakutenProductSearchCondition(
      keyword: keyword,
      genreId: genreId,
      shopCode: shopCode,
      minPrice: sanitizedPrice.minPrice,
      maxPrice: sanitizedPrice.maxPrice,
      minReviewCount: sendReviewCount,
      minReviewAverage: sendReviewAverage,
      sort: searchPreference,
    ).normalized();
  }

  ({int? minPrice, int? maxPrice}) _sanitizePriceRange({
    required int? minPrice,
    required int? maxPrice,
  }) {
    final normalizedMin = (minPrice != null && minPrice > 0) ? minPrice : null;
    final normalizedMax = (maxPrice != null && maxPrice > 0) ? maxPrice : null;
    if (normalizedMin == null || normalizedMax == null) {
      return (minPrice: null, maxPrice: null);
    }
    if (normalizedMin >= normalizedMax) {
      return (minPrice: null, maxPrice: null);
    }
    return (minPrice: normalizedMin, maxPrice: normalizedMax);
  }

  void _logRecommendSearchParams({
    required String keyword,
    required String? genreId,
    required String? searchPreference,
    required int? minPrice,
    required int? maxPrice,
    required int? sanitizedMinPrice,
    required int? sanitizedMaxPrice,
  }) {
    recommendAuditLog('[RECOMMEND] search keyword=$keyword');
    recommendAuditLog('[RECOMMEND] genreId=${genreId ?? ''}');
    recommendAuditLog('[RECOMMEND] searchPreference=${searchPreference ?? ''}');
    recommendAuditLog('[RECOMMEND] minPrice=${minPrice?.toString() ?? 'null'}');
    recommendAuditLog('[RECOMMEND] maxPrice=${maxPrice?.toString() ?? 'null'}');
    recommendAuditLog(
      '[RECOMMEND] sanitizedMinPrice=${sanitizedMinPrice?.toString() ?? 'null'}',
    );
    recommendAuditLog(
      '[RECOMMEND] sanitizedMaxPrice=${sanitizedMaxPrice?.toString() ?? 'null'}',
    );
  }

  String? _sortForPostStyles(Set<String> postStyles) {
    return TodayRecommendationPolicy.apiSortForPostStyles(postStyles);
  }

  _ScoredRecommendation? _scoreRecommendationForBucket(
    RakutenSearchItem item, {
    required _ItemPoolMeta meta,
    required Set<String> favoriteGenreIds,
    required Set<String> savedShopIds,
    required Set<String> preferredGenreWords,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required Set<String> postStyles,
    required List<RakutenManagedProduct> soldOutcomeItems,
    required List<RakutenManagedProduct> reactedOutcomeItems,
    required List<RakutenManagedProduct> likedOnlyOutcomeItems,
    required List<RakutenManagedProduct> recentCandidatesForBridge,
    required List<RakutenManagedProduct> staleCandidatesForBridge,
    required _ReactionProfile reactionProfile,
  }) {
    final reject = _recommendRejectReason(item, postStyles: postStyles);
    if (reject != null) {
      recommendAuditLog(
        '[RECOMMEND_EXCLUDE] itemCode=${item.productId} price=${item.itemPrice} reason=$reject',
      );
      return null;
    }

    var score = 0.0;
    final reasons = <String>[];
    final genreMatch = _genreMatchScore(
      item,
      favoriteGenreIds,
      preferredGenreWords,
    );
    final doneSimilarity = _historySimilarity(item, doneItems);
    final candidateSimilarity = _historySimilarity(item, candidateItems);
    final savedShopMatch =
        item.shopCode.trim().isNotEmpty &&
        savedShopIds.contains(item.shopCode.trim());

    final outcomeBoost = _outcomeInsightBoost(
      item,
      soldItems: soldOutcomeItems,
      reactedItems: reactedOutcomeItems,
      likedOnlyItems: likedOnlyOutcomeItems,
      recentBridgeCandidates: recentCandidatesForBridge,
      staleBridgeCandidates: staleCandidatesForBridge,
    );
    if (outcomeBoost >= 1.5) {
      score += 22;
      reasons.add('反応の良かった履歴に近い');
    } else if (outcomeBoost >= 0.75) {
      score += 12;
    }

    if (genreMatch >= 0.5) {
      score += 40;
      reasons.add('好きなジャンルに近い');
    }
    if (doneSimilarity >= 0.35) {
      score += 30;
      reasons.add('コレ済に近い');
    }
    if (candidateSimilarity >= 0.45) {
      score += 15;
      reasons.add('候補に近い');
    }
    if (savedShopMatch) {
      score += 25;
      reasons.add('保存ショップから');
    }

    final style = _resolvePrimaryStyle(postStyles);
    final styleScore = _styleMatchScore(item, style);
    if (styleScore > 0) {
      score += styleScore;
      reasons.add(_styleReasonLabel(style));
    }

    if (style == UserProfile.postStyleAffordable) {
      if (item.itemPrice >= 500 && item.itemPrice <= 10000) {
        score += 25;
      }
      if (item.reviewAverage >= 4.0) score += 15;
      if (item.reviewCount >= 3) score += 10;
      if (item.reviewCount >= 10) score += 5;
      if (item.imageUrl.trim().isNotEmpty) score += 10;
      if (item.reviewCount == 0) score -= 30;
    }

    if (style == UserProfile.postStylePremium) {
      if (item.itemPrice >= 3000 && item.itemPrice < 50000) {
        score += 25;
      }
      if (item.reviewCount >= 10) score += 15;
      if (item.reviewAverage >= 4.0) score += 10;
    }

    if (style == UserProfile.postStyleHighlyRated) {
      if (item.reviewAverage >= 4.2 && item.reviewCount >= 15) {
        score += 18;
        reasons.add('高評価');
      } else if (item.reviewAverage >= 4.5 && item.reviewCount < 8) {
        score -= 25;
      }
    } else {
      if (item.reviewAverage >= 4.0 && item.reviewCount >= 10) {
        score += 15;
        reasons.add('高評価');
      }
    }
    if (item.reviewCount >= 10) {
      score += 10;
      reasons.add('レビュー多め');
      if (style == UserProfile.postStyleReviewRich &&
          item.reviewAverage < 3.8) {
        score -= 18;
      }
    }
    if (item.imageUrl.trim().isNotEmpty) {
      score += 10;
    }
    if (_isPriceInPreferredRange(item.itemPrice, style)) {
      score += 10;
    }
    if (item.reviewCount == 0) {
      score -= 15;
    }
    if (item.itemPrice >= 100000) {
      score -= 30;
    }
    if (!savedShopMatch && genreMatch < 0.5 && doneSimilarity < 0.3) {
      score -= 20;
    }
    if (style == UserProfile.postStyleTrend &&
        genreMatch < 0.5 &&
        doneSimilarity < 0.35 &&
        candidateSimilarity < 0.35) {
      score -= 18;
    }
    if (style == UserProfile.postStylePractical &&
        !RegExp(
          r'日用品|生活雑貨|生活|キッチン|収納|ベビー|育児|家電小物|掃除|洗濯|食品|防災|家電',
        ).hasMatch('${item.itemName} ${item.genreName}')) {
      score -= 12;
    }

    final reaction = _reactionMatchScore(item, reactionProfile);
    final roomFit = _roomFitScore(item);
    final reviewEvidence = _reviewEvidenceScore(item);
    final postability = _postabilityScore(item);
    final weightedBoost =
        roomFit.score * 2.8 +
        reaction.score * 2.1 +
        reviewEvidence * 1.6 +
        postability.score * 0.8;
    score += weightedBoost;
    reasons.addAll(roomFit.reasons);
    reasons.addAll(reaction.reasons);
    reasons.addAll(postability.reasons);

    if (item.reviewCount < 3 && item.reviewAverage < 4.0) {
      score -= 45;
    }

    TodayRecommendationSection section;
    if (savedShopMatch && meta.fromShopPlan) {
      section = TodayRecommendationSection.sellable;
    } else if (meta.fromDiscoveryPhase &&
        genreMatch < 0.5 &&
        doneSimilarity < 0.35 &&
        !savedShopMatch) {
      section = TodayRecommendationSection.fresh;
    } else {
      section = TodayRecommendationSection.popular;
    }

    recommendAuditLog(
      '[RECOMMEND_SCORE] itemCode=${item.productId} '
      'title=${item.itemName.trim()} '
      'price=${item.itemPrice} '
      'reviewAverage=${item.reviewAverage.toStringAsFixed(2)} '
      'reviewCount=${item.reviewCount} roomFit=${roomFit.score.toStringAsFixed(1)} '
      'reaction=${reaction.score.toStringAsFixed(1)} '
      'reviewEvidence=${reviewEvidence.toStringAsFixed(1)} '
      'postability=${postability.score.toStringAsFixed(1)} '
      'score=${score.toStringAsFixed(1)} '
      'reasons=${reasons.join('|')}',
    );

    return _ScoredRecommendation(
      item: item,
      score: score,
      priceScore: _priceScore(item),
      reason: reasons.isEmpty ? '発掘・トレンド' : reasons.join('・'),
      section: section,
    );
  }

  double _priceScore(RakutenSearchItem item) {
    final price = item.itemPrice;
    if (price < 500) return -4;
    if (price < 1500) return 0.5;
    if (price < 3000) return 1.5;
    if (price < 10000) return 3;
    if (price < 20000) return 2;
    if (price < 30000) {
      if (item.reviewCount >= 80 && item.reviewAverage >= 4.2) return 1.2;
      return 0.2;
    }
    return -4;
  }

  String? _recommendRejectReason(
    RakutenSearchItem item, {
    required Set<String> postStyles,
  }) {
    if (item.productId.trim().isEmpty) return 'missingItemCode';
    if (item.reviewCount <= 0 || item.reviewAverage <= 0) {
      return 'zeroReview';
    }
    final quality = SearchResultQualityFilter.exclusionReason(
      item,
      checkSafety: true,
    );
    if (quality != null) {
      return switch (quality) {
        SearchQualityExcludeReason.noName => 'missingTitle',
        SearchQualityExcludeReason.noUrl => 'invalidUrl',
        SearchQualityExcludeReason.noImage => 'noImage',
        SearchQualityExcludeReason.noPrice => 'missingPrice',
        SearchQualityExcludeReason.safety => 'safetyBlocked',
        SearchQualityExcludeReason.reviewCount => null,
        SearchQualityExcludeReason.reviewAverage => null,
      };
    }
    final title = item.itemName.trim();
    // 今日のおすすめ限定: 価格帯の下限/上限を共通化。
    if (item.itemPrice < 500) {
      return 'tooCheap';
    }
    if (item.itemPrice >= 50000) return 'tooExpensive';
    final businessWord = RegExp(
      r'業務用|法人|産業|工業|周波数変換器|三相|50KVA|中古|未使用品|測定器|建設|部材|部品取り|訳あり高額|ジャンク|ライセンス|許諾',
      caseSensitive: false,
    );
    if (businessWord.hasMatch(title)) return 'businessItem';
    if (item.reviewCount == 0 && item.itemPrice >= 30000) {
      return 'highPriceNoReview';
    }
    return null;
  }

  String _resolvePrimaryStyle(Set<String> postStyles) {
    for (final k in UserProfile.postStyleKeys) {
      if (postStyles.contains(k)) return k;
    }
    return UserProfile.postStyleBalance;
  }

  double _styleMatchScore(RakutenSearchItem item, String style) {
    switch (style) {
      case UserProfile.postStyleAffordable:
        if (item.itemPrice >= 500 && item.itemPrice <= 10000) return 20;
        if (item.itemPrice > 0 && item.itemPrice <= 20000) return 10;
        return 0;
      case UserProfile.postStylePremium:
        if (item.itemPrice >= 3000 && item.itemPrice <= 50000) return 20;
        return 0;
      case UserProfile.postStyleHighlyRated:
        if (item.reviewAverage >= 4.0 && item.reviewCount >= 10) return 20;
        if (item.reviewAverage >= 4.0 && item.reviewCount >= 5) return 8;
        return 0;
      case UserProfile.postStyleSocial:
        return item.imageUrl.trim().isNotEmpty ? 20 : 0;
      case UserProfile.postStylePractical:
        return RegExp(
              r'日用品|生活雑貨|生活|キッチン|収納|ベビー|育児|家電小物|掃除|洗濯|食品|防災|家電',
            ).hasMatch('${item.itemName} ${item.genreName}')
            ? 20
            : 0;
      case UserProfile.postStyleReviewRich:
        return item.reviewCount >= 30 ? 20 : (item.reviewCount >= 10 ? 10 : 0);
      case UserProfile.postStyleTrend:
        return RegExp(r'新作|新着|季節|限定|トレンド').hasMatch(item.itemName) ? 20 : 2;
      case UserProfile.postStyleBalance:
      default:
        return 8;
    }
  }

  String _styleReasonLabel(String style) {
    switch (style) {
      case UserProfile.postStyleAffordable:
        return '買いやすい価格';
      case UserProfile.postStylePremium:
        return '高単価候補';
      case UserProfile.postStyleHighlyRated:
        return '高評価';
      case UserProfile.postStyleSocial:
        return '見た目で選ぶ';
      case UserProfile.postStylePractical:
        return '実用的';
      case UserProfile.postStyleReviewRich:
        return 'レビュー多め';
      case UserProfile.postStyleTrend:
        return '発掘・トレンド';
      case UserProfile.postStyleBalance:
      default:
        return 'バランス';
    }
  }

  bool _isPriceInPreferredRange(int price, String style) {
    switch (style) {
      case UserProfile.postStyleAffordable:
        return price >= 500 && price <= 10000;
      case UserProfile.postStylePremium:
        return price >= 3000 && price <= 50000;
      default:
        return price > 0 && price <= 100000;
    }
  }

  double _genreMatchScore(
    RakutenSearchItem item,
    Set<String> favoriteGenreIds,
    Set<String> preferredGenreWords,
  ) {
    final genreId = item.genreId.trim();
    if (genreId.isNotEmpty && favoriteGenreIds.contains(genreId)) return 1;
    final haystack = '${item.itemName} ${item.genreName}';
    for (final word in preferredGenreWords) {
      final normalized = word.trim();
      if (normalized.isNotEmpty && haystack.contains(normalized)) return 0.75;
    }
    return 0;
  }

  /// 分析で使う「反応が良かった商品」に寄せた加点（優先度はコメント順）。
  double _outcomeInsightBoost(
    RakutenSearchItem item, {
    required List<RakutenManagedProduct> soldItems,
    required List<RakutenManagedProduct> reactedItems,
    required List<RakutenManagedProduct> likedOnlyItems,
    required List<RakutenManagedProduct> recentBridgeCandidates,
    required List<RakutenManagedProduct> staleBridgeCandidates,
  }) {
    if (reactedItems.isEmpty) return 0;

    final gid = item.genreId.trim();
    var boost = 0.0;

    if (gid.isNotEmpty && soldItems.any((p) => p.genreId.trim() == gid)) {
      boost += 2.8;
    }

    final sc = item.shopCode.trim();
    if (sc.isNotEmpty && soldItems.any((p) => p.shopCode.trim() == sc)) {
      boost += 2.3;
    }

    final matchedSoldGenre =
        gid.isNotEmpty && soldItems.any((p) => p.genreId.trim() == gid);
    if (!matchedSoldGenre) {
      if (gid.isNotEmpty &&
          likedOnlyItems.any((p) => p.genreId.trim() == gid)) {
        boost += 1.9;
      } else {
        var simReacted = likedOnlyItems.isEmpty
            ? 0.0
            : _historySimilarity(item, likedOnlyItems);
        final simAllReacted = _historySimilarity(item, reactedItems);
        if (simAllReacted > simReacted) simReacted = simAllReacted;
        if (simReacted >= 0.34) {
          boost += 1.45;
        }
      }
    }

    var bridge = 0.0;
    for (final c in recentBridgeCandidates) {
      final sim = _managedProductTokenSimilarity(item, c);
      if (sim < 0.32) continue;
      final anchor = _historySimilarity(
        RakutenSearchItem(
          productId: c.productId,
          itemName: c.itemName,
          itemPrice: c.itemPrice,
          itemUrl: c.itemUrl,
          affiliateUrl: c.affiliateUrl ?? '',
          imageUrl: c.imageUrl,
          shopName: c.shopName,
          shopCode: c.shopCode,
          genreId: c.genreId,
          genreName: c.genreName,
          reviewCount: 0,
          reviewAverage: 0,
        ),
        reactedItems,
      );
      if (anchor >= 0.34) {
        final score = sim * 1.35;
        if (score > bridge) bridge = score;
      }
    }
    if (bridge >= 0.4) {
      boost += 1.15;
    } else if (bridge >= 0.32) {
      boost += 0.75;
    }

    var staleBridge = 0.0;
    for (final c in staleBridgeCandidates) {
      final sim = _managedProductTokenSimilarity(item, c);
      if (sim < 0.3) continue;
      final anchor = _historySimilarity(
        RakutenSearchItem(
          productId: c.productId,
          itemName: c.itemName,
          itemPrice: c.itemPrice,
          itemUrl: c.itemUrl,
          affiliateUrl: c.affiliateUrl ?? '',
          imageUrl: c.imageUrl,
          shopName: c.shopName,
          shopCode: c.shopCode,
          genreId: c.genreId,
          genreName: c.genreName,
          reviewCount: 0,
          reviewAverage: 0,
        ),
        reactedItems,
      );
      if (anchor >= 0.32) {
        if (sim > staleBridge) staleBridge = sim;
      }
    }
    if (staleBridge >= 0.36) {
      boost += 0.85;
    } else if (staleBridge >= 0.28) {
      boost += 0.45;
    }

    return boost.clamp(0.0, 12.0);
  }

  double _managedProductTokenSimilarity(
    RakutenSearchItem item,
    RakutenManagedProduct p,
  ) {
    final itemTokens = _nameTokens(item.itemName);
    final historyTokens = _nameTokens(p.itemName);
    if (itemTokens.isEmpty || historyTokens.isEmpty) return 0;
    final overlap = itemTokens.intersection(historyTokens).length;
    final denom = itemTokens.length < historyTokens.length
        ? itemTokens.length
        : historyTokens.length;
    return (overlap / denom).clamp(0.0, 1.0);
  }

  double _historySimilarity(
    RakutenSearchItem item,
    List<RakutenManagedProduct> history,
  ) {
    if (history.isEmpty) return 0;
    var best = 0.0;
    final itemGenre = item.genreId.trim();
    final itemTokens = _nameTokens(item.itemName);
    for (final h in history.take(80)) {
      var score = 0.0;
      if (itemGenre.isNotEmpty && itemGenre == h.genreId.trim()) {
        score += 0.55;
      }
      final historyTokens = _nameTokens(h.itemName);
      if (itemTokens.isNotEmpty && historyTokens.isNotEmpty) {
        final overlap = itemTokens.intersection(historyTokens).length;
        final denom = itemTokens.length < historyTokens.length
            ? itemTokens.length
            : historyTokens.length;
        score += (overlap / denom).clamp(0.0, 1.0) * 0.45;
      }
      if (score > best) best = score;
      if (best >= 1) return 1;
    }
    return best.clamp(0.0, 1.0);
  }

  Set<String> _nameTokens(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[【】\[\]（）()「」,，、。/／\\|+＋・:：;；!！?？]'), ' ')
        .toLowerCase();
    final out = <String>{};
    for (final token in cleaned.split(RegExp(r'[\s　]+'))) {
      final t = token.trim();
      if (t.length < 2) continue;
      if (RegExp(r'^[0-9]+$').hasMatch(t)) continue;
      out.add(t);
      if (out.length >= 12) break;
    }
    return out;
  }

  _ReactionProfile _buildReactionProfile({
    required List<RakutenManagedProduct> managedItems,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
  }) {
    final commentGenres = <String>{};
    final likeGenres = <String>{};
    final commentShops = <String>{};
    final likeShops = <String>{};
    final priceBands = <String>{};
    final keywordTokens = <String>{};

    for (final p in managedItems) {
      final comments = p.roomCommentCount ?? 0;
      final likes = p.roomLikeCount ?? 0;
      final gid = p.genreId.trim();
      final shop = p.shopCode.trim();
      final hasCommentSignal = comments >= 1 || p.feedbackSoldAt != null;
      final hasLikeSignal = likes >= 5 || p.feedbackLikedAt != null;
      if (hasCommentSignal) {
        if (gid.isNotEmpty) commentGenres.add(gid);
        if (shop.isNotEmpty) commentShops.add(shop);
      }
      if (hasLikeSignal) {
        if (gid.isNotEmpty) likeGenres.add(gid);
        if (shop.isNotEmpty) likeShops.add(shop);
      }
      if (hasCommentSignal || hasLikeSignal) {
        if (p.itemPrice > 0) priceBands.add(_priceBand(p.itemPrice));
        keywordTokens.addAll(_nameTokens(p.itemName).take(4));
      }
    }
    // 反応が少ない場合は最低限、履歴を弱いシグナルとして取り込む。
    if (commentGenres.isEmpty && likeGenres.isEmpty) {
      for (final p in [...doneItems, ...candidateItems].take(30)) {
        final gid = p.genreId.trim();
        final shop = p.shopCode.trim();
        if (gid.isNotEmpty) likeGenres.add(gid);
        if (shop.isNotEmpty) likeShops.add(shop);
        if (p.itemPrice > 0) priceBands.add(_priceBand(p.itemPrice));
        keywordTokens.addAll(_nameTokens(p.itemName).take(2));
      }
    }
    recommendAuditLog(
      '[RECOMMEND_REACTION] commentGenres=${commentGenres.length} '
      'likeGenres=${likeGenres.length} commentShops=${commentShops.length} '
      'likeShops=${likeShops.length} priceBands=${priceBands.join(",")}',
    );
    return _ReactionProfile(
      commentGenres: commentGenres,
      likeGenres: likeGenres,
      commentShops: commentShops,
      likeShops: likeShops,
      priceBands: priceBands,
      keywordTokens: keywordTokens,
    );
  }

  ({double score, List<String> reasons}) _reactionMatchScore(
    RakutenSearchItem item,
    _ReactionProfile profile,
  ) {
    var score = 0.0;
    final reasons = <String>[];
    final gid = item.genreId.trim();
    final shop = item.shopCode.trim();
    final band = _priceBand(item.itemPrice);
    final itemTokens = _nameTokens(item.itemName);

    if (gid.isNotEmpty && profile.commentGenres.contains(gid)) {
      score += 30;
      reasons.add('コメント反応あり');
    }
    if (shop.isNotEmpty && profile.commentShops.contains(shop)) {
      score += 25;
      reasons.add('コメント反応あり');
    }
    if (gid.isNotEmpty && profile.likeGenres.contains(gid)) {
      score += 20;
      reasons.add('♡されやすい');
    }
    if (shop.isNotEmpty && profile.likeShops.contains(shop)) {
      score += 15;
      reasons.add('♡されやすい');
    }
    if (profile.priceBands.contains(band)) {
      score += 15;
    }
    if (itemTokens.any(profile.keywordTokens.contains)) {
      score += 15;
    }
    if (score > 0) {
      recommendAuditLog(
        '[RECOMMEND_REACTION_SCORE] itemCode=${item.productId} '
        'score=${score.toStringAsFixed(1)} reasons=${reasons.join("|")}',
      );
    }
    return (score: score, reasons: reasons);
  }

  ({double score, List<String> reasons}) _postabilityScore(
    RakutenSearchItem item,
  ) {
    var score = 0.0;
    final reasons = <String>[];
    final title = item.itemName.trim();
    final practicalWord = RegExp(r'育児|日用品|キッチン|収納|食品|生活雑貨|ベビー|掃除|洗濯|防災');
    final giftWord = RegExp(r'ギフト|贈り物|プレゼント|母の日|父の日|お祝い');

    if (item.imageUrl.trim().isNotEmpty) {
      score += 15;
      reasons.add('投稿しやすい');
    }
    if (title.length >= 6 &&
        title.length <= 42 &&
        !_looksLikeModelOnly(title)) {
      score += 10;
    }
    if (practicalWord.hasMatch('$title ${item.genreName}')) {
      score += 15;
      reasons.add('投稿しやすい');
    }
    if (giftWord.hasMatch(title)) score += 10;
    if (item.reviewAverage >= 4.0) score += 10;
    if (item.reviewCount >= 10) score += 10;
    if (item.itemPrice >= 500 && item.itemPrice <= 10000) score += 10;
    if (_looksLikeModelOnly(title)) score -= 20;
    if (title.length >= 70) score -= 10;

    recommendAuditLog(
      '[RECOMMEND_POSTABILITY] itemCode=${item.productId} '
      'score=${score.toStringAsFixed(1)} reasons=${reasons.join("|")}',
    );
    return (score: score, reasons: reasons);
  }

  ({double score, List<String> reasons}) _roomFitScore(RakutenSearchItem item) {
    var score = 0.0;
    final reasons = <String>[];
    final text = '${item.itemName} ${item.genreName}'.toLowerCase();
    final fitWords = <String>[
      '育児',
      '時短',
      '日用品',
      'キッチン',
      '収納',
      '美容',
      'おしゃれ',
      'sns映え',
      'ギフト',
      '可愛い',
      '便利',
    ];
    for (final w in fitWords) {
      if (text.contains(w)) score += 8;
    }
    if (fitWords.any(text.contains)) reasons.add('ROOM向き');

    final unfitWords = <String>[
      '宿泊券',
      '旅行券',
      '香典返し',
      '法人',
      '工具',
      '工事',
      'ライセンス',
      'co2',
      'セキュリティ',
      '業務用',
      '保守',
      'ソフトウェアライセンス',
    ];
    var unfitHit = false;
    for (final w in unfitWords) {
      if (text.contains(w.toLowerCase())) {
        score -= 26;
        unfitHit = true;
      }
    }
    if (unfitHit) {
      recommendAuditLog(
        '[RECOMMEND_ROOM_UNFIT] itemCode=${item.productId} title=${item.itemName}',
      );
    }
    recommendAuditLog(
      '[RECOMMEND_ROOM_FIT] itemCode=${item.productId} score=${score.toStringAsFixed(1)} reasons=${reasons.join("|")}',
    );
    return (score: score, reasons: reasons);
  }

  double _reviewEvidenceScore(RakutenSearchItem item) {
    var score = 0.0;
    if (item.reviewAverage >= 4.0) score += 12;
    if (item.reviewCount >= 3) score += 10;
    if (item.reviewCount >= 10) score += 12;
    if (item.reviewCount >= 30) score += 10;
    if (item.reviewCount < 3 && item.reviewAverage < 4.0) score -= 30;
    if (item.reviewCount == 0) score -= 25;
    return score;
  }

  String _priceBand(int price) {
    if (price < 2000) return '500-1999';
    if (price < 5000) return '2000-4999';
    if (price < 10000) return '5000-9999';
    if (price < 20000) return '10000-19999';
    return '20000-49999';
  }

  String _titleCoreToken(String title) {
    final tokens = _nameTokens(title).toList(growable: false);
    if (tokens.isEmpty) return '';
    return tokens.first;
  }

  String _mainTopicKey(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('カタログギフト')) return 'カタログギフト';
    if (normalized.contains('ふるさと納税')) return 'ふるさと納税';
    if (normalized.contains('宿泊券')) return '宿泊券';
    if (normalized.contains('旅行券')) return '旅行券';
    return '';
  }

  bool _looksLikeModelOnly(String title) {
    final t = title.replaceAll(' ', '');
    return RegExp(r'^[a-zA-Z0-9\-_/]{6,}$').hasMatch(t);
  }

  String _localDateKey(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  }
}

class _ScoredRecommendation {
  const _ScoredRecommendation({
    required this.item,
    required this.score,
    required this.priceScore,
    required this.reason,
    required this.section,
  });

  final RakutenSearchItem item;
  final double score;
  final double priceScore;
  final String reason;
  final TodayRecommendationSection section;
}

class _ItemPoolMeta {
  bool fromShopPlan = false;
  bool fromDiscoveryPhase = false;
  bool fromRelaxedPhase = false;
  bool fromPersonalPhase = false;
  String sourceGenreId = '';
}

class _ReactionProfile {
  const _ReactionProfile({
    required this.commentGenres,
    required this.likeGenres,
    required this.commentShops,
    required this.likeShops,
    required this.priceBands,
    required this.keywordTokens,
  });

  final Set<String> commentGenres;
  final Set<String> likeGenres;
  final Set<String> commentShops;
  final Set<String> likeShops;
  final Set<String> priceBands;
  final Set<String> keywordTokens;
}

class _RecommendSearchPlan {
  const _RecommendSearchPlan({
    required this.phase,
    required this.relaxLevel,
    required this.source,
    required this.keyword,
    required this.genreId,
    required this.shopCode,
    this.sortOverride,
  });

  factory _RecommendSearchPlan.fromSpec(RecommendSearchPlanSpec spec) {
    return _RecommendSearchPlan(
      phase: spec.phase,
      relaxLevel: spec.relaxLevel,
      source: spec.source,
      keyword: spec.keyword,
      genreId: spec.genreId,
      shopCode: spec.shopCode,
      sortOverride: spec.sort,
    );
  }

  final String phase;
  final int relaxLevel;
  final String source;
  final String keyword;
  final String? genreId;
  final String? shopCode;
  final String? sortOverride;
}
