import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ジャンル別のおすすめ検索ページカーソル（枯渇対策・最小永続化）。
class TodayRecommendGenrePageCursor {
  const TodayRecommendGenrePageCursor({
    this.lastFetchedPage = 0,
    this.lastFetchedSort = '',
    this.lastFetchedAt,
    this.exhaustedUntil,
    this.lastRawCount = 0,
    this.lastUsableCount = 0,
    this.lastManagedExcludedCount = 0,
  });

  final int lastFetchedPage;
  final String lastFetchedSort;
  final DateTime? lastFetchedAt;
  final DateTime? exhaustedUntil;
  final int lastRawCount;
  final int lastUsableCount;
  final int lastManagedExcludedCount;

  Map<String, dynamic> toJson() => {
    'lastFetchedPage': lastFetchedPage,
    'lastFetchedSort': lastFetchedSort,
    if (lastFetchedAt != null) 'lastFetchedAt': lastFetchedAt!.toIso8601String(),
    if (exhaustedUntil != null)
      'exhaustedUntil': exhaustedUntil!.toIso8601String(),
    'lastRawCount': lastRawCount,
    'lastUsableCount': lastUsableCount,
    'lastManagedExcludedCount': lastManagedExcludedCount,
  };

  static TodayRecommendGenrePageCursor? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    DateTime? parseDt(Object? raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return TodayRecommendGenrePageCursor(
      lastFetchedPage: (json['lastFetchedPage'] as num?)?.toInt() ?? 0,
      lastFetchedSort: (json['lastFetchedSort'] ?? '').toString(),
      lastFetchedAt: parseDt(json['lastFetchedAt']),
      exhaustedUntil: parseDt(json['exhaustedUntil']),
      lastRawCount: (json['lastRawCount'] as num?)?.toInt() ?? 0,
      lastUsableCount: (json['lastUsableCount'] as num?)?.toInt() ?? 0,
      lastManagedExcludedCount:
          (json['lastManagedExcludedCount'] as num?)?.toInt() ?? 0,
    );
  }

  TodayRecommendGenrePageCursor copyWith({
    int? lastFetchedPage,
    String? lastFetchedSort,
    DateTime? lastFetchedAt,
    DateTime? exhaustedUntil,
    int? lastRawCount,
    int? lastUsableCount,
    int? lastManagedExcludedCount,
  }) {
    return TodayRecommendGenrePageCursor(
      lastFetchedPage: lastFetchedPage ?? this.lastFetchedPage,
      lastFetchedSort: lastFetchedSort ?? this.lastFetchedSort,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      exhaustedUntil: exhaustedUntil ?? this.exhaustedUntil,
      lastRawCount: lastRawCount ?? this.lastRawCount,
      lastUsableCount: lastUsableCount ?? this.lastUsableCount,
      lastManagedExcludedCount:
          lastManagedExcludedCount ?? this.lastManagedExcludedCount,
    );
  }
}

/// ジャンル別 page ローテーション（SharedPreferences）。
abstract final class TodayRecommendGenrePageStore {
  static const String prefsKey = 'today_recommend_genre_page_v1';
  static const int maxPage = 10;
  static const int exhaustedRawThreshold = 12;
  static const Duration exhaustedCooldown = Duration(hours: 24);

  static String cursorKey(String genreId, String sort) =>
      '${genreId.trim()}|${sort.trim()}';

  static Map<String, TodayRecommendGenrePageCursor> loadAll(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final out = <String, TodayRecommendGenrePageCursor>{};
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is! Map<String, dynamic>) continue;
        final cur = TodayRecommendGenrePageCursor.fromJson(v);
        if (cur != null) out[entry.key] = cur;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAll(
    SharedPreferences prefs,
    Map<String, TodayRecommendGenrePageCursor> cursors,
  ) async {
    final encoded = <String, dynamic>{};
    for (final e in cursors.entries) {
      encoded[e.key] = e.value.toJson();
    }
    await prefs.setString(prefsKey, jsonEncode(encoded));
  }

  /// 次に叩く page（1始まり）。枯渇クールダウン中は 1 に戻す。
  static int resolveNextPage({
    required TodayRecommendGenrePageCursor? cursor,
    required String sort,
    required DateTime now,
  }) {
    if (cursor == null || cursor.lastFetchedPage <= 0) return 1;
    if (cursor.lastFetchedSort.trim() != sort.trim()) return 1;
    if (cursor.exhaustedUntil != null && now.isBefore(cursor.exhaustedUntil!)) {
      return 1;
    }
    final next = cursor.lastFetchedPage + 1;
    if (next > maxPage) return 1;
    return next;
  }

  static TodayRecommendGenrePageCursor advance({
    required TodayRecommendGenrePageCursor? previous,
    required String sort,
    required int pageUsed,
    required int rawCount,
    required int usableCount,
    required int managedExcludedCount,
    required DateTime now,
  }) {
    final exhausted = rawCount < exhaustedRawThreshold;
    return TodayRecommendGenrePageCursor(
      lastFetchedPage: pageUsed,
      lastFetchedSort: sort,
      lastFetchedAt: now,
      exhaustedUntil: exhausted ? now.add(exhaustedCooldown) : null,
      lastRawCount: rawCount,
      lastUsableCount: usableCount,
      lastManagedExcludedCount: managedExcludedCount,
    );
  }
}
