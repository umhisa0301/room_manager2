import 'package:flutter/foundation.dart';

import '../services/rakuten_genre_master_service.dart';

/// 画面表示用のジャンル名解決（genreId をユーザーに出さない）。
abstract final class GenreDisplayResolve {
  static const String fallbackLabel = 'ジャンル未確認';

  static String labelForGenreId(
    String? genreId, {
    required String screen,
    String? inputLabel,
  }) {
    final id = genreId?.trim() ?? '';
    if (id.isEmpty) {
      _log(
        screen: screen,
        genreId: id,
        resolvedGenreName: '',
        shownLabel: fallbackLabel,
        fallbackUsed: true,
      );
      return fallbackLabel;
    }

    final resolved = RakutenGenreMasterService.instance.getGenreNameById(id);
    final unknown =
        resolved.isEmpty ||
        resolved == RakutenGenreMasterService.unknownGenreDisplayLabel;
    final shown = unknown ? fallbackLabel : resolved;
    final fallbackUsed = unknown;
    _log(
      screen: screen,
      genreId: id,
      resolvedGenreName: resolved,
      shownLabel: shown,
      fallbackUsed: fallbackUsed,
    );
    if (kDebugMode &&
        inputLabel != null &&
        inputLabel.trim().isNotEmpty &&
        inputLabel.trim() != shown &&
        !unknown) {
      debugPrint(
        '[GENRE_DISPLAY_INPUT_MISMATCH] screen=$screen genreId=$id '
        'inputLabel=$inputLabel resolved=$resolved',
      );
    }
    return shown;
  }

  /// 検索見出し向け（例: キッズファッションで探す）。
  static String searchHeadlineForGenreId(String? genreId, {required String screen}) {
    final name = labelForGenreId(genreId, screen: screen);
    if (name == fallbackLabel) return 'ジャンルから探す';
    return '$nameで探す';
  }

  /// 折りたたみヘッダー向け（例: ジャンルから探す：キッズファッション）。
  static String collapsedTitleForGenreId(String? genreId, {required String screen}) {
    final name = labelForGenreId(genreId, screen: screen);
    if (name == fallbackLabel) return 'ジャンルから探す';
    return 'ジャンルから探す：$name';
  }

  static void _log({
    required String screen,
    required String genreId,
    required String resolvedGenreName,
    required String shownLabel,
    required bool fallbackUsed,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_DISPLAY_RESOLVE] screen=$screen genreId=$genreId '
      'resolvedGenreName=$resolvedGenreName shownLabel=$shownLabel '
      'fallbackUsed=$fallbackUsed',
    );
  }
}
