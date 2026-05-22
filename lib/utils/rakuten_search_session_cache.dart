import 'package:flutter/foundation.dart';

import '../models/rakuten_search_item.dart';
import '../state/rakuten_search_provider.dart';
import 'search_result_envelope.dart';

/// 探す画面の同一セッション内状態保持（タブ往復・探し方切替用）。
class RakutenSearchSessionCache {
  RakutenSearchSessionCache._();

  static final RakutenSearchSessionCache instance = RakutenSearchSessionCache._();

  final Map<String, _ModeSnapshot> _providerByMode = {};
  final Map<String, RakutenSearchUiSnapshot> _uiByMode = {};
  final Map<String, SearchResultEnvelope> _envelopeByMode = {};

  static const String modeProduct = 'productSearch';
  static const String modeGenre = 'genreSearch';
  static const String modeSavedShop = 'savedShopSearch';
  static const String modeShopDiscovery = 'shopDiscovery';

  String modeKey({
    required bool savedShopKeywordEntry,
    required String searchModeName,
  }) {
    if (savedShopKeywordEntry) return modeSavedShop;
    return searchModeName;
  }

  void saveProviderSnapshot(
    String key,
    RakutenSearchProvider search, {
    SearchResultEnvelope? envelope,
  }) {
    _providerByMode[key] = _ModeSnapshot(
      status: search.status,
      results: List<RakutenSearchItem>.from(search.results),
      errorMessage: search.errorMessage,
      lastKeyword: search.lastKeyword,
      keywordSearchHadApiHitsButNoVisibleResults:
          search.keywordSearchHadApiHitsButNoVisibleResults,
      ownerMode: envelope?.ownerMode ?? key,
      searchKey: envelope?.searchKey,
      genreId: envelope?.genreId,
      shopCode: envelope?.shopCode,
    );
    if (envelope != null) {
      _envelopeByMode[key] = envelope;
    }
    _log('save', key, search.results.length);
  }

  void restoreProviderSnapshot(String key, RakutenSearchProvider search) {
    final snap = _providerByMode[key];
    if (snap == null) {
      search.resetTransientState();
      _log('restore', key, 0);
      return;
    }
    search.restoreFromSnapshot(
      status: snap.status,
      results: snap.results,
      errorMessage: snap.errorMessage,
      lastKeyword: snap.lastKeyword,
      keywordSearchHadApiHitsButNoVisibleResults:
          snap.keywordSearchHadApiHitsButNoVisibleResults,
      errorModeTag: snap.status == RakutenSearchStatus.error
          ? _providerModeTagForCacheKey(key)
          : null,
    );
    _log('restore', key, snap.results.length);
  }

  SearchResultEnvelope? envelopeForMode(String key) => _envelopeByMode[key];

  void saveUiSnapshot(String key, RakutenSearchUiSnapshot ui) {
    _uiByMode[key] = ui;
  }

  RakutenSearchUiSnapshot? uiSnapshot(String key) => _uiByMode[key];

  /// Provider スナップショットと結果エンベロープのみ削除（UI 入力は保持）。
  void clearProviderSnapshot(String key) {
    _providerByMode.remove(key);
    _envelopeByMode.remove(key);
    _log('clearProvider', key, 0);
  }

  void clearMode(String key) {
    _providerByMode.remove(key);
    _uiByMode.remove(key);
    _envelopeByMode.remove(key);
    _log('clear', key, 0);
  }

  static String? _providerModeTagForCacheKey(String key) {
    return switch (key) {
      modeSavedShop => 'savedShop',
      modeGenre => 'genre',
      modeShopDiscovery => 'shopDiscovery',
      _ => 'product',
    };
  }

  void _log(String event, String key, int resultCount) {
    if (!kDebugMode) return;
    debugPrint(
      '[SEARCH_STATE_PERSIST] screen=$key event=$event resultCount=$resultCount',
    );
  }
}

class _ModeSnapshot {
  _ModeSnapshot({
    required this.status,
    required this.results,
    required this.errorMessage,
    required this.lastKeyword,
    required this.keywordSearchHadApiHitsButNoVisibleResults,
    required this.ownerMode,
    this.searchKey,
    this.genreId,
    this.shopCode,
  });

  final RakutenSearchStatus status;
  final List<RakutenSearchItem> results;
  final String errorMessage;
  final String lastKeyword;
  final bool keywordSearchHadApiHitsButNoVisibleResults;
  final String ownerMode;
  final String? searchKey;
  final String? genreId;
  final String? shopCode;
}

/// 検索画面の入力・選択状態（コントローラ文字列のスナップショット）。
class RakutenSearchUiSnapshot {
  const RakutenSearchUiSnapshot({
    this.keyword = '',
    this.minPrice = '',
    this.maxPrice = '',
    this.excludeKeyword = '',
    this.minReviewCount = '',
    this.minReviewAverage = '',
    this.minCommentCount = '',
    this.genreAux = '',
    this.shopDiscoveryKeyword = '',
    this.shopDiscoveryExclude = '',
    this.shopDiscoveryMinReviewCount = '',
    this.shopDiscoveryMinReviewAverage = '',
    this.shopDiscoveryShopLimit = '10',
    this.shopDiscoveryItemsPerShop = '5',
    this.selectedShopCode,
    this.selectedGenreId,
    this.productDetailGenreId,
    this.selectedDiscoveryGenreId,
    this.selectionMode = false,
    this.selectedProductIds = const {},
    this.searchHeaderCollapsed = false,
    this.savedShopKeywordFlow = false,
    this.shopDiscoveryHasSearched = false,
  });

  final String keyword;
  final String minPrice;
  final String maxPrice;
  final String excludeKeyword;
  final String minReviewCount;
  final String minReviewAverage;
  final String minCommentCount;
  final String genreAux;
  final String shopDiscoveryKeyword;
  final String shopDiscoveryExclude;
  final String shopDiscoveryMinReviewCount;
  final String shopDiscoveryMinReviewAverage;
  final String shopDiscoveryShopLimit;
  final String shopDiscoveryItemsPerShop;
  final String? selectedShopCode;
  final String? selectedGenreId;

  /// 商品名モードの詳細条件シートでのみ使うジャンル絞り込み。
  final String? productDetailGenreId;
  final String? selectedDiscoveryGenreId;
  final bool selectionMode;
  final Set<String> selectedProductIds;
  final bool searchHeaderCollapsed;
  final bool savedShopKeywordFlow;
  final bool shopDiscoveryHasSearched;
}
