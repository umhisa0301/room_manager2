import 'package:flutter/foundation.dart';

import 'rakuten_managed_product.dart';
import '../utils/room_colle_candidate_stale.dart';

/// 候補タブ：登録からの経過で「整理対象」を絞る（コレ済一覧では無視。将来は一括削除の対象抽出管線に流用可）。
enum RoomColleStaleCandidatePreset {
  /// 条件なし。
  none,

  /// 登録から 7 暦日以上。
  sevenPlus,

  /// 登録から 30 暦日以上。
  thirtyPlus,
}

RoomColleStaleCandidatePreset roomColleStaleCandidatePresetFromWire(
  String? raw,
) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return RoomColleStaleCandidatePreset.none;
  return RoomColleStaleCandidatePreset.values.firstWhere(
    (e) => e.name == t,
    orElse: () => RoomColleStaleCandidatePreset.none,
  );
}

/// アプリに候補として保存した日（[RakutenManagedProduct.addedAt]）ベースのプリセット。
/// コレ済タブでも同一フィールドを使い、「一覧に出す元データの登録日」として扱う。
enum RoomColleRegisteredDatePreset {
  /// 日付条件なし。
  all,

  /// 端末ローカルの暦日で「今日」と同じ日に保存されたもの。
  today,

  /// 今日を含む過去7暦日（今日〜6日前の 0:00 以降）。
  last7Days,
}

RoomColleRegisteredDatePreset roomColleRegisteredDatePresetFromWire(
    String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return RoomColleRegisteredDatePreset.all;
  return RoomColleRegisteredDatePreset.values.firstWhere(
    (e) => e.name == t,
    orElse: () => RoomColleRegisteredDatePreset.all,
  );
}

/// ROOMコレ一覧用の絞り込み条件。
///
/// [keyword] 以外は将来増やしやすいようフィールドを分離。永続化は [toJson] / [fromJson]。
@immutable
class RoomColleListFilterCriteria {
  const RoomColleListFilterCriteria({
    this.keyword = '',
    this.registeredDatePreset = RoomColleRegisteredDatePreset.all,
    this.staleCandidatePreset = RoomColleStaleCandidatePreset.none,
    this.genreId,
    this.priceMinYen,
    this.priceMaxYen,
  });

  /// 商品名・ショップ・ID・URL 等を横断したキーワード（従来どおり）。
  final String keyword;

  /// [RakutenManagedProduct.addedAt] に対するプリセット。
  final RoomColleRegisteredDatePreset registeredDatePreset;

  /// 候補の「古い順」整理向け。単一選択（[none] / [sevenPlus] / [thirtyPlus]）。
  /// コレ済タブの一覧では解釈されない（データは保持され得るが効果は候補のみ）。
  final RoomColleStaleCandidatePreset staleCandidatePreset;

  /// 楽天 [RakutenManagedProduct.genreId] との完全一致。null または空なら未使用。
  /// API由来のIDのみで名前は保持しない（将来、マップテーブルを足せば表示名のみ拡張）。
  final String? genreId;

  /// 価格下限（円・税込み想定の itemPrice）。null なら下限なし。
  final int? priceMinYen;

  /// 価格上限（円）。null なら上限なし。
  final int? priceMaxYen;

  static const RoomColleListFilterCriteria defaults =
      RoomColleListFilterCriteria();

  /// キーワード以外で一覧を減らし得る条件が付いているか。
  bool get hasNonKeywordConstraints {
    if (registeredDatePreset != RoomColleRegisteredDatePreset.all) {
      return true;
    }
    if (staleCandidatePreset != RoomColleStaleCandidatePreset.none) {
      return true;
    }
    final g = genreId?.trim() ?? '';
    if (g.isNotEmpty) return true;
    if (priceMinYen != null || priceMaxYen != null) return true;
    return false;
  }

  /// キーワードまたは拡張条件のいずれかで絞り込みが有効か。
  bool get hasAnyReducingFilter =>
      keyword.trim().isNotEmpty || hasNonKeywordConstraints;

  RoomColleListFilterCriteria copyWith({
    String? keyword,
    RoomColleRegisteredDatePreset? registeredDatePreset,
    RoomColleStaleCandidatePreset? staleCandidatePreset,
    String? genreId,
    bool clearGenreId = false,
    int? priceMinYen,
    int? priceMaxYen,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
  }) {
    return RoomColleListFilterCriteria(
      keyword: keyword ?? this.keyword,
      registeredDatePreset:
          registeredDatePreset ?? this.registeredDatePreset,
      staleCandidatePreset:
          staleCandidatePreset ?? this.staleCandidatePreset,
      genreId: clearGenreId ? null : (genreId ?? this.genreId),
      priceMinYen: clearPriceMin ? null : (priceMinYen ?? this.priceMinYen),
      priceMaxYen: clearPriceMax ? null : (priceMaxYen ?? this.priceMaxYen),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'keyword': keyword,
      'registeredDatePreset': registeredDatePreset.name,
      'staleCandidatePreset': staleCandidatePreset.name,
      'genreId': genreId,
      'priceMinYen': priceMinYen,
      'priceMaxYen': priceMaxYen,
    };
  }

  static RoomColleListFilterCriteria fromJson(dynamic raw) {
    if (raw is! Map) return defaults;
    try {
      final m = Map<String, dynamic>.from(raw);
      final kw = (m['keyword'] ?? '').toString();
      final preset = roomColleRegisteredDatePresetFromWire(
        m['registeredDatePreset']?.toString(),
      );
      final stale = roomColleStaleCandidatePresetFromWire(
        m['staleCandidatePreset']?.toString(),
      );
      final gRaw = m['genreId']?.toString().trim();
      final genre = (gRaw != null && gRaw.isNotEmpty) ? gRaw : null;

      int? readOptInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v.trim());
        return null;
      }

      var minY = readOptInt(m['priceMinYen']);
      var maxY = readOptInt(m['priceMaxYen']);
      if (minY != null && maxY != null && minY > maxY) {
        final t = minY;
        minY = maxY;
        maxY = t;
      }
      return RoomColleListFilterCriteria(
        keyword: kw,
        registeredDatePreset: preset,
        staleCandidatePreset: stale,
        genreId: genre,
        priceMinYen: minY,
        priceMaxYen: maxY,
      );
    } catch (e, st) {
      assert(() {
        debugPrint('[RoomColleListFilterCriteria] fromJson: $e\n$st');
        return true;
      }());
      return defaults;
    }
  }
}

/// キーワード判定（1件のデータ破損で全体を失敗させない）。
bool _managedProductMatchesKeyword(RakutenManagedProduct e, String query) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) return true;
  return e.itemName.toLowerCase().contains(t) ||
      e.shopName.toLowerCase().contains(t) ||
      e.productId.toLowerCase().contains(t) ||
      e.itemUrl.toLowerCase().contains(t) ||
      e.shopCode.toLowerCase().contains(t) ||
      e.genreId.toLowerCase().contains(t);
}

bool _matchesRegisteredDate(
  RakutenManagedProduct e,
  RoomColleRegisteredDatePreset preset,
) {
  if (preset == RoomColleRegisteredDatePreset.all) return true;
  try {
    final c = e.addedAt;
    final now = DateTime.now();
    final cDay = DateTime(c.year, c.month, c.day);
    if (preset == RoomColleRegisteredDatePreset.today) {
      final tDay = DateTime(now.year, now.month, now.day);
      return cDay == tDay;
    }
    if (preset == RoomColleRegisteredDatePreset.last7Days) {
      final todayStart = DateTime(now.year, now.month, now.day);
      final windowStart = todayStart.subtract(const Duration(days: 6));
      return !cDay.isBefore(windowStart);
    }
  } catch (_) {}
  return false;
}

bool _matchesGenre(RakutenManagedProduct e, String? genreFilter) {
  final t = genreFilter?.trim() ?? '';
  if (t.isEmpty) return true;
  try {
    return e.genreId.trim() == t;
  } catch (_) {
    return false;
  }
}

bool _matchesStaleCandidatePreset(
  RakutenManagedProduct e,
  RoomColleStaleCandidatePreset preset,
) {
  if (preset == RoomColleStaleCandidatePreset.none) return true;
  if (e.status != RakutenManagedProductStatus.candidate) return true;
  try {
    final days = RoomColleCandidateStaleSpec.calendarDaysElapsed(
      e.addedAt,
      DateTime.now(),
    );
    switch (preset) {
      case RoomColleStaleCandidatePreset.none:
        return true;
      case RoomColleStaleCandidatePreset.sevenPlus:
        return days >= 7;
      case RoomColleStaleCandidatePreset.thirtyPlus:
        return days >= 30;
    }
  } catch (_) {}
  return false;
}

bool _matchesPrice(
  RakutenManagedProduct e,
  int? minYen,
  int? maxYen,
) {
  try {
    final p = e.itemPrice;
    if (minYen != null && p < minYen) return false;
    if (maxYen != null && p > maxYen) return false;
    return true;
  } catch (_) {
    return false;
  }
}

/// [criteria] を適用（キーワード＋登録日＋経過（候補のみ）＋ジャンルID＋価格帯）。例外はスキップ。
///
/// [staleCandidatePreset] は [RakutenManagedProductStatus.candidate] の行だけに効く。
/// 将来、同じ [RoomColleListFilterCriteria] で [applyRoomColleListFilters] 済みリストを
/// 一括削除の対象 ID に流用できる。
List<RakutenManagedProduct> applyRoomColleListFilters(
  List<RakutenManagedProduct> items,
  RoomColleListFilterCriteria criteria,
) {
  if (!criteria.hasAnyReducingFilter) {
    return List<RakutenManagedProduct>.from(items);
  }
  final out = <RakutenManagedProduct>[];
  for (final e in items) {
    try {
      if (!_managedProductMatchesKeyword(e, criteria.keyword)) continue;
      if (!_matchesRegisteredDate(e, criteria.registeredDatePreset)) continue;
      if (!_matchesStaleCandidatePreset(e, criteria.staleCandidatePreset)) {
        continue;
      }
      if (!_matchesGenre(e, criteria.genreId)) continue;
      if (!_matchesPrice(e, criteria.priceMinYen, criteria.priceMaxYen)) {
        continue;
      }
      out.add(e);
    } catch (err, st) {
      assert(() {
        debugPrint(
          '[ROOMコレ] フィルタ判定スキップ productId=${e.productId}: $err\n$st',
        );
        return true;
      }());
    }
  }
  return out;
}
