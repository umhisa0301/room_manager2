import 'package:flutter/foundation.dart';

import '../repository/xpath_config_repository.dart';
import 'room_url_extraction_coordinator.dart';

/// 設定ファイルの XPath を用いて商品ページから URL を抽出する（WebView 実行は Coordinator 経由）。
class RoomUrlExtractionService {
  RoomUrlExtractionService._();

  static const String _defaultSelectorName = 'roomTargetUrl';

  /// [pageUrl] を読み込み、設定の XPath で最初の文字列結果を返す。
  static const String _logTag = '[RoomUrlExtraction]';

  static Future<String> extractRoomTargetUrl(String pageUrl) async {
    final sel =
        await XPathConfigRepository.loadSelectorNamed(_defaultSelectorName);
    if (sel == null) {
      debugPrint(
        '$_logTag 失敗 [設定] assets の selectors に '
        '"$_defaultSelectorName" がありません',
      );
      throw Exception('設定に $_defaultSelectorName が見つかりません');
    }
    final t = sel.type.toLowerCase().trim();
    if (t != 'xpath' && t != 'css') {
      debugPrint(
        '$_logTag 失敗 [設定] type は xpath か css である必要があります: ${sel.type}',
      );
      throw Exception('未対応のセレクタ種別です: ${sel.type}（xpath または css）');
    }
    final v = sel.value.trim();
    if (v.isEmpty) {
      debugPrint('$_logTag 失敗 [設定] value が空です (name=$_defaultSelectorName)');
      throw Exception('セレクタの value が空です');
    }

    final String? out;
    try {
      out = await RoomUrlExtractionCoordinator.instance.extract(
        pageUrl,
        t,
        v,
        postLoadDelayMs: sel.postLoadDelayMs,
      );
    } on StateError catch (e) {
      debugPrint(
        '$_logTag 失敗 [Coordinator] RoomUrlExtractionHost がツリーに無い、'
        'または未 attach です: $e',
      );
      rethrow;
    }
    if (out == null || out.trim().isEmpty) {
      debugPrint(
        '$_logTag 失敗 [結果] WebView から null/空文字が返りました '
        '(pageUrl=${pageUrl.length > 120 ? '${pageUrl.substring(0, 120)}…' : pageUrl})',
      );
      throw Exception('抽出結果が空です');
    }
    return out.trim();
  }
}
