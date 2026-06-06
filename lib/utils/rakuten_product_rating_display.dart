import 'package:flutter/foundation.dart';

/// 楽天商品のレビュー平均・件数を UI 向け文言に整形する。
abstract final class RakutenProductRatingDisplay {
  const RakutenProductRatingDisplay._();

  /// 管理商品カードの評価行向け（「評価未取得」等）。
  static String formatProductCardLabel({
    required double reviewAverage,
    required int reviewCount,
  }) {
    final avg = reviewAverage;
    final cnt = reviewCount;
    if (avg > 0 && cnt > 0) {
      return '評価 ★${_formatAverage(avg)}（$cnt件）';
    }
    if (avg > 0) {
      return '評価 ★${_formatAverage(avg)}';
    }
    if (cnt > 0) {
      return 'レビュー$cnt件';
    }
    return '評価未取得';
  }

  static String _formatAverage(double avg) => avg.toStringAsFixed(1);

  static void traceLog({
    required String source,
    required String productId,
    required double reviewAverage,
    required int reviewCount,
    required String displayText,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[RATING_DISPLAY_TRACE] source=$source productId=${productId.trim()} '
      'reviewAverage=$reviewAverage reviewCount=$reviewCount '
      'displayText=$displayText',
    );
  }
}
