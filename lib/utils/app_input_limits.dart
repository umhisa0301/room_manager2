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
    final minErr = validateMinPriceField(minPriceText);
    if (minErr != null) return minErr;
    final maxErr = validateMaxPriceField(
      maxPriceText,
      minPriceText: minPriceText,
    );
    if (maxErr != null) return maxErr;
    return null;
  }

  /// 任意キーワード（補助キーワード・除外ワード）。空欄可。
  static String? validateOptionalSearchKeyword(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length > searchKeywordMax) {
      return 'キーワードは$searchKeywordMax文字以内で入力してください';
    }
    return null;
  }

  /// 除外ワード（空欄可・最大50文字）。
  static String? validateExcludeKeyword(String? raw) =>
      validateOptionalSearchKeyword(raw);

  static String? validateMinPriceField(String? raw) {
    final err = validatePriceText(raw, label: '最低価格');
    if (err != null) {
      detailSearchFieldValidationLog(
        field: 'minPrice',
        valid: false,
        reason: err,
      );
    }
    return err;
  }

  static String? validateMaxPriceField(
    String? raw, {
    required String minPriceText,
  }) {
    final priceErr = validatePriceText(raw, label: '最高価格');
    if (priceErr != null) {
      detailSearchFieldValidationLog(
        field: 'maxPrice',
        valid: false,
        reason: priceErr,
      );
      return priceErr;
    }
    final minT = minPriceText.trim();
    final maxT = raw?.trim() ?? '';
    if (minT.isNotEmpty && maxT.isNotEmpty) {
      final min = int.tryParse(minT);
      final max = int.tryParse(maxT);
      if (min != null && max != null && max < min) {
        const msg = '最高価格は最低価格以上で入力してください';
        detailSearchFieldValidationLog(
          field: 'maxPrice',
          valid: false,
          reason: msg,
        );
        return msg;
      }
    }
    return null;
  }

  /// 任意の件数欄（最低コメント数など）。空欄可・最大3桁。
  static String? validateOptionalCountField(
    String? raw, {
    String label = '件数',
  }) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(t)) {
      return '$labelは数字のみで入力してください';
    }
    final n = int.tryParse(t);
    if (n == null) {
      return '$labelの形式が正しくありません';
    }
    final maxCount = int.parse('9' * countFieldMaxDigits);
    if (n > maxCount) {
      return '$labelは$maxCount以内で入力してください';
    }
    return null;
  }

  static void logApplied({
    required String screen,
    required String field,
    required int maxLength,
    String keyboardType = 'text',
    String formatter = 'default',
    String validator = 'default',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INPUT_LIMIT_APPLIED] screen=$screen field=$field '
      'maxLength=$maxLength keyboardType=$keyboardType '
      'formatter=$formatter validator=$validator',
    );
  }

  static void detailSearchFieldValidationLog({
    required String field,
    required bool valid,
    String reason = '',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[DETAIL_SEARCH_FIELD_VALIDATION] field=$field valid=$valid '
      'reason=$reason',
    );
  }

  /// 詳細検索シート内の全入力欄に適用ログを一度だけ出す。
  static void logDetailSearchSheetLimitsApplied() {
    logApplied(
      screen: 'detailSearch',
      field: 'keyword',
      maxLength: searchKeywordMax,
      formatter: 'singleLineKeyword',
      validator: 'validateSearchKeyword',
    );
    logApplied(
      screen: 'detailSearch',
      field: 'excludeKeyword',
      maxLength: searchKeywordMax,
      formatter: 'singleLineKeyword',
      validator: 'validateExcludeKeyword',
    );
    logApplied(
      screen: 'detailSearch',
      field: 'genreAuxKeyword',
      maxLength: searchKeywordMax,
      formatter: 'singleLineKeyword',
      validator: 'validateOptionalSearchKeyword',
    );
    logApplied(
      screen: 'detailSearch',
      field: 'minPrice',
      maxLength: priceMaxDigits,
      keyboardType: 'number',
      formatter: 'priceDigitsOnly',
      validator: 'validateMinPriceField',
    );
    logApplied(
      screen: 'detailSearch',
      field: 'maxPrice',
      maxLength: priceMaxDigits,
      keyboardType: 'number',
      formatter: 'priceDigitsOnly',
      validator: 'validateMaxPriceField',
    );
    logApplied(
      screen: 'detailSearch',
      field: 'minCommentCount',
      maxLength: countFieldMaxDigits,
      keyboardType: 'number',
      formatter: 'countDigits',
      validator: 'validateOptionalCountField',
    );
  }
}
