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

  static void logInitialSetupGenreBinding({
    required List<String> selectedGenreIds,
    required List<String> selectedGenreNames,
    required String shopRecommendGenreId,
    required String shopRecommendGenreName,
    required bool matched,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INITIAL_SETUP_GENRE_BINDING] '
      'selectedGenreIds=${selectedGenreIds.join(',')} '
      'selectedGenreNames=${selectedGenreNames.join(',')} '
      'shopRecommendGenreId=$shopRecommendGenreId '
      'shopRecommendGenreName=$shopRecommendGenreName '
      'source=initialSetup matched=$matched reason=$reason',
    );
  }

  static void logInitialSetupShopRecommendGenre({
    required String genreId,
    required String genreName,
    required bool fallbackUsed,
    required String fallbackReason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INITIAL_SETUP_SHOP_RECOMMEND_GENRE] '
      'genreId=$genreId genreName=$genreName '
      'fallbackUsed=$fallbackUsed fallbackReason=$fallbackReason',
    );
  }

  static void logInitialSetupGenreTreeOpen({
    required int selectedCount,
    required int maxSelectable,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INITIAL_SETUP_GENRE_TREE_OPEN] selectedCount=$selectedCount '
      'maxSelectable=$maxSelectable',
    );
  }

  static void logInitialSetupGenreTreeSelect({
    required String genreId,
    required String genreName,
    required int depth,
    required bool selected,
    required int selectedCount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INITIAL_SETUP_GENRE_TREE_SELECT] genreId=$genreId genreName=$genreName '
      'depth=$depth selected=$selected selectedCount=$selectedCount',
    );
  }

  static void logInitialSetupGenreUiUnified({
    required bool oldPickerVisible,
    required bool treePickerVisible,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[INITIAL_SETUP_GENRE_UI_UNIFIED] oldPickerVisible=$oldPickerVisible '
      'treePickerVisible=$treePickerVisible reason=$reason',
    );
  }

  static void logGenreSearchUiUnified({
    required bool oldGenreAreaVisible,
    required bool drilldownGenreAreaVisible,
    required String label,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_SEARCH_UI_UNIFIED] oldGenreAreaVisible=$oldGenreAreaVisible '
      'drilldownGenreAreaVisible=$drilldownGenreAreaVisible label=$label',
    );
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
