/// 楽天ジャンルマスタの1行分（アプリ内キャッシュ想定）。
///
/// 将来、親ジャンルや階層パスを扱う場合は [parentGenreId] から拡張しやすい形にしてある。
class RakutenGenreMasterEntry {
  const RakutenGenreMasterEntry({
    required this.genreId,
    required this.genreName,
    this.parentGenreId,
  });

  /// 楽天APIの `genreId`（数値でも文字列として保持する前提）。
  final String genreId;

  /// 画面表示用の日本語ジャンル名。
  final String genreName;

  /// 親ジャンルID（未使用なら null）。
  final String? parentGenreId;
}
