/// 非表示 WebView ホストと抽出処理をつなぐ薄いコーディネータ。
class RoomUrlExtractionCoordinator {
  RoomUrlExtractionCoordinator._();

  static final RoomUrlExtractionCoordinator instance =
      RoomUrlExtractionCoordinator._();

  Future<String?> Function(String url, String xpath)? _runner;
  bool _ready = false;

  bool get isReady => _ready;

  void attach(Future<String?> Function(String url, String xpath) runner) {
    _runner = runner;
    _ready = true;
  }

  void detach() {
    _runner = null;
    _ready = false;
  }

  Future<String?> extractWithXPath(String pageUrl, String xpath) async {
    final r = _runner;
    if (r == null) {
      throw StateError('URL抽出用WebViewが未初期化です');
    }
    return r(pageUrl, xpath);
  }
}
