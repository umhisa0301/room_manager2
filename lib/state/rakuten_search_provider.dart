import 'package:flutter/foundation.dart';

import '../config/rakuten_api_config.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_search_repository.dart';

enum RakutenSearchStatus {
  idle,
  loading,
  success,
  error,
}

/// 楽天検索画面の状態管理。
class RakutenSearchProvider extends ChangeNotifier {
  RakutenSearchProvider({
    required RakutenSearchRepository repository,
  }) : _repository = repository;

  final RakutenSearchRepository _repository;

  RakutenSearchStatus _status = RakutenSearchStatus.idle;
  List<RakutenSearchItem> _results = const [];
  String _errorMessage = '';
  String _lastKeyword = '';

  RakutenSearchStatus get status => _status;
  List<RakutenSearchItem> get results => _results;
  String get errorMessage => _errorMessage;
  String get lastKeyword => _lastKeyword;

  /// 直近の成功結果のうち `affiliateUrl` が空でない件数（API側のアフィリエイト応答の目安）。
  int get resultsWithAffiliateUrlCount => _results
      .where((e) => e.hasAffiliateUrlInResponse)
      .length;

  Future<void> search(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) {
      _status = RakutenSearchStatus.idle;
      _results = const [];
      _errorMessage = '';
      _lastKeyword = '';
      notifyListeners();
      return;
    }
    _status = RakutenSearchStatus.loading;
    _errorMessage = '';
    _lastKeyword = q;
    notifyListeners();

    try {
      final fetched = await _repository.search(keyword: q);
      _results = fetched;
      _status = RakutenSearchStatus.success;
      final withAff = fetched.where((e) => e.hasAffiliateUrlInResponse).length;
      debugPrint(
        '[Rakuten] affiliateIdをリクエストに付与: '
        '${RakutenApiConfig.requestIncludesAffiliateId} / '
        'affiliateUrlあり: $withAff / ${fetched.length} 件',
      );
    } catch (e) {
      _results = const [];
      _status = RakutenSearchStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// 検索画面の一覧・ローディング・エラーなど一時状態だけを初期化する（永続データは変更しない）。
  void resetTransientState() {
    _status = RakutenSearchStatus.idle;
    _results = const [];
    _errorMessage = '';
    _lastKeyword = '';
    notifyListeners();
  }
}

