import 'package:flutter/foundation.dart';

import '../models/rakuten_genre_master_entry.dart';

/// トップジャンル（ルート）の UI 表示順。
///
/// genreId ベースで安定した並びを提供する。保存済み genreId には影響しない。
abstract final class GenreDisplayOrder {
  /// ユーザーが選びやすい順（genreId ベース）。
  static const List<String> preferredRootGenreIds = [
    '100371', // レディースファッション
    '551177', // メンズファッション
    '100533', // キッズ・ベビー・マタニティ
    '216131', // バッグ・小物・ブランド雑貨
    '558885', // 靴
    '100433', // インナー・下着・ナイトウェア
    '100939', // 美容・コスメ・香水
    '100938', // ダイエット・健康
    '100227', // 食品
    '100316', // 水・ソフトドリンク
    '551167', // スイーツ・お菓子
    '215783', // 日用品雑貨・文房具・手芸
    '558944', // キッチン用品・食器・調理器具
    '100804', // インテリア・寝具・収納
    '562637', // 家電
    '211742', // TV・オーディオ・カメラ
    '100026', // パソコン・周辺機器
    '564500', // スマートフォン・タブレット
    '566382', // おもちゃ
    '101164', // ホビー
    '101070', // スポーツ・アウトドア
    '101213', // ペット・ペットグッズ
    '100005', // 花・ガーデン・DIY
    '503190', // 車用品・バイク用品
    '200162', // 本・雑誌・コミック
    '101240', // CD・DVD
    '101205', // テレビゲーム
    '100000', // 百貨店・総合通販・ギフト
  ];

  static const int _unknownRankBase = 100000;

  static final Map<String, int> _rankByGenreId = {
    for (var i = 0; i < preferredRootGenreIds.length; i++)
      preferredRootGenreIds[i]: i,
  };

  static int _rank(String genreId) =>
      _rankByGenreId[genreId.trim()] ?? _unknownRankBase;

  /// ルートジャンル向けの比較。未登録 ID は末尾で名称昇順。
  static int compareGenreIds(
    String a,
    String b, {
    String? nameA,
    String? nameB,
  }) {
    final ra = _rank(a);
    final rb = _rank(b);
    if (ra != rb) return ra.compareTo(rb);
    if (ra >= _unknownRankBase) {
      final na = (nameA ?? a).trim();
      final nb = (nameB ?? b).trim();
      final byName = na.compareTo(nb);
      if (byName != 0) return byName;
    }
    return a.trim().compareTo(b.trim());
  }

  static void sortGenreIds(
    List<String> ids, {
    String? Function(String id)? nameForId,
  }) {
    ids.sort(
      (a, b) => compareGenreIds(
        a,
        b,
        nameA: nameForId?.call(a),
        nameB: nameForId?.call(b),
      ),
    );
  }

  static void sortRakutenGenreMasterEntries(List<RakutenGenreMasterEntry> list) {
    list.sort(
      (a, b) => compareGenreIds(
        a.genreId,
        b.genreId,
        nameA: a.genreName,
        nameB: b.genreName,
      ),
    );
  }

  static void logRootOrder({
    required String source,
    required Iterable<String> genreNames,
    required int count,
  }) {
    if (!kDebugMode) return;
    final first = genreNames.take(5).join(',');
    debugPrint('[GENRE_DISPLAY_ORDER] source=$source count=$count first=$first');
  }
}
