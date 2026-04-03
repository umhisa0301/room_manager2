import '../models/rakuten_genre_master_entry.dart';
import '../repository/rakuten_genre_master_repository.dart';

/// ジャンルマスタ参照の窓口（UI や画面ロジックはここ経由に寄せる）。
class RakutenGenreMasterService {
  RakutenGenreMasterService._(this._repository);

  /// デフォルト（ローカル定数）。DI が必要になったらコンストラクタ注入に拡張する。
  static final RakutenGenreMasterService instance = RakutenGenreMasterService._(
    LocalRakutenGenreMasterRepository(),
  );

  final RakutenGenreMasterRepository _repository;

  /// 画面上の未登録 `genreId` 向けラベル（アプリ内で統一）。
  static const String unknownGenreDisplayLabel = '未分類';

  /// マスタに存在するジャンルのみ名前付きで返す。未登録・空は null（検索フォールバック等で従来挙動を維持）。
  String? genreNameIfKnown(String? rawGenreId) {
    final id = rawGenreId?.trim() ?? '';
    if (id.isEmpty) return null;
    return _repository.findNameIfRegistered(id);
  }

  /// 一覧・商品表示向け。空 ID は空文字。未登録は [unknownGenreDisplayLabel]。
  String genreDisplayName(String? rawGenreId) {
    final id = rawGenreId?.trim() ?? '';
    if (id.isEmpty) return '';
    return _repository.findNameIfRegistered(id) ?? unknownGenreDisplayLabel;
  }

  /// マスタ全件（ジャンル名昇順）。UI・ダイアログ・マイグレーションの共通入口。
  List<RakutenGenreMasterEntry> getAllGenres() {
    final list = List<RakutenGenreMasterEntry>.from(_repository.fetchAll());
    list.sort((a, b) => a.genreName.compareTo(b.genreName));
    return list;
  }

  /// `getAllGenres` と同一（プルダウン用の別名。既存呼び出し互換）。
  List<RakutenGenreMasterEntry> orderedMasterEntriesForDropdown() =>
      getAllGenres();

  /// [genreDisplayName] の別名（要件上の命名用）。
  String getGenreNameById(String? rawGenreId) => genreDisplayName(rawGenreId);

  /// ROOMコレ絞り込みのドロップダウン表示用（値は `genreId` のまま）。
  String roomColleGenreFilterMenuLabel(String genreId) {
    final id = genreId.trim();
    if (id.isEmpty) return '';
    final name = genreDisplayName(id);
    if (name == unknownGenreDisplayLabel) {
      return '$unknownGenreDisplayLabel（$id）';
    }
    return name;
  }
}
