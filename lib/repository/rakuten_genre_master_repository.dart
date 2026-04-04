import '../data/rakuten_genre_master_local_data.dart';
import '../models/rakuten_genre_master_entry.dart';

/// 楽天ジャンルマスタの取得元（Firestore / 楽天ジャンルAPI 等へ差し替え時は実装を追加）。
abstract class RakutenGenreMasterRepository {
  List<RakutenGenreMasterEntry> fetchAll();

  /// 登録済みの場合のみ名称を返す（未登録は null）。
  String? findNameIfRegistered(String genreId);
}

/// ローカル定数リストをソースとする実装。
class LocalRakutenGenreMasterRepository
    implements RakutenGenreMasterRepository {
  LocalRakutenGenreMasterRepository();

  List<RakutenGenreMasterEntry>? _all;
  Map<String, String>? _byId;

  @override
  List<RakutenGenreMasterEntry> fetchAll() {
    return _all ??= List<RakutenGenreMasterEntry>.unmodifiable(
      RakutenGenreMasterLocalData.entries,
    );
  }

  @override
  String? findNameIfRegistered(String genreId) {
    final id = genreId.trim();
    if (id.isEmpty) return null;
    _byId ??= {
      for (final e in RakutenGenreMasterLocalData.entries)
        e.genreId: e.genreName,
    };
    return _byId![id];
  }
}
