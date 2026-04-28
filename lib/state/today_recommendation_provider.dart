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

  TodayRecommendationBundle? get bundle => _bundle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalCount => _bundle?.entries.length ?? 0;
  int get pendingCount => _bundle?.pendingCount ?? 0;
  bool get isCompleted => _bundle?.isCompleted ?? false;

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
  }) async {
    final todayKey = _localDateKey(DateTime.now());
    if (_bundle != null && _bundle!.localDateKey == todayKey) {
      return;
    }
    await regenerateToday(
      profile: profile,
      managedItems: managedItems,
      savedShops: savedShops,
    );
  }

  Future<void> regenerateToday({
    required UserProfile profile,
    required List<RakutenManagedProduct> managedItems,
    required List<SavedShop> savedShops,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final generated = await _generate(
        profile: profile,
        managedItems: managedItems,
        savedShops: savedShops,
      );
      _bundle = generated;
      await _repository.save(generated);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TodayRecommendation] regenerateToday failed: $e');
        debugPrint('$st');
      }
      _errorMessage = '今日のおすすめを用意できませんでした。通信状況を確認し、もう一度「再生成」をお試しください。';
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
    final keywords = _buildKeywords(profile, managedItems);
    final scoreHintShops = _countManagedShopFrequency(managedItems);
    final doneItems = managedItems
        .where((e) => e.status == RakutenManagedProductStatus.done)
        .toList(growable: false);
    final candidateItems = managedItems
        .where((e) => e.status == RakutenManagedProductStatus.candidate)
        .toList(growable: false);

    final pool = <RakutenSearchItem>[];
    // 好きなジャンルがある場合はジャンル指定を優先し、ユーザーごとに候補母集団を変える。
    for (final genreId in favoriteGenreIds.take(5)) {
      final keyword = keywords.isEmpty ? '人気' : keywords.first;
      final list = await _searchRepository.search(
        condition: RakutenProductSearchCondition(
          keyword: keyword,
          genreId: genreId,
          minReviewCount: 10,
          minReviewAverage: 3.6,
        ),
      );
      pool.addAll(list.take(24));
    }

    // 保存済ショップを優先取得（上位2ショップ）
    for (final shop in savedShops.take(2)) {
      final keyword = keywords.isEmpty ? '人気' : keywords.first;
      final list = await _searchRepository.search(
        condition: RakutenProductSearchCondition(
          keyword: keyword,
          shopCode: shop.shopId.trim(),
          minReviewCount: 20,
          minReviewAverage: 3.8,
        ),
      );
      pool.addAll(list.take(20));
    }
    // 通常検索
    for (final keyword in keywords.take(4)) {
      final list = await _searchRepository.search(
        condition: RakutenProductSearchCondition(
          keyword: keyword,
          minReviewCount: 20,
          minReviewAverage: 3.8,
        ),
      );
      pool.addAll(list.take(30));
    }
    if (pool.isEmpty) {
      final fallback = await _searchRepository.search(
        condition: const RakutenProductSearchCondition(
          keyword: '人気',
          minReviewCount: 20,
          minReviewAverage: 3.8,
        ),
      );
      pool.addAll(fallback.take(40));
    }

    final dedup = <String, RakutenSearchItem>{};
    for (final item in pool) {
      final id = item.productId.trim();
      if (id.isEmpty || excludeIds.contains(id)) continue;
      if (_isExtremePrice(item.itemPrice)) continue;
      dedup.putIfAbsent(id, () => item);
    }

    final genreWords = UserProfilePreferredGenreWords.fromProfile(profile);
    final scored =
        dedup.values
            .map(
              (item) => _scoreRecommendation(
                item,
                favoriteGenreIds: favoriteGenreIds,
                savedShopIds: savedShopIds,
                preferredGenreWords: genreWords,
                doneItems: doneItems,
                candidateItems: candidateItems,
                managedShopFrequency: scoreHintShops,
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final selected = _pickBalancedRecommendations(scored);
    final entries = selected
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
    return TodayRecommendationBundle(
      localDateKey: _localDateKey(DateTime.now()),
      generatedAt: DateTime.now(),
      entries: entries,
    );
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

  Map<String, int> _countManagedShopFrequency(
    List<RakutenManagedProduct> managedItems,
  ) {
    final map = <String, int>{};
    for (final item in managedItems) {
      final code = item.shopCode.trim();
      if (code.isEmpty) continue;
      map[code] = (map[code] ?? 0) + 1;
    }
    return map;
  }

  List<_ScoredRecommendation> _pickBalancedRecommendations(
    List<_ScoredRecommendation> scored,
  ) {
    if (scored.length <= 10) return scored;
    final out = <_ScoredRecommendation>[];

    void addFrom(TodayRecommendationSection section, int max) {
      for (final item in scored.where((e) => e.section == section)) {
        if (out.length >= 10) break;
        final sectionCount = out.where((e) => e.section == section).length;
        if (sectionCount >= max) break;
        if (!out.any((e) => e.item.productId == item.item.productId)) {
          out.add(item);
        }
      }
    }

    addFrom(TodayRecommendationSection.sellable, 6);
    addFrom(TodayRecommendationSection.popular, 3);
    addFrom(TodayRecommendationSection.fresh, 2);
    for (final item in scored) {
      if (out.length >= 10) break;
      if (!out.any((e) => e.item.productId == item.item.productId)) {
        out.add(item);
      }
    }
    return out;
  }

  _ScoredRecommendation _scoreRecommendation(
    RakutenSearchItem item, {
    required Set<String> favoriteGenreIds,
    required Set<String> savedShopIds,
    required Set<String> preferredGenreWords,
    required List<RakutenManagedProduct> doneItems,
    required List<RakutenManagedProduct> candidateItems,
    required Map<String, int> managedShopFrequency,
  }) {
    final genreMatch = _genreMatchScore(
      item,
      favoriteGenreIds,
      preferredGenreWords,
    );
    final doneSimilarity = _historySimilarity(item, doneItems);
    final candidateSimilarity = _historySimilarity(item, candidateItems);
    final shopCode = item.shopCode.trim();
    final shopMatch =
        shopCode.isNotEmpty &&
            (savedShopIds.contains(shopCode) ||
                (managedShopFrequency[shopCode] ?? 0) > 0)
        ? 1.0
        : 0.0;
    final popularity = _popularityScore(item);
    final priceScore = _priceScore(item.itemPrice);

    final personalizedScore =
        genreMatch * 3 +
        doneSimilarity * 4 +
        candidateSimilarity * 2 +
        shopMatch * 2;
    final finalScore = personalizedScore * 5 + popularity * 2 + priceScore * 3;
    final section = priceScore >= 3
        ? TodayRecommendationSection.sellable
        : popularity > 0.75
        ? TodayRecommendationSection.popular
        : TodayRecommendationSection.fresh;

    return _ScoredRecommendation(
      item: item,
      score: finalScore,
      priceScore: priceScore,
      reason: _reasonFor(
        doneSimilarity: doneSimilarity,
        candidateSimilarity: candidateSimilarity,
        shopMatch: shopMatch,
        genreMatch: genreMatch,
        popularity: popularity,
        priceScore: priceScore,
      ),
      section: section,
    );
  }

  bool _isExtremePrice(int price) {
    return price < 500 || price >= 30000;
  }

  double _priceScore(int price) {
    if (price >= 2000 && price < 5000) return 3;
    if (price >= 1000 && price < 2000) return 2;
    if (price >= 5000 && price < 10000) return 2;
    if (price >= 10000) return -2;
    return -1;
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

  double _popularityScore(RakutenSearchItem item) {
    final reviewScore = (item.reviewCount / 800).clamp(0.0, 1.0);
    final ratingScore = (item.reviewAverage / 5).clamp(0.0, 1.0);
    return (reviewScore * 0.65 + ratingScore * 0.35).clamp(0.0, 1.0);
  }

  String _reasonFor({
    required double doneSimilarity,
    required double candidateSimilarity,
    required double shopMatch,
    required double genreMatch,
    required double popularity,
    required double priceScore,
  }) {
    if (priceScore >= 3) return '売れやすい価格帯';
    if (doneSimilarity >= 0.45) return 'あなたのコレ履歴に基づく';
    if (shopMatch > 0) return 'よく保存しているショップ';
    if (candidateSimilarity >= 0.45) return '候補にした商品に近い';
    if (genreMatch >= 0.55) return '好きなジャンルに近い';
    if (popularity >= 0.70) return '人気商品';
    return '新しい候補';
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
