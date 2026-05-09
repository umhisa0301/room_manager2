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
  static const Duration _autoRetryCooldown = Duration(minutes: 5);

  TodayRecommendationBundle? get bundle => _bundle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TodayRecommendationGenerationStatus get generationStatus => _generationStatus;
  bool get isInCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

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

  Future<void> ensureToday({
    required UserProfile profile,
    required List<RakutenManagedProduct> managedItems,
    required List<SavedShop> savedShops,
    String trigger = 'ensure',
  }) async {
    _trace('trigger=$trigger');
    _trace('action=ensureToday');
    _trace('alreadyGenerating=$_isLoading');
    _trace('lastGeneratedAt=${_bundle?.generatedAt.toIso8601String() ?? 'null'}');
    final todayKey = _localDateKey(DateTime.now());
    if (_bundle != null && _bundle!.localDateKey == todayKey) {
      _trace('shouldSkipBecauseRecentlyTried=true');
      _guard('skip reason=hasTodayBundle');
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
    _trace('trigger=$trigger');
    _trace('action=regenerateToday');
    _trace('alreadyGenerating=$_isLoading');
    _trace('lastGeneratedAt=${_bundle?.generatedAt.toIso8601String() ?? 'null'}');
    if (_isLoading) {
      _guard('skip reason=alreadyGenerating');
      return;
    }
    if (!manual && isInCooldown) {
      _guard('skip reason=cooldown');
      return;
    }
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
          : TodayRecommendationGenerationStatus.ready;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TodayRecommendation] regenerateToday failed: $e');
        debugPrint('$st');
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('(429)') ||
          msg.contains('allowed requests has been exceeded')) {
        _generationStatus = TodayRecommendationGenerationStatus.failedRateLimit;
        _cooldownUntil = DateTime.now().add(_autoRetryCooldown);
      } else {
        _generationStatus = TodayRecommendationGenerationStatus.failedApiError;
      }
      _errorMessage = 'おすすめを準備できませんでした。少し時間をおいて再試行してください';
      _resultLog(status: 'failed', reason: _failureTypeFromError(e));
      _saveLog(saved: false, reason: _failureTypeFromError(e));
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

    final pool = <String, RakutenSearchItem>{};
    final metaById = <String, _ItemPoolMeta>{};
    var apiCalls = 0;
    var allPlansNoItems = true;
    const maxApiHard = 10;

    bool canCallMoreApi(int entryCount) {
      if (entryCount >= 10) return false;
      if (apiCalls >= maxApiHard) return false;
      return true;
    }

    final genreWords = UserProfilePreferredGenreWords.fromProfile(profile);
    for (var i = 0; i < plans.length; i++) {
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
        _trace('raw item itemCode=${item.productId} title=${item.itemName}');
        final exclusion = _excludeReason(
          item: item,
          excludeIds: excludeIds,
          doneItems: doneItems,
          candidateItems: candidateItems,
          dedup: pool,
        );
        if (exclusion != null) {
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

    if (pool.isEmpty && allPlansNoItems) {
      _resultLog(status: 'empty', reason: 'allPlansNoItems');
    }

    final finalized = _finalizeFromPool(
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
    );
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
        debugPrint('[RECOMMEND_RESULT] status=empty reason=noAcceptedItems');
      } else if (entries.length < 10) {
        _resultLog(
          status: 'partial',
          count: entries.length,
          reason: 'shortfallAfterPlans',
        );
      }
    }
    _trace('finalCandidateCount=${entries.length}');
    _trace('failureType=${entries.isEmpty ? 'empty' : 'none'}');
    _resultLog(
      status: entries.isEmpty ? 'empty' : 'success',
      count: entries.length,
      reason: entries.isEmpty ? 'allPlansNoItems' : null,
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
    final keywordAlt =
        keywords.length >= 2 ? keywords[1] : (keywords.isEmpty ? 'ランキング' : '売れ筋');
    final historyGenres = _topGenresFromHistory(doneItems, candidateItems, limit: 4);
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

  ({List<TodayRecommendationEntry> entries, int personalCount, int relaxedCount, int discoveryCount}) _finalizeFromPool({
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
  }) {
    final scored =
        pool.values
            .map(
              (item) => _scoreRecommendationForBucket(
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
              ),
            )
            .where((e) => e != null)
            .cast<_ScoredRecommendation>()
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final picked = _pickBalancedBySection(scored);
    final entries =
        picked
            .map(
              (e) => TodayRecommendationEntry(
                item: e.item,
                reason: e.reason,
                section: e.section,
                score: e.score,
                priceScore: e.priceScore,
              ),
            )
            .toList(growable: false);

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

    void takeFrom(List<_ScoredRecommendation> list, int max) {
      for (final e in list) {
        if (selected.length >= 10) return;
        if (max <= 0) return;
        final id = e.item.productId.trim();
        if (id.isEmpty || selectedIds.contains(id)) continue;
        selected.add(e);
        selectedIds.add(id);
        max -= 1;
      }
    }

    takeFrom(popular, 7);
    takeFrom(sellable, 3);
    takeFrom(fresh, 3);

    if (selected.length < 10) {
      for (final e in scored) {
        if (selected.length >= 10) break;
        final id = e.item.productId.trim();
        if (id.isEmpty || selectedIds.contains(id)) continue;
        final freshCount =
            selected.where((x) => x.section == TodayRecommendationSection.fresh).length;
        if (e.section == TodayRecommendationSection.fresh && freshCount >= 3) {
          continue;
        }
        selected.add(e);
        selectedIds.add(id);
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
        _resultLog(status: 'failed', reason: 'rateLimit');
      } else if (msg.contains('(400)') || msg.contains('(500)')) {
        _resultLog(status: 'failed', reason: 'apiError');
      } else {
        _resultLog(status: 'failed', reason: 'exception');
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
    debugPrint('[RECOMMEND_API] phase=$phase start index=$index page=$page');
  }

  void _apiLogStatus({
    required String phase,
    required Object status,
    required int rawCount,
  }) {
    if (!kDebugMode) return;
    debugPrint('[RECOMMEND_API] phase=$phase status=$status rawCount=$rawCount');
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

  void _resultLog({
    required String status,
    String? reason,
    int? count,
  }) {
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

  void _saveLog({required bool saved, String? reason, int? count}) {
    if (!kDebugMode) return;
    if (saved) {
      debugPrint('[RECOMMEND_SAVE] savedBundle=true count=${count ?? 0}');
    } else {
      debugPrint('[RECOMMEND_SAVE] savedBundle=false reason=${reason ?? 'unknown'}');
    }
  }

  void _guard(String message) {
    if (!kDebugMode) return;
    debugPrint('[RECOMMEND_GUARD] $message');
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
      return '-reviewCount';
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
  }) {
    final reject = _recommendRejectReason(item, postStyles: postStyles);
    if (reject != null) {
      if (kDebugMode) {
        debugPrint('[RECOMMEND_EXCLUDE] itemCode=${item.productId} reason=$reject');
      }
      return null;
    }

    var score = 0.0;
    final reasons = <String>[];
    final genreMatch = _genreMatchScore(item, favoriteGenreIds, preferredGenreWords);
    final doneSimilarity = _historySimilarity(item, doneItems);
    final candidateSimilarity = _historySimilarity(item, candidateItems);
    final savedShopMatch = item.shopCode.trim().isNotEmpty &&
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
        'reviewCount=${item.reviewCount} score=${score.toStringAsFixed(1)} '
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
    if (item.itemPrice >= 300000) return 'tooExpensive';
    if (postStyles.contains(UserProfile.postStyleAffordable) &&
        item.itemPrice > 0 &&
        item.itemPrice < 300) {
      return 'tooCheap';
    }
    final businessWord = RegExp(
      r'業務用|法人|産業|工業|周波数変換器|三相|50KVA|中古|未使用品|測定器|建設|部材|部品取り|訳あり高額',
      caseSensitive: false,
    );
    if (businessWord.hasMatch(title)) return 'businessItem';
    if (item.reviewCount == 0 && item.itemPrice >= 50000) return 'highPriceNoReview';
    if (postStyles.contains(UserProfile.postStyleSocial) &&
        item.imageUrl.trim().isEmpty) {
      return 'missingImage';
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
        return item.reviewAverage >= 4.0 ? 20 : 0;
      case UserProfile.postStyleSocial:
        return item.imageUrl.trim().isNotEmpty ? 20 : 0;
      case UserProfile.postStylePractical:
        return RegExp(r'日用品|育児|生活|キッチン|収納|家電').hasMatch(item.itemName)
            ? 20
            : 0;
      case UserProfile.postStyleReviewRich:
        return item.reviewCount >= 30 ? 20 : (item.reviewCount >= 10 ? 10 : 0);
      case UserProfile.postStyleTrend:
        return RegExp(r'新作|新着|季節|限定|トレンド').hasMatch(item.itemName) ? 20 : 8;
      case UserProfile.postStyleBalance:
      default:
        return 20;
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
