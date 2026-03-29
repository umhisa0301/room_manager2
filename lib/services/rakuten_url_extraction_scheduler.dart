/// コレ候補登録後に URL 抽出ジョブをキューする（ホスト Widget が実処理）。
abstract class RakutenUrlExtractionScheduler {
  void scheduleExtraction(String productId, String pageUrl);
}

class RakutenUrlExtractionSchedulerImpl implements RakutenUrlExtractionScheduler {
  void Function(String productId, String pageUrl)? _handler;

  void registerHandler(void Function(String productId, String pageUrl) handler) {
    _handler = handler;
  }

  @override
  void scheduleExtraction(String productId, String pageUrl) {
    final id = productId.trim();
    final url = pageUrl.trim();
    if (id.isEmpty || url.isEmpty) return;
    _handler?.call(id, url);
  }
}
