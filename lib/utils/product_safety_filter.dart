import 'package:flutter/foundation.dart';

/// 不適切商品除外の理由（ログ・テスト用）。
enum ProductSafetyBlockReason {
  adultKeyword,
  adultContext,
  blcdKeyword,
  gravureKeyword,
  underwearKeyword,
  otherAdult,
}

/// 家族向け ROOM 運用向けの商品安全フィルタ。
abstract final class ProductSafetyFilter {
  static const _adultKeywords = <String>[
    'アダルト',
    '成人向け',
    '18禁',
    'r18',
    'r-18',
    '大人のオモチャ',
    '大人のおもちゃ',
    'オトナのおもちゃ',
    'オトナのオモチャ',
    '性具',
    'バイブ',
    'ローター',
    'ディルド',
    'ラブグッズ',
    'アダルトグッズ',
    '官能',
    '濡れトロ',
    'blcd',
    'ボーイズラブ',
    'tl小説',
    'アダルトdvd',
    'グラビア',
    'ヌード',
    '下着',
    'セクシー',
    '媚薬',
    '避妊具',
    'コンドーム',
    '風俗',
    'ソープ',
    '痴女',
    '淫',
    'エロ',
    'フェチ',
    '縛り',
    'smグッズ',
    'アナル',
    'ペニス',
    'ヴァギナ',
  ];

  static const _adultContextMarkers = <String>[
    '大人',
    'オトナ',
    'otona',
    '成人',
    '18禁',
    'r18',
    'r-18',
    'アダルト',
    '官能',
    '性具',
    'ラブグッズ',
  ];

  static const _toyMarkers = <String>['おもちゃ', 'オモチャ', '玩具'];

  static const _blcdKeywords = <String>[
    'blcd',
    'ボーイズラブ',
    'boys love',
    'blコレクション',
    'ティーンズラブ',
  ];

  static final _cdDvdGenrePattern = RegExp(
    r'cd|dvd|ブルーレイ|blu-ray|音楽|映像',
    caseSensitive: false,
  );

  /// 検索・表示前に正規化するテキスト。
  static String normalizeText(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.toLowerCase();
  }

  static bool isBlockedProduct({
    String? itemName,
    String? title,
    String? itemCaption,
    String? description,
    String? shopName,
    String? genreName,
    String? itemUrl,
    String? affiliateUrl,
    String? keyword,
    String? rawText,
  }) {
    return blockedReasons(
      itemName: itemName,
      title: title,
      itemCaption: itemCaption,
      description: description,
      shopName: shopName,
      genreName: genreName,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      keyword: keyword,
      rawText: rawText,
    ).isNotEmpty;
  }

  static List<ProductSafetyBlockReason> blockedReasons({
    String? itemName,
    String? title,
    String? itemCaption,
    String? description,
    String? shopName,
    String? genreName,
    String? itemUrl,
    String? affiliateUrl,
    String? keyword,
    String? rawText,
  }) {
    final parts = <String>[
      itemName ?? '',
      title ?? '',
      itemCaption ?? '',
      description ?? '',
      shopName ?? '',
      genreName ?? '',
      itemUrl ?? '',
      affiliateUrl ?? '',
      keyword ?? '',
      rawText ?? '',
    ];
    final blob = normalizeText(parts.join(' '));
    if (blob.isEmpty) return const [];

    final reasons = <ProductSafetyBlockReason>{};

    for (final kw in _adultKeywords) {
      if (blob.contains(normalizeText(kw))) {
        reasons.add(ProductSafetyBlockReason.adultKeyword);
        break;
      }
    }

    final normalizedTitle = normalizeText(itemName ?? title ?? '');
    if (normalizedTitle.isNotEmpty && _hasAdultToyContext(normalizedTitle)) {
      reasons.add(ProductSafetyBlockReason.adultContext);
    }

    final genreNorm = normalizeText(genreName);
    final inCdDvd = genreNorm.isNotEmpty && _cdDvdGenrePattern.hasMatch(genreNorm);
    if (inCdDvd || _looksLikeCdDvdTitle(blob)) {
      for (final kw in _blcdKeywords) {
        if (blob.contains(normalizeText(kw))) {
          reasons.add(ProductSafetyBlockReason.blcdKeyword);
          break;
        }
      }
    } else {
      for (final kw in _blcdKeywords) {
        if (blob.contains(normalizeText(kw))) {
          reasons.add(ProductSafetyBlockReason.blcdKeyword);
          break;
        }
      }
    }

    if (blob.contains(normalizeText('グラビア')) ||
        blob.contains(normalizeText('ヌード'))) {
      reasons.add(ProductSafetyBlockReason.gravureKeyword);
    }

    if (_isUnderwearContext(blob)) {
      reasons.add(ProductSafetyBlockReason.underwearKeyword);
    }

    if (blob.contains(normalizeText('コスプレ')) &&
        blob.contains(normalizeText('セクシー'))) {
      reasons.add(ProductSafetyBlockReason.otherAdult);
    }

    return reasons.toList(growable: false);
  }

  static bool _hasAdultToyContext(String normalizedBlob) {
    final hasToy = _toyMarkers.any(normalizedBlob.contains);
    if (!hasToy) return false;
    return _adultContextMarkers.any(normalizedBlob.contains);
  }

  static bool _looksLikeCdDvdTitle(String blob) {
    return blob.contains('[dvd]') ||
        blob.contains('dvd]') ||
        blob.contains('blu-ray') ||
        blob.contains('ブルーレイ');
  }

  static bool _isUnderwearContext(String blob) {
    if (!blob.contains(normalizeText('下着'))) return false;
    if (blob.contains(normalizeText('ベビー')) ||
        blob.contains(normalizeText('子供')) ||
        blob.contains(normalizeText('キッズ'))) {
      return false;
    }
    return true;
  }

  static String reasonsToLogCsv(Iterable<ProductSafetyBlockReason> reasons) {
    return reasons.map((e) => e.name).join(',');
  }

  static void logFilter({
    required String source,
    required String itemCode,
    required String title,
    String shopName = '',
    String genreName = '',
    required bool blocked,
    Iterable<ProductSafetyBlockReason> reasons = const [],
    Iterable<String> matchedKeywords = const [],
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[PRODUCT_SAFETY_FILTER] source=$source itemCode=$itemCode '
      'title=${title.trim().isEmpty ? '(empty)' : title.trim()} '
      'shopName=${shopName.trim()} genreName=${genreName.trim()} '
      'blocked=$blocked reasons=${reasonsToLogCsv(reasons)}',
    );
    if (blocked && matchedKeywords.isNotEmpty) {
      debugPrint(
        '[RECOMMEND_EXCLUDE] itemCode=$itemCode reason=safetyBlocked '
        'matchedKeywords=${matchedKeywords.join(',')}',
      );
    }
  }
}
