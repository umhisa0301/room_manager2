/// 楽天 API 呼び出しの優先順位（手動検索 > おすすめ自動生成 > 補完）。
abstract final class ApiRequestCoordinator {
  static int _manualSearchDepth = 0;

  static bool get manualSearchRunning => _manualSearchDepth > 0;

  static void onManualSearchStarted() {
    _manualSearchDepth++;
  }

  static void onManualSearchEnded() {
    if (_manualSearchDepth > 0) {
      _manualSearchDepth--;
    }
  }

  /// 手動検索が終わるまで待つ（おすすめ生成の API 競合回避）。
  static Future<bool> waitForManualSearchIdle({
    Duration maxWait = const Duration(seconds: 45),
  }) async {
    if (!manualSearchRunning) return true;
    final deadline = DateTime.now().add(maxWait);
    while (manualSearchRunning && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return !manualSearchRunning;
  }
}
