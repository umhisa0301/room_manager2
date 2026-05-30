import '../models/user_profile.dart';
import '../services/rakuten_genre_master_service.dart';
import 'favorite_genre_selection_policy.dart';
import 'genre_pref_log.dart';

/// 好みジャンル ID と表示名の整合（保存・読込）を担う。
abstract final class FavoriteGenrePref {
  static String resolveGenreNameForId(String genreId) {
    final id = genreId.trim();
    if (id.isEmpty) return '';
    return RakutenGenreMasterService.instance.getGenreNameById(id);
  }

  /// [genreIds] ごとにマスタから正式名称を解決し、ID と同数の名前リストを返す。
  static List<String> resolveGenreNamesForIds(Iterable<String> genreIds) {
    return genreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(resolveGenreNameForId)
        .toList(growable: false);
  }

  /// 保存用 [UserProfile] を組み立て（ID と名前は常に同数・同順）。
  static UserProfile profileWithFavoriteGenres({
    required UserProfile base,
    required List<String> genreIds,
    String source = 'unknown',
    Iterable<String>? inputGenreNames,
  }) {
    final idList = genreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(FavoriteGenreSelectionPolicy.maxSelectable)
        .toList(growable: false);
    final inputNames = inputGenreNames?.toList() ?? const <String>[];
    final names = <String>[];
    final invalidIds = <String>[];

    for (var i = 0; i < idList.length; i++) {
      final id = idList[i];
      final resolved = resolveGenreNameForId(id);
      final inputName = i < inputNames.length ? inputNames[i].trim() : '';
      final unknown =
          resolved.isEmpty ||
          resolved == RakutenGenreMasterService.unknownGenreDisplayLabel;
      if (unknown) invalidIds.add(id);
      final storedName = unknown
          ? (inputName.isNotEmpty
                ? inputName
                : RakutenGenreMasterService.unknownGenreDisplayLabel)
          : resolved;
      final nameCorrected =
          inputName.isNotEmpty && inputName != storedName;
      if (nameCorrected) {
        GenrePrefLog.logIdNameMismatchFixed(
          genreId: id,
          oldName: inputName,
          newName: storedName,
          source: source,
        );
      }
      GenrePrefLog.logSaveNormalized(
        genreId: id,
        inputGenreName: inputName,
        resolvedGenreName: storedName,
        nameCorrected: nameCorrected,
        source: source,
      );
      names.add(storedName);
    }

    GenrePrefLog.logSaveSummary(
      genreIds: idList,
      genreNames: names,
      source: source,
    );

    return UserProfile(
      displayName: base.displayName,
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: names.join('、'),
      favoriteGenreIds: idList.join('、'),
      postStyles: base.postStyles,
      roomUrl: base.roomUrl,
    );
  }

  /// 読込時に ID を正として名前を再構築。ズレがあれば補正済みプロフィールを返す。
  static ({UserProfile profile, bool corrected}) normalizeLoadedProfile(
    UserProfile profile, {
    String source = 'load',
  }) {
    final idList = profile.favoriteGenreIdList;
    if (idList.isEmpty) {
      GenrePrefLog.logLoad(
        favoriteGenreIds: const [],
        favoriteGenreNames: const [],
        source: source,
      );
      return (profile: profile, corrected: false);
    }

    final resolvedNames = resolveGenreNamesForIds(idList);
    final storedNames = profile.favoriteGenreList;
    final invalidIds = <String>[];
    for (var i = 0; i < idList.length; i++) {
      final resolved = i < resolvedNames.length ? resolvedNames[i] : '';
      if (resolved.isEmpty ||
          resolved == RakutenGenreMasterService.unknownGenreDisplayLabel) {
        invalidIds.add(idList[i]);
      }
    }

    var corrected = false;
    if (resolvedNames.length != storedNames.length) {
      corrected = true;
    } else {
      for (var i = 0; i < resolvedNames.length; i++) {
        if (resolvedNames[i] != storedNames[i]) {
          corrected = true;
          if (storedNames[i].isNotEmpty) {
            GenrePrefLog.logIdNameMismatchFixed(
              genreId: idList[i],
              oldName: storedNames[i],
              newName: resolvedNames[i],
              source: source,
            );
          }
        }
      }
    }

    GenrePrefLog.logLoadNormalized(
      favoriteGenreIds: idList,
      resolvedGenreNames: resolvedNames,
      invalidGenreIds: invalidIds,
      corrected: corrected,
    );
    GenrePrefLog.logLoad(
      favoriteGenreIds: idList,
      favoriteGenreNames: corrected ? resolvedNames : storedNames,
      source: source,
    );

    if (!corrected) {
      return (profile: profile, corrected: false);
    }

    final next = UserProfile(
      displayName: profile.displayName,
      age: profile.age,
      genderKey: profile.genderKey,
      occupation: profile.occupation,
      favoriteGenres: resolvedNames.join('、'),
      favoriteGenreIds: idList.join('、'),
      postStyles: profile.postStyles,
      roomUrl: profile.roomUrl,
    );
    return (profile: next, corrected: true);
  }
}
