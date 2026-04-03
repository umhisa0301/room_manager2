import 'package:flutter/services.dart';

/// キーワード検索の詳細条件フィールド向け [TextInputFormatter]。
abstract final class RakutenKeywordDetailConditionsInput {
  RakutenKeywordDetailConditionsInput._();

  /// 価格・件数など非負整数（半角数字のみ）。
  static final List<TextInputFormatter> digitsOnlyField = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  /// 最低評価点数（数字と小数点のみ。桁数で入力過多を抑止）。
  static final List<TextInputFormatter> reviewAverageField = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    LengthLimitingTextInputFormatter(4),
  ];
}

/// キーワード検索タブの詳細条件（ボトムシート内の数値項目）の入力検証。
/// UI・[RakutenProductSearchCondition] 組み立てから独立させ、null/空文字/型変換を安全に扱う。
abstract final class RakutenKeywordDetailConditionsValidation {
  RakutenKeywordDetailConditionsValidation._();

  /// キーワード検索タブの「最低評価数」選択肢（未選択は空文字）。
  static const List<int> keywordMinReviewCountChoices = [
    10,
    50,
    100,
    500,
    1000,
  ];

  /// キーワード検索タブの「最低評価点数」選択肢（未選択は空文字）。
  static const List<double> keywordMinReviewAverageChoices = [
    3.0,
    3.5,
    4.0,
    4.5,
  ];

  /// 楽天商品検索APIに無理のない価格上限（円）。超過はエラー。
  static const int maxPriceYen = 999999999;

  /// 評価数・コメント数などの上限（現実的な範囲）。
  static const int maxCountThreshold = 9999999;

  static const double minReviewAverageBound = 0.0;

  /// 楽天レビューは一般に5点満想定。
  static const double maxReviewAverageBound = 5.0;

  /// すべて問題なければ null。最初に見つかったエラー文言を返す。
  static String? validateAll({
    required String minPriceText,
    required String maxPriceText,
    required String minReviewCountText,
    required String minReviewAverageText,
    required String minCommentCountText,
  }) {
    final minPriceErr = validateOptionalNonNegativeIntField(
      fieldLabel: '最低価格',
      raw: minPriceText,
      maxInclusive: maxPriceYen,
    );
    if (minPriceErr != null) return minPriceErr;

    final maxPriceErr = validateOptionalNonNegativeIntField(
      fieldLabel: '最高価格',
      raw: maxPriceText,
      maxInclusive: maxPriceYen,
    );
    if (maxPriceErr != null) return maxPriceErr;

    final minP = parseOptionalNonNegativeInt(minPriceText);
    final maxP = parseOptionalNonNegativeInt(maxPriceText);
    if (minP != null && maxP != null && minP > maxP) {
      return '最低価格は最高価格以下にしてください。';
    }

    final reviewCountErr = validateKeywordTabMinReviewCount(minReviewCountText);
    if (reviewCountErr != null) return reviewCountErr;

    final commentErr = validateOptionalNonNegativeIntField(
      fieldLabel: '最低コメント数',
      raw: minCommentCountText,
      maxInclusive: maxCountThreshold,
    );
    if (commentErr != null) return commentErr;

    return validateKeywordTabMinReviewAverage(minReviewAverageText);
  }

  /// 空は未指定。非空は [keywordMinReviewCountChoices] のいずれかのみ。
  static String? validateKeywordTabMinReviewCount(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null) {
      return '最低評価数は一覧から選び直してください（未選択は指定なし）。';
    }
    if (!keywordMinReviewCountChoices.contains(v)) {
      return '最低評価数は一覧のいずれかを選んでください。';
    }
    return null;
  }

  /// 空は未指定。非空は [keywordMinReviewAverageChoices] のいずれかのみ。
  static String? validateKeywordTabMinReviewAverage(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) {
      return '最低評価点数は一覧から選び直してください（未選択は指定なし）。';
    }
    for (final a in keywordMinReviewAverageChoices) {
      if ((v - a).abs() < 0.001) return null;
    }
    return '最低評価点数は一覧のいずれかを選んでください。';
  }

  /// 空・空白のみは null（未指定）。非空で整数化できなければエラー。
  static String? validateOptionalNonNegativeIntField({
    required String fieldLabel,
    required String raw,
    required int maxInclusive,
  }) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null) {
      return '$fieldLabelは半角数字の整数で入力してください（空欄は指定なし）。';
    }
    if (v < 0) {
      return '$fieldLabelは0以上で入力してください。';
    }
    if (v > maxInclusive) {
      return '$fieldLabelは$maxInclusive以下で入力してください。';
    }
    return null;
  }

  static String? validateOptionalReviewAverage(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) {
      return '最低評価点数は数値で入力してください（例: 4.0）。空欄は指定なし。';
    }
    if (v.isNaN || v.isInfinite) {
      return '最低評価点数が不正です。0〜5の範囲で入力してください。';
    }
    if (v < minReviewAverageBound || v > maxReviewAverageBound) {
      return '最低評価点数は'
          '${minReviewAverageBound.toStringAsFixed(1)}〜'
          '${maxReviewAverageBound.toStringAsFixed(1)}の範囲で入力してください。';
    }
    return null;
  }

  /// 検証済み前提のパース用途（キーワード検索以外でも利用可）。空は null。
  static int? parseOptionalNonNegativeInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
}
