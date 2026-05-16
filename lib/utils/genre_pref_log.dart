import 'package:flutter/foundation.dart';

import '../services/genre_master_service.dart';
import '../services/rakuten_genre_master_service.dart';

/// 好みジャンル ID の保存・参照・不一致をログする。
abstract final class GenrePrefLog {
  static void logSave({
    required String selectedGenreId,
    required String selectedGenreName,
    required String source,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_PREF_SAVE] selectedGenreId=$selectedGenreId '
      'selectedGenreName=$selectedGenreName source=$source',
    );
  }

  static void logLoad({
    required Iterable<String> favoriteGenreIds,
    required Iterable<String> favoriteGenreNames,
    required String source,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_PREF_LOAD] favoriteGenreIds=${favoriteGenreIds.join(',')} '
      'favoriteGenreNames=${favoriteGenreNames.join(',')} source=$source',
    );
  }

  static void logMismatch({
    required String savedGenreId,
    required String usedGenreId,
    required String savedName,
    required String usedName,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_PREF_MISMATCH] savedGenreId=$savedGenreId usedGenreId=$usedGenreId '
      'savedName=$savedName usedName=$usedName reason=$reason',
    );
  }

  /// ユーザーが選んだ好みジャンルと同一、またはその子孫（親方向に遡って一致）か。
  static bool isGenreAlignedWithFavorites(
    String genreId,
    Iterable<String> favoriteGenreIds,
  ) {
    final id = genreId.trim();
    if (id.isEmpty) return false;
    final fav = favoriteGenreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (fav.isEmpty) return true;
    if (fav.contains(id)) return true;

    final gms = GenreMasterService.instance;
    if (!gms.isLoaded) return false;

    var cursor = id;
    final seen = <String>{};
    while (cursor.isNotEmpty && seen.add(cursor)) {
      if (fav.contains(cursor)) return true;
      final parent = gms.getParentGenreId(cursor);
      if (parent == null || parent.trim().isEmpty) break;
      cursor = parent.trim();
    }
    return false;
  }

  /// 検索に使うジャンル ID。好みと無関係な履歴ジャンルは除外し、ログを出す。
  static String? resolveSearchGenreId({
    required String candidateGenreId,
    required Iterable<String> favoriteGenreIds,
    required String source,
  }) {
    final id = candidateGenreId.trim();
    if (id.isEmpty) return null;
    if (isGenreAlignedWithFavorites(id, favoriteGenreIds)) return id;

    final svc = RakutenGenreMasterService.instance;
    final savedId = favoriteGenreIds.isNotEmpty
        ? favoriteGenreIds.first.trim()
        : '';
    logMismatch(
      savedGenreId: savedId,
      usedGenreId: id,
      savedName: savedId.isEmpty
          ? ''
          : (svc.genreNameIfKnown(savedId) ?? savedId),
      usedName: svc.genreNameIfKnown(id) ?? id,
      reason: 'historyGenreNotInFavorites source=$source',
    );
    return null;
  }

  static List<String> filterHistoryGenresForSearch({
    required List<String> historyGenreIds,
    required Iterable<String> favoriteGenreIds,
    required String source,
  }) {
    final out = <String>[];
    for (final gid in historyGenreIds) {
      final resolved = resolveSearchGenreId(
        candidateGenreId: gid,
        favoriteGenreIds: favoriteGenreIds,
        source: source,
      );
      if (resolved != null) out.add(resolved);
    }
    return out;
  }
}
