import '../services/rakuten_genre_master_service.dart';

/// 画面向けのジャンル表示ラベル解決（同期・即時表示用）。
///
/// API 取得前はローカル定数マスタに無い場合 [rawGenreId] 自体を返す（取得中でも ID が見える）。
class GenreDisplayHelper {
  GenreDisplayHelper._();

  /// 空 ID は空文字。ローカルマスタ命中時は日本語名、それ以外は ID 文字列。
  static String immediateLabelForGenreId(String? rawGenreId) {
    final id = rawGenreId?.trim() ?? '';
    if (id.isEmpty) return '';
    final known = RakutenGenreMasterService.instance.genreNameIfKnown(id);
    if (known != null && known.isNotEmpty) return known;
    return id;
  }
}
