import '../models/rakuten_genre_master_entry.dart';

/// アプリ同梱の簡易ジャンルマスタ（後から Firestore / 楽天ジャンルAPI に差し替え可能）。
///
/// 実データの更新は [LocalRakutenGenreMasterRepository] や
/// 将来追加するリモート実装側に寄せる想定で、UI から直接参照しない。
abstract final class RakutenGenreMasterLocalData {
  static const List<RakutenGenreMasterEntry> entries = [
    RakutenGenreMasterEntry(genreId: '100005', genreName: '本・雑誌・漫画'),
    RakutenGenreMasterEntry(genreId: '100026', genreName: 'パソコン・周辺機器'),
    RakutenGenreMasterEntry(genreId: '100227', genreName: '食品'),
    RakutenGenreMasterEntry(genreId: '100371', genreName: '水・ソフトドリンク'),
    RakutenGenreMasterEntry(genreId: '100433', genreName: 'ビール・洋酒'),
    RakutenGenreMasterEntry(genreId: '100804', genreName: 'キッチン用品・食器'),
    RakutenGenreMasterEntry(genreId: '100939', genreName: 'インテリア・寝具・収納'),
    RakutenGenreMasterEntry(genreId: '101070', genreName: '日本酒・焼酎'),
    RakutenGenreMasterEntry(genreId: '101240', genreName: 'おもちゃ'),
    RakutenGenreMasterEntry(genreId: '213131', genreName: 'ペット・ペットグッズ'),
    RakutenGenreMasterEntry(genreId: '216131', genreName: 'バッグ・小物・ブランド雑貨'),
    RakutenGenreMasterEntry(genreId: '551167', genreName: '家電'),
    RakutenGenreMasterEntry(genreId: '551177', genreName: 'パソコン・周辺機器'),
    RakutenGenreMasterEntry(genreId: '558885', genreName: 'スポーツ・アウトドア'),
    RakutenGenreMasterEntry(genreId: '558929', genreName: '花・ガーデン・DIY'),
    RakutenGenreMasterEntry(genreId: '565004', genreName: '日用品雑貨・文房具・手芸'),
    RakutenGenreMasterEntry(genreId: '611505', genreName: 'キッズ・ベビー・マタニティ'),
  ];
}
