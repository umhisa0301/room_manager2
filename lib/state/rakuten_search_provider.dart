import 'package:flutter/foundation.dart';

import '../config/rakuten_api_config.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_search_repository.dart';

enum RakutenSearchStatus { idle, loading, success, error }

/// 楽天検索画面の状態管理。
class RakutenSearchProvider extends ChangeNotifier {
  RakutenSearchProvider({required RakutenSearchRepository repository})
    : _repository = repository;

  final RakutenSearchRepository _repository;

  RakutenSearchStatus _status = RakutenSearchStatus.idle;
  List<RakutenSearchItem> _results = const [];
  String _errorMessage = '';
  String _lastKeyword = '';

  /// キーワード検索で API から商品は取れたが、登録済み除外・アプリ側条件の結果リストが空。
  bool _keywordSearchHadApiHitsButNoVisibleResults = false;

  /// 直近の [searchWithCondition] で `excludeRegisteredProductIds` を使った場合のフェッチメタ（それ以外は null）。
  RakutenKeywordManagedFetchSummary? _keywordManagedFetchSummary;

  RakutenSearchStatus get status => _status;
  List<RakutenSearchItem> get results => _results;
  String get errorMessage => _errorMessage;
  String get lastKeyword => _lastKeyword;

  bool get keywordSearchHadApiHitsButNoVisibleResults =>
      _keywordSearchHadApiHitsButNoVisibleResults;

  RakutenKeywordManagedFetchSummary? get keywordManagedFetchSummary =>
      _keywordManagedFetchSummary;

  /// 管理除外パスで目標件数に届かなかったときの短文（キーワードタブ向け）。届いている・該当なしは null。
  String? keywordManagedVisibleShortfallNote() {
    final s = _keywordManagedFetchSummary;
    if (s == null) return null;
    final n = _results.length;
    if (n >= s.targetVisibleCap) return null;
    switch (s.stopReason) {
      case RakutenKeywordSearchStopReason.reachedTarget:
        return null;
      case RakutenKeywordSearchStopReason.partialFetchFailure:
        return '途中の取得に失敗したため、表示は$n件です。しばらくして再検索してください。';
      case RakutenKeywordSearchStopReason.maxPagesReached:
        return '取得ページ上限に達しました。除外後の表示は$n件です。';
      case RakutenKeywordSearchStopReason.apiNoMoreResults:
        return '登録済・保存ショップを除くと、この条件で表示できる新しい候補は$n件でした。';
    }
  }

  /// 直近の成功結果のうち `affiliateUrl` が空でない件数（API側のアフィリエイト応答の目安）。
  int get resultsWithAffiliateUrlCount =>
      _results.where((e) => e.hasAffiliateUrlInResponse).length;

  Future<void> search(String keyword) async {
    final condition = RakutenProductSearchCondition(
      keyword: keyword,
    ).normalized();
    if (condition.keyword.isEmpty) {
      _status = RakutenSearchStatus.idle;
      _results = const [];
      _errorMessage = '';
      _lastKeyword = '';
      _keywordSearchHadApiHitsButNoVisibleResults = false;
      _keywordManagedFetchSummary = null;
      notifyListeners();
      return;
    }
    await searchWithCondition(condition);
  }

  Future<void> searchWithCondition(
    RakutenProductSearchCondition condition, {
    Set<String>? excludeRegisteredProductIds,
    Set<String>? excludeSavedShopCodes,
  }) async {
    final normalized = condition.normalized();
    // キーワード検索だけでなく、genreId 指定のみの検索（ジャンル検索・ショップ発掘）も許可する。
    final hasKeyword = normalized.keyword.isNotEmpty;
    final hasGenre =
        normalized.genreId != null && normalized.genreId!.isNotEmpty;
    final hasShop =
        normalized.shopCode != null && normalized.shopCode!.trim().isNotEmpty;
    if (!hasKeyword && !hasGenre && !hasShop) {
      _status = RakutenSearchStatus.idle;
      _results = const [];
      _errorMessage = '';
      _lastKeyword = '';
      _keywordSearchHadApiHitsButNoVisibleResults = false;
      _keywordManagedFetchSummary = null;
      notifyListeners();
      return;
    }
    _status = RakutenSearchStatus.loading;
    _errorMessage = '';
    _lastKeyword = normalized.keyword;
    _keywordSearchHadApiHitsButNoVisibleResults = false;
    _keywordManagedFetchSummary = null;
    notifyListeners();

    try {
      final List<RakutenSearchItem> fetched;
      if (excludeRegisteredProductIds != null) {
        final result = await _repository.searchKeywordWithManagedExclusion(
          condition: normalized,
          excludeRegisteredProductIds: excludeRegisteredProductIds,
          excludeSavedShopCodes: excludeSavedShopCodes ?? const {},
        );
        fetched = result.items;
        _keywordSearchHadApiHitsButNoVisibleResults =
            result.receivedAnyItemFromApi && result.items.isEmpty;
        _keywordManagedFetchSummary = RakutenKeywordManagedFetchSummary.from(
          result,
        );
      } else {
        fetched = await _repository.search(condition: normalized);
        _keywordManagedFetchSummary = null;
      }
      if (kDebugMode) {
        final g = normalized.genreId?.trim();
        final tag = g != null && g.isNotEmpty
            ? 'genreSearch'
            : 'searchWithCondition';
        debugPrint(
          '[Rakuten] $tag provider after repository count=${fetched.length}',
        );
      }
      _results = fetched;
      _status = RakutenSearchStatus.success;
      final withAff = fetched.where((e) => e.hasAffiliateUrlInResponse).length;
      debugPrint(
        '[Rakuten] affiliateIdをリクエストに付与: '
        '${RakutenApiConfig.requestIncludesAffiliateId} / '
        'affiliateUrlあり: $withAff / ${fetched.length} 件',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Rakuten] searchWithCondition failed: $e');
        debugPrint('$st');
      }
      _results = const [];
      _status = RakutenSearchStatus.error;
      _errorMessage = _userFacingError(e);
      _keywordSearchHadApiHitsButNoVisibleResults = false;
      _keywordManagedFetchSummary = null;
    }
    notifyListeners();
  }

  String _userFacingError(Object e) {
    final raw = e.toString();
    final body = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length).trim()
        : raw.trim();
    if (body.contains('楽天APIのアプリIDが未設定')) {
      return '楽天APIの設定（アプリID）がまだありません。ビルド設定をご確認ください。';
    }
    if (body.contains('楽天のアプリIDが無効です')) {
      return body;
    }
    if (body.startsWith('楽天API:')) {
      if (kDebugMode) {
        debugPrint('[Rakuten] API rejected params (not shown in UI): $body');
      }
      return '検索条件が通らない可能性があります。キーワードや条件を少し変えて、もう一度お試しください。';
    }
    return '通信状況やキーワード・条件をご確認のうえ、もう一度お試しください。';
  }

  /// 検索画面の一覧・ローディング・エラーなど一時状態だけを初期化する（永続データは変更しない）。
  void resetTransientState() {
    _status = RakutenSearchStatus.idle;
    _results = const [];
    _errorMessage = '';
    _lastKeyword = '';
    _keywordSearchHadApiHitsButNoVisibleResults = false;
    _keywordManagedFetchSummary = null;
    notifyListeners();
  }
}
