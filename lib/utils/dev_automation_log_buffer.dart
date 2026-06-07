import 'package:flutter/foundation.dart';

/// 開発者向け自動検証の画面上ログ（最新 [maxEntries] 件を保持）。
class DevAutomationLogBuffer extends ChangeNotifier {
  DevAutomationLogBuffer({this.maxEntries = defaultMaxEntries});

  static const int defaultMaxEntries = 50;

  final int maxEntries;
  final List<String> _entries = <String>[];

  List<String> get entries => List<String>.unmodifiable(_entries);

  void add(String message) {
    final line = message.trim();
    if (line.isEmpty) return;
    _entries.add(line);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    debugPrint(line);
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}
