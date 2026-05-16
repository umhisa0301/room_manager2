import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ユーザー入力の文字数・数値上限と共通バリデーション。
abstract final class AppInputLimits {
  static const int searchKeywordMax = 50;
  static const int shopNameMax = 40;
  static const int roomUrlMax = 200;
  static const int productUrlMax = 500;
  static const int priceMaxDigits = 7;
  static const int priceMaxValue = 9999999;
  static const int countFieldMaxDigits = 3;

  static List<TextInputFormatter> singleLineKeywordFormatters({
    int maxLength = searchKeywordMax,
  }) {
    return [
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.deny(RegExp(r'\n')),
    ];
  }

  static List<TextInputFormatter> urlFormatters({required int maxLength}) {
    return [LengthLimitingTextInputFormatter(maxLength)];
  }

  static List<TextInputFormatter> priceDigitsOnlyFormatters() {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(priceMaxDigits),
    ];
  }

  static List<TextInputFormatter> countDigitsFormatters() {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(countFieldMaxDigits),
    ];
  }

  static String? validateSearchKeyword(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return 'キーワードを入力してください';
    if (t.length > searchKeywordMax) {
      return 'キーワードは$searchKeywordMax文字以内で入力してください';
    }
    return null;
  }

  static String? validatePriceText(String? raw, {String label = '価格'}) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(t)) {
      return '$labelは数字のみで入力してください';
    }
    final n = int.tryParse(t);
    if (n == null) return '$labelの形式が正しくありません';
    if (n > priceMaxValue) {
      return '$labelは${priceMaxValue ~/ 10000}万円以内で入力してください';
    }
    return null;
  }

  static String? validatePriceRange({
    required String minPriceText,
    required String maxPriceText,
  }) {
    final minErr = validatePriceText(minPriceText, label: '最低価格');
    if (minErr != null) return minErr;
    final maxErr = validatePriceText(maxPriceText, label: '最高価格');
    if (maxErr != null) return maxErr;
    final minT = minPriceText.trim();
    final maxT = maxPriceText.trim();
    if (minT.isEmpty || maxT.isEmpty) return null;
    final min = int.tryParse(minT);
    final max = int.tryParse(maxT);
    if (min != null && max != null && min > max) {
      return '最低価格は最高価格以下にしてください';
    }
    return null;
  }

  static void logApplied({
    required String screen,
    required String field,
    required int maxLength,
    String keyboardType = 'text',
    String formatter = 'default',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INPUT_LIMIT_APPLIED] screen=$screen field=$field '
      'maxLength=$maxLength keyboardType=$keyboardType formatter=$formatter',
    );
  }
}
