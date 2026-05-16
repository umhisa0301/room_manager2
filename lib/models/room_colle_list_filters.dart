import 'package:flutter/foundation.dart';

import 'rakuten_managed_product.dart';
import '../utils/room_colle_candidate_stale.dart';

/// 候補タブ：登録からの経過で「候補から外す対象」を絞る。
enum RoomColleStaleCandidatePreset { none, threePlus, sevenPlus, thirtyPlus }

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

/// 登録日の相対フィルター。既存の [last7Days] は互換維持のため名称を残す。
enum RoomColleRegisteredDatePreset {
  all,
  today,
  last3Days,
  last7Days,
  last30Days,
  olderThan30Days,
}

RoomColleRegisteredDatePreset roomColleRegisteredDatePresetFromWire(
  String? raw,
) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return RoomColleRegisteredDatePreset.all;
  return RoomColleRegisteredDatePreset.values.firstWhere(
    (e) => e.name == t,
    orElse: () => RoomColleRegisteredDatePreset.all,
  );
}

enum RoomCollePostedDatePreset { all, today, last3Days, last7Days, last30Days }

RoomCollePostedDatePreset roomCollePostedDatePresetFromWire(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return RoomCollePostedDatePreset.all;
  return RoomCollePostedDatePreset.values.firstWhere(
    (e) => e.name == t,
    orElse: () => RoomCollePostedDatePreset.all,
  );
}

/// コレ済タブのクイックフィルター（評価プリセット）。
enum RoomColleDoneQuickFilterPreset {
  all,
  sold,
  roomReaction,
  roomCommentOnly,
  roomLikeOnly,
  roomPosted,
}

RoomColleDoneQuickFilterPreset roomColleDoneQuickFilterPresetFromWire(
  String? raw,
) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return RoomColleDoneQuickFilterPreset.all;
  return RoomColleDoneQuickFilterPreset.values.firstWhere(
    (e) => e.name == t,
    orElse: () => RoomColleDoneQuickFilterPreset.all,
  );
}

enum RoomColleShopFilterMode { all, saved, shopName }

RoomColleShopFilterMode roomColleShopFilterModeFromWire(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return RoomColleShopFilterMode.all;
  return RoomColleShopFilterMode.values.firstWhere(
    (e) => e.name == t,
    orElse: () => RoomColleShopFilterMode.all,
  );
}

/// ROOMコレ一覧用の絞り込み条件。
///
/// 既存JSONに新キーが無くても [fromJson] でデフォルトへ戻す。
@immutable
class RoomColleListFilterCriteria {
  const RoomColleListFilterCriteria({
    this.keyword = '',
    this.registeredDatePreset = RoomColleRegisteredDatePreset.all,
    this.shopFilterMode = RoomColleShopFilterMode.all,
    this.shopName,
    this.staleCandidatePreset = RoomColleStaleCandidatePreset.none,
    this.genreId,
    this.priceMinYen,
    this.priceMaxYen,
    this.candidateHasRoomUrlOnly = false,
    this.candidateTodayRecommendationOnly = false,
    this.candidateUnpostedOnly = false,
    this.doneFeedbackSold = false,
    this.doneFeedbackLiked = false,
    this.doneFeedbackWeak = false,
    this.doneFeedbackUnrated = false,
    this.doneQuickFilter = RoomColleDoneQuickFilterPreset.all,
    this.doneRoomConfirmedOnly = false,
    this.postedDatePreset = RoomCollePostedDatePreset.all,
  });

  /// 商品名・ショップ名・ジャンル名を横断検索する。
  final String keyword;
  final RoomColleRegisteredDatePreset registeredDatePreset;
  final RoomColleShopFilterMode shopFilterMode;
  final String? shopName;
  final RoomColleStaleCandidatePreset staleCandidatePreset;
  final String? genreId;
  final int? priceMinYen;
  final int? priceMaxYen;

  final bool candidateHasRoomUrlOnly;
  final bool candidateTodayRecommendationOnly;
  final bool candidateUnpostedOnly;

  final bool doneFeedbackSold;
  final bool doneFeedbackLiked;
  final bool doneFeedbackWeak;
  final bool doneFeedbackUnrated;
  final RoomColleDoneQuickFilterPreset doneQuickFilter;
  final bool doneRoomConfirmedOnly;
  final RoomCollePostedDatePreset postedDatePreset;

  static const RoomColleListFilterCriteria defaults =
      RoomColleListFilterCriteria();

  bool get hasNonKeywordConstraints {
    if (registeredDatePreset != RoomColleRegisteredDatePreset.all) return true;
    if (shopFilterMode != RoomColleShopFilterMode.all) return true;
    if ((shopName?.trim() ?? '').isNotEmpty) return true;
    if (staleCandidatePreset != RoomColleStaleCandidatePreset.none) {
      return true;
    }
    if ((genreId?.trim() ?? '').isNotEmpty) return true;
    if (priceMinYen != null || priceMaxYen != null) return true;
    if (candidateHasRoomUrlOnly ||
        candidateTodayRecommendationOnly ||
        candidateUnpostedOnly) {
      return true;
    }
    if (doneFeedbackSold ||
        doneFeedbackLiked ||
        doneFeedbackWeak ||
        doneFeedbackUnrated ||
        doneRoomConfirmedOnly) {
      return true;
    }
    if (doneQuickFilter != RoomColleDoneQuickFilterPreset.all) return true;
    if (postedDatePreset != RoomCollePostedDatePreset.all) return true;
    return false;
  }

  /// ROOMのいいね／コメントで「反応あり」自動適用してよいか（キーワード・日付など未設定）。
  bool get isDoneFilterDefaultForAutoReaction {
    if (keyword.trim().isNotEmpty) return false;
    if (registeredDatePreset != RoomColleRegisteredDatePreset.all) {
      return false;
    }
    if (shopFilterMode != RoomColleShopFilterMode.all) return false;
    if ((shopName?.trim() ?? '').isNotEmpty) return false;
    if (staleCandidatePreset != RoomColleStaleCandidatePreset.none) {
      return false;
    }
    if ((genreId?.trim() ?? '').isNotEmpty) return false;
    if (priceMinYen != null || priceMaxYen != null) return false;
    if (candidateHasRoomUrlOnly ||
        candidateTodayRecommendationOnly ||
        candidateUnpostedOnly) {
      return false;
    }
    if (doneQuickFilter != RoomColleDoneQuickFilterPreset.all) return false;
    if (doneFeedbackSold ||
        doneFeedbackLiked ||
        doneFeedbackWeak ||
        doneFeedbackUnrated ||
        doneRoomConfirmedOnly) {
      return false;
    }
    if (postedDatePreset != RoomCollePostedDatePreset.all) return false;
    return true;
  }

  bool get hasAnyReducingFilter =>
      keyword.trim().isNotEmpty || hasNonKeywordConstraints;

  RoomColleListFilterCriteria copyWith({
    String? keyword,
    RoomColleRegisteredDatePreset? registeredDatePreset,
    RoomColleShopFilterMode? shopFilterMode,
    String? shopName,
    bool clearShopName = false,
    RoomColleStaleCandidatePreset? staleCandidatePreset,
    String? genreId,
    bool clearGenreId = false,
    int? priceMinYen,
    int? priceMaxYen,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
    bool? candidateHasRoomUrlOnly,
    bool? candidateTodayRecommendationOnly,
    bool? candidateUnpostedOnly,
    bool? doneFeedbackSold,
    bool? doneFeedbackLiked,
    bool? doneFeedbackWeak,
    bool? doneFeedbackUnrated,
    RoomColleDoneQuickFilterPreset? doneQuickFilter,
    bool? doneRoomConfirmedOnly,
    RoomCollePostedDatePreset? postedDatePreset,
  }) {
    return RoomColleListFilterCriteria(
      keyword: keyword ?? this.keyword,
      registeredDatePreset: registeredDatePreset ?? this.registeredDatePreset,
      shopFilterMode: shopFilterMode ?? this.shopFilterMode,
      shopName: clearShopName ? null : (shopName ?? this.shopName),
      staleCandidatePreset: staleCandidatePreset ?? this.staleCandidatePreset,
      genreId: clearGenreId ? null : (genreId ?? this.genreId),
      priceMinYen: clearPriceMin ? null : (priceMinYen ?? this.priceMinYen),
      priceMaxYen: clearPriceMax ? null : (priceMaxYen ?? this.priceMaxYen),
      candidateHasRoomUrlOnly:
          candidateHasRoomUrlOnly ?? this.candidateHasRoomUrlOnly,
      candidateTodayRecommendationOnly:
          candidateTodayRecommendationOnly ??
          this.candidateTodayRecommendationOnly,
      candidateUnpostedOnly:
          candidateUnpostedOnly ?? this.candidateUnpostedOnly,
      doneFeedbackSold: doneFeedbackSold ?? this.doneFeedbackSold,
      doneFeedbackLiked: doneFeedbackLiked ?? this.doneFeedbackLiked,
      doneFeedbackWeak: doneFeedbackWeak ?? this.doneFeedbackWeak,
      doneFeedbackUnrated: doneFeedbackUnrated ?? this.doneFeedbackUnrated,
      doneQuickFilter: doneQuickFilter ?? this.doneQuickFilter,
      doneRoomConfirmedOnly:
          doneRoomConfirmedOnly ?? this.doneRoomConfirmedOnly,
      postedDatePreset: postedDatePreset ?? this.postedDatePreset,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'keyword': keyword,
      'registeredDatePreset': registeredDatePreset.name,
      'shopFilterMode': shopFilterMode.name,
      'shopName': shopName,
      'staleCandidatePreset': staleCandidatePreset.name,
      'genreId': genreId,
      'priceMinYen': priceMinYen,
      'priceMaxYen': priceMaxYen,
      'candidateHasRoomUrlOnly': candidateHasRoomUrlOnly,
      'candidateTodayRecommendationOnly': candidateTodayRecommendationOnly,
      'candidateUnpostedOnly': candidateUnpostedOnly,
      'doneFeedbackSold': doneFeedbackSold,
      'doneFeedbackLiked': doneFeedbackLiked,
      'doneFeedbackWeak': doneFeedbackWeak,
      'doneFeedbackUnrated': doneFeedbackUnrated,
      'doneQuickFilter': doneQuickFilter.name,
      'doneRoomConfirmedOnly': doneRoomConfirmedOnly,
      'postedDatePreset': postedDatePreset.name,
    };
  }

  static RoomColleListFilterCriteria fromJson(dynamic raw) {
    if (raw is! Map) return defaults;
    try {
      final m = Map<String, dynamic>.from(raw);
      int? readOptInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v.trim());
        return null;
      }

      bool readBool(dynamic v) {
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final t = v.trim().toLowerCase();
          return t == 'true' || t == '1' || t == 'yes';
        }
        return false;
      }

      final gRaw = m['genreId']?.toString().trim();
      final sRaw = m['shopName']?.toString().trim();
      var minY = readOptInt(m['priceMinYen']);
      var maxY = readOptInt(m['priceMaxYen']);
      if (minY != null && maxY != null && minY > maxY) {
        final t = minY;
        minY = maxY;
        maxY = t;
      }

      return RoomColleListFilterCriteria(
        keyword: (m['keyword'] ?? '').toString(),
        registeredDatePreset: roomColleRegisteredDatePresetFromWire(
          m['registeredDatePreset']?.toString(),
        ),
        shopFilterMode: roomColleShopFilterModeFromWire(
          m['shopFilterMode']?.toString(),
        ),
        shopName: (sRaw != null && sRaw.isNotEmpty) ? sRaw : null,
        staleCandidatePreset: roomColleStaleCandidatePresetFromWire(
          m['staleCandidatePreset']?.toString(),
        ),
        genreId: (gRaw != null && gRaw.isNotEmpty) ? gRaw : null,
        priceMinYen: minY,
        priceMaxYen: maxY,
        candidateHasRoomUrlOnly: readBool(m['candidateHasRoomUrlOnly']),
        candidateTodayRecommendationOnly: readBool(
          m['candidateTodayRecommendationOnly'],
        ),
        candidateUnpostedOnly: readBool(m['candidateUnpostedOnly']),
        doneFeedbackSold: readBool(m['doneFeedbackSold']),
        doneFeedbackLiked: readBool(m['doneFeedbackLiked']),
        doneFeedbackWeak: readBool(m['doneFeedbackWeak']),
        doneFeedbackUnrated: readBool(m['doneFeedbackUnrated']),
        doneQuickFilter: () {
          final hasKey = m.containsKey('doneQuickFilter');
          var dq = roomColleDoneQuickFilterPresetFromWire(
            m['doneQuickFilter']?.toString(),
          );
          if (!hasKey) {
            if (readBool(m['doneFeedbackSold'])) {
              dq = RoomColleDoneQuickFilterPreset.sold;
            }
          }
          return dq;
        }(),
        doneRoomConfirmedOnly: readBool(m['doneRoomConfirmedOnly']),
        postedDatePreset: roomCollePostedDatePresetFromWire(
          m['postedDatePreset']?.toString(),
        ),
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

bool _managedProductMatchesKeyword(
  RakutenManagedProduct e,
  String query,
  String Function(RakutenManagedProduct product)? genreLabelForProduct,
) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) return true;
  final genre =
      (genreLabelForProduct?.call(e) ??
              e.persistedGenreDisplayName ??
              e.genreId)
          .toLowerCase();
  return e.itemName.toLowerCase().contains(t) ||
      e.shopName.toLowerCase().contains(t) ||
      genre.contains(t);
}

bool _matchesRelativeDate(DateTime? raw, RoomColleRegisteredDatePreset preset) {
  if (preset == RoomColleRegisteredDatePreset.all) return true;
  if (raw == null) return false;
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(raw.year, raw.month, raw.day);
    switch (preset) {
      case RoomColleRegisteredDatePreset.all:
        return true;
      case RoomColleRegisteredDatePreset.today:
        return d == today;
      case RoomColleRegisteredDatePreset.last3Days:
        return !d.isBefore(today.subtract(const Duration(days: 2)));
      case RoomColleRegisteredDatePreset.last7Days:
        return !d.isBefore(today.subtract(const Duration(days: 6)));
      case RoomColleRegisteredDatePreset.last30Days:
        return !d.isBefore(today.subtract(const Duration(days: 29)));
      case RoomColleRegisteredDatePreset.olderThan30Days:
        return d.isBefore(today.subtract(const Duration(days: 30)));
    }
  } catch (_) {
    return false;
  }
}

DateTime? _effectivePostedDateForDoneFilter(RakutenManagedProduct e) {
  switch (e.coredActivitySource) {
    case RakutenCoredActivitySource.roomImport:
      return e.roomPostedAt;
    case RakutenCoredActivitySource.manual:
      return e.doneAt ?? e.addedAt;
    case RakutenCoredActivitySource.appPost:
      return e.doneAt;
  }
}

bool _matchesPostedDate(DateTime? raw, RoomCollePostedDatePreset preset) {
  if (preset == RoomCollePostedDatePreset.all) return true;
  if (raw == null) return false;
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(raw.year, raw.month, raw.day);
    switch (preset) {
      case RoomCollePostedDatePreset.all:
        return true;
      case RoomCollePostedDatePreset.today:
        return d == today;
      case RoomCollePostedDatePreset.last3Days:
        return !d.isBefore(today.subtract(const Duration(days: 2)));
      case RoomCollePostedDatePreset.last7Days:
        return !d.isBefore(today.subtract(const Duration(days: 6)));
      case RoomCollePostedDatePreset.last30Days:
        return !d.isBefore(today.subtract(const Duration(days: 29)));
    }
  } catch (_) {
    return false;
  }
}

bool _matchesShop(
  RakutenManagedProduct e,
  RoomColleListFilterCriteria criteria,
  Set<String> savedShopIds,
) {
  switch (criteria.shopFilterMode) {
    case RoomColleShopFilterMode.all:
      return true;
    case RoomColleShopFilterMode.saved:
      return savedShopIds.contains(e.shopCode.trim());
    case RoomColleShopFilterMode.shopName:
      final target = criteria.shopName?.trim();
      if (target == null || target.isEmpty) return true;
      return e.shopName.trim() == target;
  }
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
      case RoomColleStaleCandidatePreset.threePlus:
        return days >= 3;
      case RoomColleStaleCandidatePreset.sevenPlus:
        return days >= 7;
      case RoomColleStaleCandidatePreset.thirtyPlus:
        return days >= 30;
    }
  } catch (_) {
    return false;
  }
}

bool _matchesPrice(RakutenManagedProduct e, int? minYen, int? maxYen) {
  if (minYen == null && maxYen == null) return true;
  try {
    final p = e.itemPrice;
    if (p <= 0) return false;
    if (minYen != null && p < minYen) return false;
    if (maxYen != null && p > maxYen) return false;
    return true;
  } catch (_) {
    return false;
  }
}

bool _hasRoomUrl(RakutenManagedProduct e) =>
    e.extractedUrl.trim().isNotEmpty || e.roomUrl.trim().isNotEmpty;

bool _matchesDoneQuickFilter(
  RakutenManagedProduct e,
  RoomColleDoneQuickFilterPreset preset,
) {
  switch (preset) {
    case RoomColleDoneQuickFilterPreset.all:
      return true;
    case RoomColleDoneQuickFilterPreset.sold:
      return e.feedbackSoldAt != null;
    case RoomColleDoneQuickFilterPreset.roomReaction:
      return (e.roomLikeCount ?? 0) > 0 || (e.roomCommentCount ?? 0) > 0;
    case RoomColleDoneQuickFilterPreset.roomCommentOnly:
      final cc = e.roomCommentCount;
      return cc != null && cc > 0;
    case RoomColleDoneQuickFilterPreset.roomLikeOnly:
      final lc = e.roomLikeCount;
      return lc != null && lc > 0;
    case RoomColleDoneQuickFilterPreset.roomPosted:
      if (e.roomUrl.trim().isEmpty) return false;
      final lcR = e.roomLikeCount;
      final ccR = e.roomCommentCount;
      final hasPosR =
          (lcR != null && lcR > 0) || (ccR != null && ccR > 0);
      return !hasPosR;
  }
}

bool _matchesCandidateOnly(
  RakutenManagedProduct e,
  RoomColleListFilterCriteria criteria,
  Set<String> todayRecommendationProductIds,
) {
  if (e.status != RakutenManagedProductStatus.candidate) return true;
  if (criteria.candidateHasRoomUrlOnly && !_hasRoomUrl(e)) return false;
  if (criteria.candidateTodayRecommendationOnly &&
      !todayRecommendationProductIds.contains(e.productId.trim())) {
    return false;
  }
  if (criteria.candidateUnpostedOnly && e.doneAt != null) return false;
  return true;
}

bool _matchesDoneOnly(
  RakutenManagedProduct e,
  RoomColleListFilterCriteria criteria,
) {
  if (e.status != RakutenManagedProductStatus.done && e.doneAt == null) {
    return true;
  }
  final quick = criteria.doneQuickFilter;
  if (quick != RoomColleDoneQuickFilterPreset.all) {
    if (!_matchesDoneQuickFilter(e, quick)) return false;
  } else {
    if (criteria.doneFeedbackSold && e.feedbackSoldAt == null) return false;
    if (criteria.doneFeedbackLiked && e.feedbackLikedAt == null) return false;
    if (criteria.doneFeedbackWeak && e.feedbackWeakAt == null) return false;
    if (criteria.doneFeedbackUnrated &&
        (e.feedbackSoldAt != null ||
            e.feedbackLikedAt != null ||
            e.feedbackWeakAt != null)) {
      return false;
    }
  }
  if (criteria.doneRoomConfirmedOnly && !_hasRoomUrl(e)) return false;
  if (!_matchesPostedDate(
    _effectivePostedDateForDoneFilter(e),
    criteria.postedDatePreset,
  )) {
    return false;
  }
  return true;
}

List<RakutenManagedProduct> applyRoomColleListFilters(
  List<RakutenManagedProduct> items,
  RoomColleListFilterCriteria criteria, {
  Set<String> savedShopIds = const <String>{},
  Set<String> todayRecommendationProductIds = const <String>{},
  String Function(RakutenManagedProduct product)? genreLabelForProduct,
}) {
  if (!criteria.hasAnyReducingFilter) {
    return List<RakutenManagedProduct>.from(items);
  }
  final out = <RakutenManagedProduct>[];
  for (final e in items) {
    try {
      if (!_managedProductMatchesKeyword(
        e,
        criteria.keyword,
        genreLabelForProduct,
      )) {
        continue;
      }
      if (!_matchesRelativeDate(e.addedAt, criteria.registeredDatePreset)) {
        continue;
      }
      if (!_matchesShop(e, criteria, savedShopIds)) continue;
      if (!_matchesStaleCandidatePreset(e, criteria.staleCandidatePreset)) {
        continue;
      }
      if (!_matchesGenre(e, criteria.genreId)) continue;
      if (!_matchesPrice(e, criteria.priceMinYen, criteria.priceMaxYen)) {
        continue;
      }
      if (!_matchesCandidateOnly(e, criteria, todayRecommendationProductIds)) {
        continue;
      }
      if (!_matchesDoneOnly(e, criteria)) continue;
      out.add(e);
    } catch (err, st) {
      assert(() {
        debugPrint('[ROOMコレ] フィルタ判定スキップ productId=${e.productId}: $err\n$st');
        return true;
      }());
    }
  }
  return out;
}
