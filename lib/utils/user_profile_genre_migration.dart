import '../models/rakuten_genre_master_entry.dart';
import '../services/rakuten_genre_master_service.dart';

/// 旧プロフィール（フリーテキストの `favoriteGenres`）から genreId 候補を推定する。
abstract final class UserProfileGenreMigration {
  UserProfileGenreMigration._();

  static List<String> idsFromLegacyFavoriteGenresText(
    String raw, {
    int maxCount = 5,
  }) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    final svc = RakutenGenreMasterService.instance;
    final all = svc.getAllGenres();
    final byName = <String, String>{};
    for (final e in all) {
      byName[e.genreName.trim()] = e.genreId.trim();
    }
    final out = <String>[];
    final seen = <String>{};
    for (final token in t.split(RegExp(r'[、,\n]+'))) {
      if (out.length >= maxCount) break;
      final text = token.trim();
      if (text.isEmpty) continue;
      String? id;
      if (RegExp(r'^[0-9]+$').hasMatch(text)) {
        id = text;
        final name = svc.genreNameIfKnown(id);
        if (name == null) continue;
      } else {
        id = byName[text];
        id ??= _matchByPartialName(text, all);
      }
      if (id != null && id.isNotEmpty && seen.add(id)) {
        out.add(id);
      }
    }
    return out;
  }

  static String? _matchByPartialName(
    String token,
    List<RakutenGenreMasterEntry> all,
  ) {
    final t = token.trim();
    if (t.isEmpty) return null;
    RakutenGenreMasterEntry? hit;
    for (final e in all) {
      if (e.genreName.contains(t)) {
        if (hit != null) return null;
        hit = e;
      }
    }
    return hit?.genreId.trim();
  }
}
