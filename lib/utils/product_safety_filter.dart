import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import 'app_debug_log.dart';

/// 不適切商品除外の理由（ログ・テスト用）。
enum ProductSafetyBlockReason {
  adultKeyword,
  adultContext,
  blcdKeyword,
  gravureKeyword,
  underwearKeyword,
  otherAdult,
  alcoholKeyword,
  tobaccoKeyword,
  gamblingKeyword,
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

  static const _alcoholGenreMarkers = <String>[
    'ビール',
    '洋酒',
    '日本酒',
    '焼酎',
    'ワイン',
    'シャンパン',
    'ウイスキー',
    'ブランデー',
    'リキュール',
    'チューハイ',
    'カクテル',
    'アルコール',
    'お酒',
    '酒類',
  ];

  static const _alcoholTitleKeywords = <String>[
    'ビール',
    '発泡酒',
    'ワイン',
    'シャンパン',
    '日本酒',
    '焼酎',
    'ウイスキー',
    'ブランデー',
    'リキュール',
    'チューハイ',
    'カクテル',
    'ノンアルコールビール',
    '純米',
    '大吟醸',
    '辛口',
    'ドリンク缶',
  ];

  static const _alcoholAccessoryMarkers = <String>[
    'グラス',
    '酒器',
    'デキャンタ',
    '栓抜き',
    'クーラー',
    'コルク',
  ];

  static const _tobaccoKeywords = <String>[
    'タバコ',
    'たばこ',
    '煙草',
    '電子タバコ',
    'vape',
    'ベイプ',
    '加熱式',
    'iqos',
    'アイコス',
    'glo',
    'グロー',
    'ploom',
    'プルーム',
    'シガー',
    '葉巻',
    '喫煙',
  ];

  static const _gamblingKeywords = <String>[
    'パチンコ',
    'パチスロ',
    'スロット',
    '競馬',
    '競艇',
    '競輪',
    '宝くじ',
    'ロト',
    'toto',
    'カジノ',
    '麻雀賭',
    '賭博',
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
    final normalizedTitle = normalizeText(itemName ?? title ?? '');
    final genreNorm = normalizeText(genreName);

    for (final kw in _adultKeywords) {
      if (blob.contains(normalizeText(kw))) {
        reasons.add(ProductSafetyBlockReason.adultKeyword);
        break;
      }
    }

    if (normalizedTitle.isNotEmpty && _hasAdultToyContext(normalizedTitle)) {
      reasons.add(ProductSafetyBlockReason.adultContext);
    }

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

    if (_isAlcoholProduct(
      blob: blob,
      genreNorm: genreNorm,
      titleNorm: normalizedTitle,
    )) {
      reasons.add(ProductSafetyBlockReason.alcoholKeyword);
    }

    for (final kw in _tobaccoKeywords) {
      if (blob.contains(normalizeText(kw))) {
        reasons.add(ProductSafetyBlockReason.tobaccoKeyword);
        break;
      }
    }

    for (final kw in _gamblingKeywords) {
      if (blob.contains(normalizeText(kw))) {
        reasons.add(ProductSafetyBlockReason.gamblingKeyword);
        break;
      }
    }

    return reasons.toList(growable: false);
  }

  static bool _isAlcoholProduct({
    required String blob,
    required String genreNorm,
    required String titleNorm,
  }) {
    for (final m in _alcoholGenreMarkers) {
      if (genreNorm.contains(normalizeText(m))) return true;
    }
    if (_isAlcoholAccessoryTitle(titleNorm)) return false;
    for (final kw in _alcoholTitleKeywords) {
      if (titleNorm.contains(normalizeText(kw)) ||
          blob.contains(normalizeText(kw))) {
        return true;
      }
    }
    return false;
  }

  static bool _isAlcoholAccessoryTitle(String titleNorm) {
    if (titleNorm.isEmpty) return false;
    final hasAccessory = _alcoholAccessoryMarkers.any(titleNorm.contains);
    if (!hasAccessory) return false;
    const productIndicators = [
      '本セット',
      '缶',
      '瓶',
      'ml',
      '度数',
      '純米',
      '大吟醸',
      '辛口',
      'ケース',
      '飲み切り',
      '飲料',
    ];
    if (productIndicators.any(titleNorm.contains)) return false;
    return true;
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

  static String primaryLogReason(Iterable<ProductSafetyBlockReason> reasons) {
    if (reasons.isEmpty) return 'none';
    if (reasons.contains(ProductSafetyBlockReason.alcoholKeyword)) {
      return 'alcohol';
    }
    if (reasons.any((r) =>
        r == ProductSafetyBlockReason.adultKeyword ||
        r == ProductSafetyBlockReason.adultContext ||
        r == ProductSafetyBlockReason.blcdKeyword ||
        r == ProductSafetyBlockReason.gravureKeyword ||
        r == ProductSafetyBlockReason.underwearKeyword ||
        r == ProductSafetyBlockReason.otherAdult)) {
      return 'adult';
    }
    if (reasons.contains(ProductSafetyBlockReason.tobaccoKeyword)) {
      return 'tobacco';
    }
    if (reasons.contains(ProductSafetyBlockReason.gamblingKeyword)) {
      return 'gambling';
    }
    return 'adult';
  }

  static String reasonsToLogCsv(Iterable<ProductSafetyBlockReason> reasons) {
    return reasons.map((e) => e.name).join(',');
  }

  static String? _batchSource;
  static int _batchTotal = 0;
  static int _batchBlocked = 0;
  static final Map<String, int> _batchReasonBreakdown = <String, int>{};
  static final List<String> _batchBlockedExamples = <String>[];

  /// 検索1回分の集計ログ用。検索開始時に呼ぶ。
  static void beginBatch(String source) {
    _batchSource = source;
    _batchTotal = 0;
    _batchBlocked = 0;
    _batchReasonBreakdown.clear();
    _batchBlockedExamples.clear();
  }

  /// 検索完了後に1行サマリを出す（通常デバッグ）。
  static void endBatch() {
    if (!kDebugMode || _batchSource == null) return;
    final examples = _batchBlockedExamples.take(3).join(' | ');
    debugSummaryLog(
      '[PRODUCT_SAFETY_FILTER] source=$_batchSource totalItems=$_batchTotal '
      'blockedCount=$_batchBlocked '
      'reasonBreakdown=${_batchReasonBreakdown.entries.map((e) => '${e.key}:${e.value}').join(',')} '
      'firstBlockedExamples=${examples.isEmpty ? '-' : examples}',
    );
    _batchSource = null;
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
    final reasonTag = primaryLogReason(reasons);
    if (_batchSource != null && source == _batchSource) {
      _batchTotal++;
      if (blocked) {
        _batchBlocked++;
        _batchReasonBreakdown[reasonTag] =
            (_batchReasonBreakdown[reasonTag] ?? 0) + 1;
        if (_batchBlockedExamples.length < 3) {
          final t = title.trim().isEmpty ? '(empty)' : title.trim();
          _batchBlockedExamples.add('$itemCode:$t:$reasonTag');
        }
      }
    }
    if (!DebugLogFlags.kVerboseItemLogsEnabled) return;
    verboseItemLog(
      '[PRODUCT_SAFETY_FILTER] source=$source itemCode=$itemCode '
      'title=${title.trim().isEmpty ? '(empty)' : title.trim()} '
      'genreName=${genreName.trim()} shopName=${shopName.trim()} '
      'blocked=$blocked reason=$reasonTag',
    );
    if (blocked) {
      verboseItemLog(
        '[RECOMMEND_EXCLUDE] reason=safetyBlocked blockReason=$reasonTag '
        'itemCode=$itemCode matchedKeywords=${matchedKeywords.join(',')}',
      );
    }
  }
}
