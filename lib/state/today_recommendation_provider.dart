import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/today_recommendation.dart';
import '../models/user_profile.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/today_recommendation_repository.dart';
import '../utils/user_profile_preferred_genre_words.dart';
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
  }) : _repository = repository,
       _searchRepository = searchRepository {
    _bundle = _repository.load();
  }

  final TodayRecommendationRepository _repository;
  final RakutenSearchRepository _searchRepository;

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
  static const Duration _recentEnsureWindow = Duration(seconds: 3);
  static const Duration _manualRegenerateCooldown = Duration(minutes: 5);
  static const Duration _recentGenerateCooldown = Duration(minutes: 15);
  static const Duration _rateLimitCooldown = Duration(minutes: 12);
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
    await regenerateToday(
      profile: profile,
      managedItems: managedItems,
      savedShops: savedShops,
      trigger: trigger,
    );
  }

  Future<void> regenerateToday({
    required UserProfile profile,
    required List<RakutenManagedProduct> managedItems,
    required List<SavedShop> savedShops,
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
    _lastRegenerateAt = now;
    _isLoading = true;
    _errorMessage = null;
    _generationStatus = TodayRecommendationGenerationStatus.loading;
    notifyListeners();
    try {
      final generated = await _generate(
        profile: profile,
        managedItems: managedItems,
        savedShops: savedShops,
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
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TodayRecommendation] regenerateToday failed: $e');
        debugPrint('$st');
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
      notifyListeners();
    }
  }

  Future<void> markSkipped(String productId) async {
    final b = _bundle;
    if (b == null) return;
    final nextEntries = b.entries
        .map((e) {
          if (e.item.productId != productId) return e;
          if (e.decision != TodayRecommendationDecision.pending) return e;
          return e.copyWith(decision: TodayRecommendationDecision.skipped);
        })
        .toList(growable: false);
    _bundle = b.copyWith(entries: nextEntries);
    await _repository.save(_bundle!);
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
    final savedShopIds = savedShops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final favoriteGenreIds = profile.favoriteGenreIdList
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final selectedStyle = profile.selectedSearchStyle;
    final postStyles = <String>{selectedStyle};
    if (kDebugMode) {
      debugPrint('[RECOMMEND_STYLE] selected=$selectedStyle');
      debugPrint('[SEARCH_STYLE_TRACE] selectedStyle=$selectedStyle');
    }
    _trace('favoriteGenreIds=${favoriteGenreIds.join(',')}');
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
      debugPrint(
        '[RECOMMEND_START] genreCount=${favoriteGenreIds.length} '
        'savedShopCount=${savedShops.length} doneCount=${doneItems.length} '
        'candidateCount=${candidateItems.length} selectedStyle=$selectedStyle',
      );
    }

    final plans = _buildPhasedSearchPlans(
      favoriteGenreIds: favoriteGenreIds,
      savedShops: savedShops,
      doneItems: doneItems,
      candidateItems: candidateItems,
      keywords: keywords,
      postStyles: postStyles,
    );
    _planLogCount(plans.length);
    _generateLog(
      stage: 'start',
      requestCount: 0,
      planCount: plans.length,
    );

    final pool = <String, RakutenSearchItem>{};
    final metaById = <String, _ItemPoolMeta>{};
    var apiCalls = 0;
    var excludedCount = 0;
    var allPlansNoItems = true;
    var rateLimited = false;
    const maxApiHard = 10;

    bool canCallMoreApi(int entryCount) {
      if (entryCount >= 10) return false;
      if (apiCalls >= maxApiHard) return false;
      return true;
    }

    final genreWords = UserProfilePreferredGenreWords.fromProfile(profile);
    final reactionProfile = _buildReactionProfile(
      managedItems: managedItems,
      doneItems: doneItems,
      candidateItems: candidateItems,
    );
    final guardedPlanCount = plans.length > 1 ? plans.length - 1 : plans.length;
    var i = 0;
    for (; i < guardedPlanCount; i++) {
      final preview = _finalizeFromPool(
        pool: pool,
        metaById: metaById,
        favoriteGenreIds: favoriteGenreIds,
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
      );
      if (!canCallMoreApi(preview.entries.length)) break;

      final p = plans[i];
      _phaseLog(p.phase);
      final condition = _conditionWithPostStyles(
        keyword: p.keyword,
        postStyles: postStyles,
        genreId: p.genreId,
        shopCode: p.shopCode,
        relaxLevel: p.relaxLevel,
        sortOverride: p.sortOverride,
      );
      _planLogDetailed(
        index: i + 1,
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
        planIndex: i + 1,
        keyword: p.keyword,
        genreId: p.genreId,
        shopCode: p.shopCode,
        page: 1,
      );

      List<RakutenSearchItem> list;
      try {
        list = await _runSearchPlan(
          phase: p.phase,
          source: p.source,
          planIndex: i + 1,
          condition: condition,
          excludeIds: excludeIds,
        );
      } catch (e) {
        if (_isRateLimitError(e)) {
          rateLimited = true;
          break;
        }
        rethrow;
      }
      apiCalls += 1;
      if (list.isNotEmpty) allPlansNoItems = false;
      for (final item in list) {
        _trace('raw item itemCode=${item.productId} title=${item.itemName}');
        final exclusion = _excludeReason(
          item: item,
          excludeIds: excludeIds,
          doneItems: doneItems,
          candidateItems: candidateItems,
          dedup: pool,
        );
        if (exclusion != null) {
          excludedCount += 1;
          _trace('exclude reason=$exclusion');
          continue;
        }
        _trace('accepted itemCode=${item.productId} title=${item.itemName}');
        final id = item.productId.trim();
        pool[id] = item;
        final m = metaById.putIfAbsent(id, () => _ItemPoolMeta());
        if (p.phase == 'personal' || p.phase == 'fallback') {
          m.fromPersonalPhase = true;
        }
        if (p.phase == 'relaxed') m.fromRelaxedPhase = true;
        if (p.phase == 'discovery') m.fromDiscoveryPhase = true;
        if (p.source == 'shop') m.fromShopPlan = true;
      }

      if (pool.length > 45) break;
    }

    var finalized = _finalizeFromPool(
      pool: pool,
      metaById: metaById,
      favoriteGenreIds: favoriteGenreIds,
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
    );
    if (!rateLimited && finalized.entries.length < 10) {
      final hasExtraPlan = i < plans.length;
      if (kDebugMode) {
        debugPrint('[RECOMMEND_API_GUARD] extraSearchAllowed=$hasExtraPlan');
      }
      if (hasExtraPlan) {
        final p = plans[i];
        _apiLogDetailed(
          planIndex: i + 1,
          keyword: p.keyword,
          genreId: p.genreId,
          shopCode: p.shopCode,
          page: 1,
        );
        final condition = _conditionWithPostStyles(
          keyword: p.keyword,
          postStyles: postStyles,
          genreId: p.genreId,
          shopCode: p.shopCode,
          relaxLevel: p.relaxLevel,
          sortOverride: p.sortOverride,
        );
        try {
          final list = await _runSearchPlan(
            phase: p.phase,
            source: p.source,
            planIndex: i + 1,
            condition: condition,
            excludeIds: excludeIds,
          );
          apiCalls += 1;
          if (list.isNotEmpty) allPlansNoItems = false;
          for (final item in list) {
            final exclusion = _excludeReason(
              item: item,
              excludeIds: excludeIds,
              doneItems: doneItems,
              candidateItems: candidateItems,
              dedup: pool,
            );
            if (exclusion != null) {
              excludedCount += 1;
              continue;
            }
            final id = item.productId.trim();
            pool[id] = item;
            final m = metaById.putIfAbsent(id, () => _ItemPoolMeta());
            if (p.phase == 'personal' || p.phase == 'fallback') {
              m.fromPersonalPhase = true;
            }
            if (p.phase == 'relaxed') m.fromRelaxedPhase = true;
            if (p.phase == 'discovery') m.fromDiscoveryPhase = true;
            if (p.source == 'shop') m.fromShopPlan = true;
          }
          finalized = _finalizeFromPool(
            pool: pool,
            metaById: metaById,
            favoriteGenreIds: favoriteGenreIds,
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
          );
        } catch (e) {
          if (_isRateLimitError(e)) {
            rateLimited = true;
          } else {
            rethrow;
          }
        }
      }
    } else if (kDebugMode) {
      debugPrint('[RECOMMEND_API_GUARD] skipExtraSearch reason=poolHasEnoughBackfill');
      debugPrint('[RECOMMEND_API_GUARD] extraSearchAllowed=false');
    }

    if (pool.isEmpty && allPlansNoItems) {
      _resultLog(status: 'failed', reason: 'allPlansNoItems', count: 0);
    }

    final entries = finalized.entries;

    if (kDebugMode) {
      debugPrint('[RECOMMEND] apiCalls=$apiCalls poolSize=${pool.length}');
      debugPrint('[RECOMMEND] final count: ${entries.length}');
      debugPrint(
        '[RECOMMEND_BUCKET] personal=${finalized.personalCount} '
        'relaxed=${finalized.relaxedCount} discovery=${finalized.discoveryCount} '
        'total=${entries.length}',
      );
      if (entries.isEmpty) {
        debugPrint('[RECOMMEND_RESULT] status=failed count=0');
      }
      debugPrint(
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
    return TodayRecommendationBundle(
      localDateKey: _localDateKey(DateTime.now()),
      generatedAt: DateTime.now(),
      entries: entries,
    );
  }

  /// フェーズ順に並べた検索プラン（API は上位から試し、10件または上限まで）。
  List<_RecommendSearchPlan> _buildPhasedSearchPlans({
    required Set<String> favoriteGenreIds,
    required List<SavedShop> savedShops,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required List<String> keywords,
    required Set<String> postStyles,
  }) {
    final favList = favoriteGenreIds.toList(growable: false);
    final keywordPrimary = keywords.isEmpty ? '人気' : keywords.first;
    final keywordAlt = keywords.length >= 2
        ? keywords[1]
        : (keywords.isEmpty ? 'ランキング' : '売れ筋');
    final historyGenres = _topGenresFromHistory(
      doneItems,
      candidateItems,
      limit: 4,
    );
    final plans = <_RecommendSearchPlan>[];

    void addPlan(_RecommendSearchPlan plan) => plans.add(plan);

    // Phase 1 personal（最大4）：ジャンル×探し方 × 保存ショップ × 履歴ジャンル
    for (final gid in favList.take(2)) {
      addPlan(
        _RecommendSearchPlan(
          phase: 'personal',
          relaxLevel: 0,
          source: 'genre',
          keyword: keywordPrimary,
          genreId: gid,
          shopCode: null,
        ),
      );
    }
    for (final shop in savedShops.take(1)) {
      final sid = shop.shopId.trim();
      if (sid.isEmpty) continue;
      addPlan(
        _RecommendSearchPlan(
          phase: 'personal',
          relaxLevel: 0,
          source: 'shop',
          keyword: keywordPrimary,
          genreId: null,
          shopCode: sid,
        ),
      );
    }
    for (final gid in historyGenres) {
      if (favList.take(2).contains(gid)) continue;
      addPlan(
        _RecommendSearchPlan(
          phase: 'personal',
          relaxLevel: 0,
          source: 'style',
          keyword: keywordPrimary,
          genreId: gid,
          shopCode: null,
        ),
      );
      break;
    }

    // Phase 2 relaxed（最大3）：レビュー・価格を緩めつつジャンル軸は維持
    for (final gid in favList.take(2)) {
      addPlan(
        _RecommendSearchPlan(
          phase: 'relaxed',
          relaxLevel: 1,
          source: 'genre',
          keyword: keywordAlt,
          genreId: gid,
          shopCode: null,
        ),
      );
    }
    if (savedShops.length >= 2) {
      final sid = savedShops[1].shopId.trim();
      if (sid.isNotEmpty) {
        addPlan(
          _RecommendSearchPlan(
            phase: 'relaxed',
            relaxLevel: 1,
            source: 'shop',
            keyword: keywordAlt,
            genreId: null,
            shopCode: sid,
          ),
        );
      }
    } else if (favList.length > 2) {
      addPlan(
        _RecommendSearchPlan(
          phase: 'relaxed',
          relaxLevel: 2,
          source: 'genre',
          keyword: keywordAlt,
          genreId: favList[2],
          shopCode: null,
        ),
      );
    }

    // Phase 3 discovery（最大2）：広め・トレンド寄り（枠は後段ピックで最大3）
    addPlan(
      _RecommendSearchPlan(
        phase: 'discovery',
        relaxLevel: 2,
        source: 'style',
        keyword: keywordPrimary,
        genreId: historyGenres.length >= 2 ? historyGenres[1] : null,
        shopCode: null,
        sortOverride: postStyles.contains(UserProfile.postStyleTrend)
            ? '-updateTimestamp'
            : '-reviewCount',
      ),
    );
    addPlan(
      const _RecommendSearchPlan(
        phase: 'discovery',
        relaxLevel: 3,
        source: 'style',
        keyword: '人気',
        genreId: null,
        shopCode: null,
        sortOverride: '-reviewCount',
      ),
    );

    // fallback（1）：フィルタをほぼ外した広い検索
    addPlan(
      _RecommendSearchPlan(
        phase: 'fallback',
        relaxLevel: 3,
        source: 'style',
        keyword: '売れ筋',
        genreId: null,
        shopCode: null,
        sortOverride: null,
      ),
    );

    return plans;
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
    if (_recommendRejectReason(item, postStyles: postStyles) != null) {
      return false;
    }
    if (item.itemPrice < 500 || item.itemPrice >= 50000) return false;
    if (!(item.reviewCount >= 3 || item.reviewAverage >= 4.0)) return false;
    if (item.imageUrl.trim().isEmpty) return false;
    return item.itemUrl.trim().isNotEmpty || item.affiliateUrl.trim().isNotEmpty;
  }

  ({
    List<TodayRecommendationEntry> entries,
    int personalCount,
    int relaxedCount,
    int discoveryCount,
  })
  _finalizeFromPool({
    required Map<String, RakutenSearchItem> pool,
    required Map<String, _ItemPoolMeta> metaById,
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
    final scored = <_ScoredRecommendation>[];
    for (final item in pool.values) {
      final scoredItem = _scoreRecommendationForBucket(
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
      if (scoredItem != null) scored.add(scoredItem);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (kDebugMode) {
      debugPrint(
        '[RECOMMEND_POOL] raw=${pool.length} valid=${scored.length} scored=${scored.length}',
      );
    }

    final picked = _pickBalancedBySection(scored);
    if (kDebugMode) {
      debugPrint('[RECOMMEND_SELECT] strictSelected=${picked.length}');
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
        debugPrint('[RECOMMEND_BACKFILL] fromExistingPool=true added=$added');
        debugPrint('[RECOMMEND_BACKFILL] reason=diversityRelaxed');
        debugPrint('[RECOMMEND_BACKFILL] added=$added total=${entryList.length}');
      }
    }
    final entries = entryList.toList(growable: false);

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
    );
  }

  /// あなた向け〜7、保存ショップ枠〜3、発掘〜3 を優先しつつ最大10件。
  List<_ScoredRecommendation> _pickBalancedBySection(
    List<_ScoredRecommendation> scored,
  ) {
    final popular = scored
        .where((e) => e.section == TodayRecommendationSection.popular)
        .toList(growable: false);
    final sellable = scored
        .where((e) => e.section == TodayRecommendationSection.sellable)
        .toList(growable: false);
    final fresh = scored
        .where((e) => e.section == TodayRecommendationSection.fresh)
        .toList(growable: false);

    final selected = <_ScoredRecommendation>[];
    final selectedIds = <String>{};
    final shopCounts = <String, int>{};
    final genreCounts = <String, int>{};
    final priceBandCounts = <String, int>{};
    final tokenCounts = <String, int>{};
    final mainTopicCounts = <String, int>{};

    double adjustedScore(_ScoredRecommendation e) {
      var score = e.score;
      final shop = e.item.shopCode.trim();
      final genre = e.item.genreId.trim();
      final band = _priceBand(e.item.itemPrice);
      final token = _titleCoreToken(e.item.itemName);
      final mainTopic = _mainTopicKey(e.item.itemName);
      if (mainTopic.isNotEmpty && (mainTopicCounts[mainTopic] ?? 0) >= 2) {
        score -= 40;
      }
      if (token.isNotEmpty && (tokenCounts[token] ?? 0) >= 2) {
        score -= 35;
      }
      if (genre.isNotEmpty && (genreCounts[genre] ?? 0) >= 3) {
        score -= 25;
      }
      if (shop.isNotEmpty && (shopCounts[shop] ?? 0) >= 2) {
        score -= 30;
      }
      if ((priceBandCounts[band] ?? 0) >= 4) {
        score -= 18;
      }
      return score;
    }

    void markDiversity(_ScoredRecommendation e) {
      final shop = e.item.shopCode.trim();
      final genre = e.item.genreId.trim();
      final band = _priceBand(e.item.itemPrice);
      final token = _titleCoreToken(e.item.itemName);
      if (shop.isNotEmpty) shopCounts[shop] = (shopCounts[shop] ?? 0) + 1;
      if (genre.isNotEmpty) genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      priceBandCounts[band] = (priceBandCounts[band] ?? 0) + 1;
      if (token.isNotEmpty) tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      final mainTopic = _mainTopicKey(e.item.itemName);
      if (mainTopic.isNotEmpty) {
        mainTopicCounts[mainTopic] = (mainTopicCounts[mainTopic] ?? 0) + 1;
      }
    }

    void takeFrom(List<_ScoredRecommendation> list, int max) {
      for (var n = 0; n < max && selected.length < 10; n++) {
        _ScoredRecommendation? best;
        var bestScore = double.negativeInfinity;
        for (final e in list) {
          final id = e.item.productId.trim();
          if (id.isEmpty || selectedIds.contains(id)) continue;
          final s = adjustedScore(e);
          if (s > bestScore) {
            bestScore = s;
            best = e;
          }
        }
        if (best == null) return;
        if (kDebugMode) {
          final mainTopic = _mainTopicKey(best.item.itemName);
          final genre = best.item.genreId.trim();
          final token = _titleCoreToken(best.item.itemName);
          final shop = best.item.shopCode.trim();
          if (mainTopic.isNotEmpty && (mainTopicCounts[mainTopic] ?? 0) >= 2) {
            debugPrint('[RECOMMEND_DIVERSITY] demotedBecause=sameMainTopic penalty=-40');
          }
          if (genre.isNotEmpty && (genreCounts[genre] ?? 0) >= 3) {
            debugPrint('[RECOMMEND_DIVERSITY] demotedBecause=sameGenre penalty=-25');
          }
          if (token.isNotEmpty && (tokenCounts[token] ?? 0) >= 2) {
            debugPrint('[RECOMMEND_DIVERSITY] demotedBecause=sameTitleToken penalty=-35');
          }
          if (shop.isNotEmpty && (shopCounts[shop] ?? 0) >= 2) {
            debugPrint('[RECOMMEND_DIVERSITY] demotedBecause=sameShop penalty=-30');
          }
        }
        selected.add(best);
        selectedIds.add(best.item.productId.trim());
        markDiversity(best);
      }
    }

    takeFrom(popular, 6);
    takeFrom(sellable, 3);
    // 発掘枠は補完目的。初回は2件まで。
    takeFrom(fresh, 2);

    if (selected.length < 10) {
      for (final e in scored) {
        if (selected.length >= 10) break;
        final id = e.item.productId.trim();
        if (id.isEmpty || selectedIds.contains(id)) continue;
        final freshCount = selected
            .where((x) => x.section == TodayRecommendationSection.fresh)
            .length;
        if (e.section == TodayRecommendationSection.fresh && freshCount >= 3) {
          continue;
        }
        selected.add(e);
        selectedIds.add(id);
        markDiversity(e);
      }
    }
    return selected;
  }

  Future<List<RakutenSearchItem>> _runSearchPlan({
    required String phase,
    required String source,
    required int planIndex,
    required RakutenProductSearchCondition condition,
    required Set<String> excludeIds,
  }) async {
    _apiLogStart(index: planIndex, page: 1, phase: phase);
    try {
      final list = await _searchRepository.search(
        condition: condition,
        maxPages: 1,
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
        );
        if (reason == null) return true;
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
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
    if (!kDebugMode) return;
    debugPrint('[RECOMMEND_TRACE] $message');
  }

  String? _excludeReason({
    required RakutenSearchItem item,
    required Set<String> excludeIds,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required Map<String, RakutenSearchItem> dedup,
    bool checkDedup = true,
  }) {
    final id = item.productId.trim();
    if (id.isEmpty) return 'missingItemCode';
    if (item.itemName.trim().isEmpty) return 'missingTitle';
    final hasAnyUrl =
        item.itemUrl.trim().isNotEmpty || item.affiliateUrl.trim().isNotEmpty;
    if (!hasAnyUrl) return 'invalidUrl';
    if (excludeIds.contains(id)) {
      if (doneItems.any((e) => e.productId.trim() == id)) return 'alreadyDone';
      if (candidateItems.any((e) => e.productId.trim() == id)) {
        return 'alreadyCandidate';
      }
      return 'other';
    }
    if (checkDedup && dedup.containsKey(id)) return 'duplicate';
    return null;
  }

  void _planLogCount(int count) {
    if (!kDebugMode) return;
    debugPrint('[RECOMMEND_PLAN] count=$count');
  }

  void _phaseLog(String phase) {
    if (!kDebugMode) return;
    debugPrint('[RECOMMEND_PHASE] phase=$phase');
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
    if (!kDebugMode) return;
    final styleKey = _resolvePrimaryStyle(postStyles);
    debugPrint(
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
    if (!kDebugMode) return;
    debugPrint('$_logTagApi phase=$phase start index=$index page=$page');
  }

  void _apiLogStatus({
    required String phase,
    required Object status,
    required int rawCount,
  }) {
    if (!kDebugMode) return;
    debugPrint('$_logTagApi phase=$phase status=$status rawCount=$rawCount');
  }

  void _apiLogDetailed({
    required int planIndex,
    required String keyword,
    required String? genreId,
    required String? shopCode,
    required int page,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '$_logTagApi planIndex=$planIndex keyword=$keyword '
      'genreId=${genreId ?? ''} shopCode=${shopCode ?? ''} page=$page',
    );
  }

  void _filterLog({
    required int raw,
    required int afterExclude,
    required Map<String, int> reasonCounts,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[RECOMMEND_FILTER] raw=$raw afterExclude=$afterExclude reasonCounts=$reasonCounts',
    );
  }

  void _resultLog({required String status, String? reason, int? count}) {
    if (!kDebugMode) return;
    if (reason != null && count != null) {
      debugPrint(
        '[RECOMMEND_RESULT] status=$status count=$count reason=$reason',
      );
      return;
    }
    if (reason != null) {
      debugPrint('[RECOMMEND_RESULT] status=$status reason=$reason');
      return;
    }
    debugPrint('[RECOMMEND_RESULT] status=$status count=${count ?? 0}');
  }

  void _saveLog({
    bool? saved,
    bool keepPreviousBundle = false,
    String? reason,
    int? count,
  }) {
    if (!kDebugMode) return;
    if (keepPreviousBundle) {
      debugPrint('[RECOMMEND_SAVE] keepPreviousBundle=true reason=${reason ?? ''}');
      return;
    }
    if (saved == true) {
      debugPrint('[RECOMMEND_SAVE] savedBundle=true count=${count ?? 0}');
    } else {
      debugPrint(
        '[RECOMMEND_SAVE] savedBundle=false reason=${reason ?? 'unknown'}',
      );
    }
  }

  bool _isRateLimitError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('(429)') ||
        msg.contains('allowed requests has been exceeded');
  }

  void _guard(String message) {
    _lastGuardReason = message.trim();
    if (!kDebugMode) return;
    debugPrint('$_logTagGuard $message');
  }

  void _trigger({required String source}) {
    if (!kDebugMode) return;
    debugPrint('$_logTagTrigger source=$source');
  }

  void _generateLog({
    required String stage,
    required int requestCount,
    required int planCount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
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
    if (!kDebugMode) return;
    debugPrint(
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
    if (!kDebugMode) return;
    debugPrint('[RECOMMEND] search keyword=$keyword');
    debugPrint('[RECOMMEND] genreId=${genreId ?? ''}');
    debugPrint('[RECOMMEND] searchPreference=${searchPreference ?? ''}');
    debugPrint('[RECOMMEND] minPrice=${minPrice?.toString() ?? 'null'}');
    debugPrint('[RECOMMEND] maxPrice=${maxPrice?.toString() ?? 'null'}');
    debugPrint(
      '[RECOMMEND] sanitizedMinPrice=${sanitizedMinPrice?.toString() ?? 'null'}',
    );
    debugPrint(
      '[RECOMMEND] sanitizedMaxPrice=${sanitizedMaxPrice?.toString() ?? 'null'}',
    );
  }

  String? _sortForPostStyles(Set<String> postStyles) {
    if (postStyles.contains(UserProfile.postStyleAffordable)) {
      return null;
    }
    if (postStyles.contains(UserProfile.postStylePremium)) {
      return '-itemPrice';
    }
    if (postStyles.contains(UserProfile.postStyleHighlyRated)) {
      return '-reviewAverage';
    }
    if (postStyles.contains(UserProfile.postStyleReviewRich)) {
      return '-reviewCount';
    }
    if (postStyles.contains(UserProfile.postStyleTrend)) {
      return '-updateTimestamp';
    }
    return null;
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
      if (kDebugMode) {
        debugPrint(
          '[RECOMMEND_EXCLUDE] itemCode=${item.productId} price=${item.itemPrice} reason=$reject',
        );
      }
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

    if (kDebugMode) {
      debugPrint(
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
    }

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
    final title = item.itemName.trim();
    final hasAnyUrl =
        item.itemUrl.trim().isNotEmpty || item.affiliateUrl.trim().isNotEmpty;
    if (item.productId.trim().isEmpty) return 'missingItemCode';
    if (title.isEmpty) return 'missingTitle';
    if (!hasAnyUrl) return 'invalidUrl';
    if (item.itemPrice <= 0) return 'missingPrice';
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
    if (postStyles.contains(UserProfile.postStyleSocial) &&
        item.imageUrl.trim().isEmpty) {
      return 'missingImage';
    }
    if (postStyles.contains(UserProfile.postStyleSocial)) {
      final imageUrl = item.imageUrl.trim();
      if (imageUrl.isNotEmpty &&
          !RegExp(r'^https?://', caseSensitive: false).hasMatch(imageUrl)) {
        return 'invalidImageUrl';
      }
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
    if (kDebugMode) {
      debugPrint(
        '[RECOMMEND_REACTION] commentGenres=${commentGenres.length} '
        'likeGenres=${likeGenres.length} commentShops=${commentShops.length} '
        'likeShops=${likeShops.length} priceBands=${priceBands.join(",")}',
      );
    }
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
    if (kDebugMode && score > 0) {
      debugPrint(
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

    if (kDebugMode) {
      debugPrint(
        '[RECOMMEND_POSTABILITY] itemCode=${item.productId} '
        'score=${score.toStringAsFixed(1)} reasons=${reasons.join("|")}',
      );
    }
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
    if (unfitHit && kDebugMode) {
      debugPrint(
        '[RECOMMEND_ROOM_UNFIT] itemCode=${item.productId} title=${item.itemName}',
      );
    }
    if (kDebugMode) {
      debugPrint(
        '[RECOMMEND_ROOM_FIT] itemCode=${item.productId} score=${score.toStringAsFixed(1)} reasons=${reasons.join("|")}',
      );
    }
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

  final String phase;
  final int relaxLevel;
  final String source;
  final String keyword;
  final String? genreId;
  final String? shopCode;
  final String? sortOverride;
}
