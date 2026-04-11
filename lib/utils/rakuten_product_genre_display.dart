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

  /// [prefetchedGenreName] が [genreId] と同一文字列のときは、名前として採用しない（取得失敗時のプレースホルダ除外）。
  static String resolve({
    String? apiGenreName,
    String? persistedGenreName,
    String? prefetchedGenreName,
    required String genreId,
    String? debugItemCode,
  }) {
    final id = genreId.trim();
    final apiTrim = apiGenreName?.trim() ?? '';

    if (apiTrim.isNotEmpty) {
      _log(debugItemCode, id, apiTrim, apiTrim);
      return apiTrim;
    }

    final persisted = persistedGenreName?.trim() ?? '';
    if (persisted.isNotEmpty) {
      _log(debugItemCode, id, apiTrim, persisted);
      return persisted;
    }

    final pf = prefetchedGenreName?.trim() ?? '';
    if (pf.isNotEmpty && !_isPlaceholderPrefetch(pf, id)) {
      _log(debugItemCode, id, apiTrim, pf);
      return pf;
    }

    if (id.isEmpty) {
      _log(debugItemCode, id, apiTrim, unknownLabel);
      return unknownLabel;
    }

    final known = RakutenGenreMasterService.instance.genreNameIfKnown(id);
    if (known != null && known.isNotEmpty) {
      _log(debugItemCode, id, apiTrim, known);
      return known;
    }

    _log(debugItemCode, id, apiTrim, unknownLabel);
    return unknownLabel;
  }

  static bool _isPlaceholderPrefetch(String name, String genreIdTrimmed) {
    if (genreIdTrimmed.isEmpty) return false;
    return name == genreIdTrimmed;
  }

  static void _log(
    String? itemCode,
    String genreId,
    String apiGenreNameForLog,
    String finalLabel,
  ) {
    if (!kDebugMode) return;
    final code = itemCode?.trim().isEmpty ?? true
        ? '-'
        : itemCode!.trim();
    final api = apiGenreNameForLog.isEmpty ? '-' : apiGenreNameForLog;
    final gid = genreId.isEmpty ? '-' : genreId;
    debugPrint(
      '[GenreDisplay] itemCode=$code genreId=$gid apiGenreName=$api final=$finalLabel',
    );
  }
}
