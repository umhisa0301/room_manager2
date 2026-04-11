import 'package:flutter/foundation.dart';

import '../services/rakuten_genre_master_service.dart';

/// 商品一覧・検索結果向けのジャンル表示名（UI とロジックの境界）。
///
/// 優先順位:
/// 1. API レスポンス由来の `apiGenreName`
/// 2. 永続化済みの `persistedGenreName`（ROOMコレ保存時など）
/// 3. 非同期キャッシュ解決後の `prefetchedGenreName`（ジャンルAPI/SPキャッシュ）
/// 4. ローカル定数マスタ（[RakutenGenreMasterService]）
/// 5. 上記いずれも無い場合のみ [RakutenGenreMasterService.unknownGenreDisplayLabel]
class RakutenProductGenreDisplay {
  RakutenProductGenreDisplay._();

  static const String unknownLabel = RakutenGenreMasterService.unknownGenreDisplayLabel;

  /// ログ過多防止（1セッションあたりの [RakutenGenre][UI]/[MASTER] 出力上限）。
  static int _rakutenGenreTraceBudget = 80;

  /// [prefetchedGenreName] が [genreId] と同一文字列のときは、名前として採用しない（取得失敗時のプレースホルダ除外）。
  static String resolve({
    String? apiGenreName,
    String? persistedGenreName,
    String? prefetchedGenreName,
    required String genreId,
    String? traceItemCode,
  }) {
    final id = genreId.trim();
    final apiTrim = apiGenreName?.trim() ?? '';

    late final String result;
    if (apiTrim.isNotEmpty) {
      result = apiTrim;
    } else {
      final persisted = persistedGenreName?.trim() ?? '';
      if (persisted.isNotEmpty) {
        result = persisted;
      } else {
        final pf = prefetchedGenreName?.trim() ?? '';
        if (pf.isNotEmpty && !_isPlaceholderPrefetch(pf, id)) {
          result = pf;
        } else if (id.isEmpty) {
          result = unknownLabel;
        } else {
          final known = RakutenGenreMasterService.instance.genreNameIfKnown(id);
          if (known != null && known.isNotEmpty) {
            result = known;
          } else {
            result = unknownLabel;
          }
        }
      }
    }

    _traceRakutenGenreIfNeeded(
      traceItemCode: traceItemCode,
      genreId: genreId,
      apiGenreName: apiGenreName,
      persistedGenreName: persistedGenreName,
      prefetchedGenreName: prefetchedGenreName,
      finalLabel: result,
    );
    return result;
  }

  static void _traceRakutenGenreIfNeeded({
    required String? traceItemCode,
    required String genreId,
    required String? apiGenreName,
    required String? persistedGenreName,
    required String? prefetchedGenreName,
    required String finalLabel,
  }) {
    if (!kDebugMode || traceItemCode == null || _rakutenGenreTraceBudget <= 0) {
      return;
    }
    _rakutenGenreTraceBudget--;
    final code = traceItemCode.trim().isEmpty ? '-' : traceItemCode.trim();
    final api = apiGenreName?.trim() ?? '';
    final persisted = persistedGenreName?.trim() ?? '';
    final pf = prefetchedGenreName?.trim() ?? '';
    final uiGenreName = api.isNotEmpty
        ? api
        : (persisted.isNotEmpty
              ? persisted
              : (pf.isNotEmpty ? pf : '-'));
    debugPrint(
      '[RakutenGenre][UI] itemCode=$code ui.genreId=${genreId.trim()} '
      'ui.genreName=$uiGenreName ui.label=$finalLabel',
    );
    final gid = genreId.trim();
    if (gid.isEmpty) {
      debugPrint(
        '[RakutenGenre][MASTER] itemCode=$code genreId=- masterHit=false '
        'resolvedGenreName=-',
      );
      return;
    }
    final known = RakutenGenreMasterService.instance.genreNameIfKnown(gid);
    final hit = known != null && known.isNotEmpty;
    debugPrint(
      '[RakutenGenre][MASTER] itemCode=$code genreId=$gid masterHit=$hit '
      'resolvedGenreName=${hit ? known : '-'}',
    );
  }

  /// 開発時: [itemCode] / [genreId] / API 名 / 最終表示を1行で出す（本番では呼ばない想定）。
  static void debugLogResolution({
    required String itemCode,
    required String genreId,
    String? apiGenreName,
    required String finalLabel,
  }) {
    if (!kDebugMode) return;
    final c = itemCode.trim().isEmpty ? '-' : itemCode.trim();
    final g = genreId.trim().isEmpty ? '-' : genreId.trim();
    final api = (apiGenreName?.trim().isEmpty ?? true)
        ? '-'
        : apiGenreName!.trim();
    debugPrint(
      '[GenreDisplay] itemCode=$c genreId=$g apiGenreName=$api final=$finalLabel',
    );
  }

  static bool _isPlaceholderPrefetch(String name, String genreIdTrimmed) {
    if (genreIdTrimmed.isEmpty) return false;
    return name == genreIdTrimmed;
  }
}
