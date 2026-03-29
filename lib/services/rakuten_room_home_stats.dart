import '../models/rakuten_managed_product.dart';

/// ホーム画面用の集計（ROOM 管理データの一覧から算出。UI とは分離）。
class RakutenRoomHomeStats {
  RakutenRoomHomeStats._();

  static int countCandidates(List<RakutenManagedProduct> all) {
    return all.where((e) => e.status == RakutenManagedProductStatus.candidate).length;
  }

  static int countDone(List<RakutenManagedProduct> all) {
    return all.where((e) => e.status == RakutenManagedProductStatus.done).length;
  }

  /// [anchor] のローカル暦日と同一日の [doneAt] をもつコレ済件数（日付切替は端末ローカルの 0:00 基準）。
  static int countDoneOnLocalCalendarDay(
    List<RakutenManagedProduct> all,
    DateTime anchor,
  ) {
    final target = DateTime(anchor.year, anchor.month, anchor.day);
    var n = 0;
    for (final e in all) {
      if (e.status != RakutenManagedProductStatus.done) continue;
      final d = e.doneAt;
      if (d == null) continue;
      final localDay = DateTime(d.year, d.month, d.day);
      if (localDay == target) n++;
    }
    return n;
  }

  /// コレ済のうち最新の [doneAt]（同一ならそのまま）。
  static DateTime? latestDoneAt(List<RakutenManagedProduct> all) {
    DateTime? max;
    for (final e in all) {
      if (e.status != RakutenManagedProductStatus.done) continue;
      final d = e.doneAt;
      if (d == null) continue;
      if (max == null || d.isAfter(max)) max = d;
    }
    return max;
  }

  /// 候補を [updatedAt] 降順で並べた一覧。
  static List<RakutenManagedProduct> candidatesNewestFirst(
    List<RakutenManagedProduct> all,
  ) {
    final list =
        all.where((e) => e.status == RakutenManagedProductStatus.candidate).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
}
