import '../models/genre_master.dart';
import '../models/rakuten_genre_master_entry.dart';
import '../repository/rakuten_genre_master_repository.dart';
import 'genre_master_service.dart';

/// ジャンルマスタ参照の窓口（UI や画面ロジックはここ経由に寄せる）。
class RakutenGenreMasterService {
  RakutenGenreMasterService._(this._repository);

  /// デフォルト（ローカル定数）。DI が必要になったらコンストラクタ注入に拡張する。
  static final RakutenGenreMasterService instance = RakutenGenreMasterService._(
    LocalRakutenGenreMasterRepository(),
  );

  final RakutenGenreMasterRepository _repository;

  /// 楽天ジャンルAPI＋永続キャッシュ由来の ID→日本語名（同梱マスタに無い leaf 用）。
  final Map<String, String> _runtimeNamesByGenreId = {};

  /// 画面上の未登録 `genreId` 向けラベル（アプリ内で統一）。
  static const String unknownGenreDisplayLabel = '未分類';

  /// [GenreMasterRepository] が保存した [GenreMaster] を参照テーブルへ取り込む。
  ///
  /// 現在ジャンル名に加え、[ancestorGenreIds] / [ancestorNames] の対も登録し、
  /// 大ジャンルだけが同梱マスタにある場合でも祖先経由で名前が引けるようにする。
  void applyGenreMaster(GenreMaster gm) {
    void put(String id, String name) {
      final t = name.trim();
      if (id.isEmpty || t.isEmpty) return;
      _runtimeNamesByGenreId[id] = t;
    }

    if (gm.genreId > 0) {
      put('${gm.genreId}', gm.genreName);
    }
    final ids = gm.ancestorGenreIds;
    final names = gm.ancestorNames;
    final n = ids.length < names.length ? ids.length : names.length;
    for (var i = 0; i < n; i++) {
      if (ids[i] <= 0) continue;
      put('${ids[i]}', names[i]);
    }
  }

  /// プリフェッチ結果など、既に解決済みの ID→名をまとめて取り込む。
  void mergeRuntimeGenreNames(Map<String, String> idToName) {
    for (final e in idToName.entries) {
      final id = e.key.trim();
      final name = e.value.trim();
      if (id.isEmpty || name.isEmpty) continue;
      _runtimeNamesByGenreId[id] = name;
    }
  }

  /// マスタに存在するジャンルのみ名前付きで返す。未登録・空は null（検索フォールバック等で従来挙動を維持）。
  ///
  /// 優先: 同梱定数マスタ → ジャンルAPIキャッシュ由来の [applyGenreMaster] / [mergeRuntimeGenreNames]
  /// → 同梱 JSON マスタ（[GenreMasterService]、全階層の ID 解決用）。
  String? genreNameIfKnown(String? rawGenreId) {
    final id = rawGenreId?.trim() ?? '';
    if (id.isEmpty) return null;
    return _repository.findNameIfRegistered(id) ??
        _runtimeNamesByGenreId[id] ??
        GenreMasterService.instance.getGenreNameById(id);
  }

  /// 一覧・商品表示向け。空 ID は空文字。未登録は [unknownGenreDisplayLabel]。
  String genreDisplayName(String? rawGenreId) {
    final id = rawGenreId?.trim() ?? '';
    if (id.isEmpty) return '';
    return genreNameIfKnown(id) ?? unknownGenreDisplayLabel;
  }

  /// 選択肢としての「マスタ一覧」（ジャンル名昇順）。
  ///
  /// [GenreMasterService] が読み込めているときは JSON の `roots`（最上位ジャンルのみ）を返し、
  /// 件数が膨大にならないようにする。未ロード時は従来どおりローカル定数リスト。
  List<RakutenGenreMasterEntry> getAllGenres() {
    final assetRoots = GenreMasterService.instance.rootMasterEntries();
    final List<RakutenGenreMasterEntry> list;
    if (GenreMasterService.instance.isLoaded && assetRoots.isNotEmpty) {
      list = List<RakutenGenreMasterEntry>.from(assetRoots);
    } else {
      list = List<RakutenGenreMasterEntry>.from(_repository.fetchAll());
    }
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
