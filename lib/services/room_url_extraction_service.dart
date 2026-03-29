import '../repository/xpath_config_repository.dart';
import 'room_url_extraction_coordinator.dart';

/// 設定ファイルの XPath を用いて商品ページから URL を抽出する（WebView 実行は Coordinator 経由）。
class RoomUrlExtractionService {
  RoomUrlExtractionService._();

  static const String _defaultSelectorName = 'roomTargetUrl';

  /// [pageUrl] を読み込み、設定の XPath で最初の文字列結果を返す。
  static Future<String> extractRoomTargetUrl(String pageUrl) async {
    final sel =
        await XPathConfigRepository.loadSelectorNamed(_defaultSelectorName);
    if (sel == null) {
      throw Exception('設定に $_defaultSelectorName が見つかりません');
    }
    final t = sel.type.toLowerCase().trim();
    if (t != 'xpath' && t != 'css') {
      throw Exception('未対応のセレクタ種別です: ${sel.type}（xpath または css）');
    }
    final v = sel.value.trim();
    if (v.isEmpty) {
      throw Exception('セレクタの value が空です');
    }

    final out = await RoomUrlExtractionCoordinator.instance.extract(
      pageUrl,
      t,
      v,
      postLoadDelayMs: sel.postLoadDelayMs,
    );
    if (out == null || out.trim().isEmpty) {
      throw Exception('抽出結果が空です');
    }
    return out.trim();
  }
}
