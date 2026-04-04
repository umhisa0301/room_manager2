/// 非表示 WebView ホストと抽出処理をつなぐ薄いコーディネータ。
class RoomUrlExtractionCoordinator {
  RoomUrlExtractionCoordinator._();

  static final RoomUrlExtractionCoordinator instance =
      RoomUrlExtractionCoordinator._();

  Future<String?> Function(
    String url,
    String selectorType,
    String selectorValue,
    int postLoadDelayMs,
  )?
  _runner;

  bool _ready = false;

  bool get isReady => _ready;

  void attach(
    Future<String?> Function(
      String url,
      String selectorType,
      String selectorValue,
      int postLoadDelayMs,
    )
    runner,
  ) {
    _runner = runner;
    _ready = true;
  }

  void detach() {
    _runner = null;
    _ready = false;
  }

  /// [selectorType]: `xpath` または `css`。[postLoadDelayMs] は読み込み完了後の待機。
  Future<String?> extract(
    String pageUrl,
    String selectorType,
    String selectorValue, {
    int postLoadDelayMs = 0,
  }) async {
    final r = _runner;
    if (r == null) {
      throw StateError('URL抽出用WebViewが未初期化です');
    }
    return r(pageUrl, selectorType, selectorValue, postLoadDelayMs);
  }
}
