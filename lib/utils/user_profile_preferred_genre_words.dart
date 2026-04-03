import '../models/user_profile.dart';
import '../services/rakuten_genre_master_service.dart';

/// おすすめスコアリング等で使う「好み語」の集合（プロフィール＋マスタ解決を吸収）。
abstract final class UserProfilePreferredGenreWords {
  UserProfilePreferredGenreWords._();

  static Set<String> fromProfile(UserProfile profile) {
    final out = <String>{};
    final svc = RakutenGenreMasterService.instance;
    for (final id in profile.favoriteGenreIdList) {
      final name = svc.genreDisplayName(id);
      if (name.isEmpty) continue;
      out.add(name);
      for (final part in name.split(RegExp(r'[・／/\s]+'))) {
        final p = part.trim();
        if (p.length >= 2) out.add(p);
      }
    }
    for (final raw in profile.favoriteGenres.split(RegExp(r'[,、，\s]+'))) {
      final v = raw.trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out;
  }
}
