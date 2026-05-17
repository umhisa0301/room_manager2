import 'package:flutter/foundation.dart';

/// ダイアログ・SnackBar 向けの表示用テキスト整形。
abstract final class DisplayTextUtils {
  static const int defaultProductNameMaxLength = 36;

  static String truncateProductName(
    String? raw, {
    int maxLength = defaultProductNameMaxLength,
    String type = 'productName',
  }) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return '（商品名なし）';
    if (text.length <= maxLength) {
      _logTruncate(type: type, originalLength: text.length, maxLength: maxLength, truncated: false);
      return text;
    }
    final out = '${text.substring(0, maxLength)}…';
    _logTruncate(type: type, originalLength: text.length, maxLength: maxLength, truncated: true);
    return out;
  }

  static void _logTruncate({
    required String type,
    required int originalLength,
    required int maxLength,
    required bool truncated,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[DISPLAY_TEXT_TRUNCATE] type=$type originalLength=$originalLength '
      'maxLength=$maxLength truncated=$truncated',
    );
  }
}
