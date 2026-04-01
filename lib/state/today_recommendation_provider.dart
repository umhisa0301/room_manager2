import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/today_recommendation.dart';
import '../models/user_profile.dart';
import '../repository/rakuten_search_repository.dart';
import '../repository/today_recommendation_repository.dart';
import 'rakuten_managed_product_provider.dart';

class TodayRecommendationProvider extends ChangeNotifier {
  TodayRecommendationProvider({
    required TodayRecommendationRepository repository,
    required RakutenSearchRepository searchRepository,
  })  : _repository = repository,
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
      _errorMessage =
          '今日のおすすめを用意できませんでした。通信状況を確認し、もう一度「再生成」をお試しください。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markSkipped(String productId) async {
    final b = _bundle;
    if (b == null) return;
    final nextEntries = b.entries.map((e) {
      if (e.item.productId != productId) return e;
      if (e.decision != TodayRecommendationDecision.pending) return e;
      return e.copyWith(decision: TodayRecommendationDecision.skipped);
    }).toList(growable: false);
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
    final nextEntries = b.entries.map((e) {
      if (e.item.productId != item.productId) return e;
      return e.copyWith(decision: TodayRecommendationDecision.addedCandidate);
    }).toList(growable: false);
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
    final savedShopIds = savedShops.map((e) => e.shopId.trim()).toSet();
    final keywords = _buildKeywords(profile, managedItems);
    final scoreHintShops = _countManagedShopFrequency(managedItems);

    final pool = <RakutenSearchItem>[];
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
      dedup.putIfAbsent(id, () => item);
    }

    final genreWords = _splitWords(profile.favoriteGenres);
    final scored = dedup.values.toList()
      ..sort((a, b) {
        final bs = _scoreOf(
          b,
          savedShopIds: savedShopIds,
          preferredGenreWords: genreWords,
          managedShopFrequency: scoreHintShops,
        );
        final as = _scoreOf(
          a,
          savedShopIds: savedShopIds,
          preferredGenreWords: genreWords,
          managedShopFrequency: scoreHintShops,
        );
        return bs.compareTo(as);
      });

    final selected = scored.take(10).toList(growable: false);
    final entries = selected
        .map((e) => TodayRecommendationEntry(item: e))
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
    out.addAll(_splitWords(profile.favoriteGenres));
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

  Set<String> _splitWords(String source) {
    final out = <String>{};
    for (final raw in source.split(RegExp(r'[,、，\s]+'))) {
      final v = raw.trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out;
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

  double _scoreOf(
    RakutenSearchItem item, {
    required Set<String> savedShopIds,
    required Set<String> preferredGenreWords,
    required Map<String, int> managedShopFrequency,
  }) {
    var score = 0.0;
    score += item.reviewCount * 0.08;
    score += item.reviewAverage * 12;
    final shopCode = item.shopCode.trim();
    if (shopCode.isNotEmpty && savedShopIds.contains(shopCode)) {
      score += 25;
    }
    if (shopCode.isNotEmpty) {
      score += (managedShopFrequency[shopCode] ?? 0) * 2.5;
    }
    if (preferredGenreWords.isNotEmpty) {
      final name = item.itemName;
      for (final w in preferredGenreWords) {
        if (name.contains(w)) {
          score += 8;
          break;
        }
      }
    }
    return score;
  }

  String _localDateKey(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  }
}

