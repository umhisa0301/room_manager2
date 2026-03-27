import 'package:flutter/foundation.dart';

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
    } catch (e) {
      _results = const [];
      _status = RakutenSearchStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }
}

