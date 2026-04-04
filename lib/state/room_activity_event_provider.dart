import 'package:flutter/foundation.dart';

import '../models/room_activity_event.dart';
import '../repository/room_activity_event_repository.dart';

/// メモリ上のイベント一覧を UI に公開し、[append] で永続化と通知を行う。
class RoomActivityEventProvider extends ChangeNotifier {
  RoomActivityEventProvider({required RoomActivityEventRepository repository})
    : _repository = repository {
    _events = _repository.loadAll();
  }

  final RoomActivityEventRepository _repository;
  List<RoomActivityEvent> _events = const [];

  List<RoomActivityEvent> get events => List.unmodifiable(_events);

  Future<void> append(RoomActivityEvent event) async {
    await _repository.append(event);
    _events = _repository.loadAll();
    notifyListeners();
  }

  /// 外部で prefs が変わった場合の再読込（通常は不要）。
  void reloadFromStorage() {
    _events = _repository.loadAll();
    notifyListeners();
  }
}
