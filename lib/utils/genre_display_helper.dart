import 'rakuten_product_genre_display.dart';
import '../services/rakuten_genre_master_service.dart';

/// 画面向けのジャンル表示ラベル解決（同期・即時表示用）。
///
/// [RakutenProductGenreDisplay.resolve] に委譲する（API名・ローカルマスタ・未分類の優先順位は同じ）。
class GenreDisplayHelper {
  GenreDisplayHelper._();

  /// 空 ID は空文字。それ以外は [RakutenProductGenreDisplay] ルールで解決。
  static String immediateLabelForGenreId(String? rawGenreId) {
    final id = rawGenreId?.trim() ?? '';
    if (id.isEmpty) return '';
    return RakutenProductGenreDisplay.resolve(
      apiGenreName: null,
      persistedGenreName: null,
      prefetchedGenreName: null,
      genreId: id,
    );
  }

  /// 互換: 旧コード向け。実質 [RakutenProductGenreDisplay.unknownLabel] と同じ文字列。
  static String get unknownLabel => RakutenGenreMasterService.unknownGenreDisplayLabel;
}
