import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/demo_mode.dart';
import '../data/demo_mode_data.dart';
import '../models/today_recommendation.dart';
import '../utils/today_recommendation_exposure_policy.dart';
import '../utils/today_recommendation_genre_page_store.dart';

class TodayRecommendationRepository {
  TodayRecommendationRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'today_recommendation_bundle_v1';
  static const String _exposureKey = 'today_recommend_exposure_history_v1';
  static const int _maxExposureRecords = 400;

  TodayRecommendationBundle? load() {
    if (kDemoModeEnabled) {
      return DemoModeData.todayRecommendationBundle();
    }
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final bundle = TodayRecommendationBundle.fromJson(decoded);
      if (kDebugMode) {
        debugPrint('[RECOMMEND_TRACE] savedBundle=${bundle != null}');
      }
      return bundle;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[RECOMMEND_TRACE] savedBundle=false');
      }
      return null;
    }
  }

  Future<void> save(TodayRecommendationBundle bundle) async {
    if (kDemoModeEnabled) {
      return;
    }
    await _prefs.setString(_key, jsonEncode(bundle.toJson()));
    if (kDebugMode) {
      debugPrint('[RECOMMEND_TRACE] savedBundle=true');
    }
  }

  Map<String, TodayRecommendExposureRecord> loadExposureRecords() {
    if (kDemoModeEnabled) return {};
    final raw = _prefs.getString(_exposureKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final records = <TodayRecommendExposureRecord>[];
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        final rec = TodayRecommendExposureRecord.fromJson(e);
        if (rec != null) records.add(rec);
      }
      return TodayRecommendExposurePolicy.mergeRecords(records);
    } catch (_) {
      return {};
    }
  }

  Future<void> recordExposureShown(
    Iterable<TodayRecommendationEntry> entries, {
    required DateTime shownAt,
  }) async {
    if (kDemoModeEnabled) return;
    final merged = loadExposureRecords();
    for (final entry in entries) {
      final id = entry.item.productId.trim();
      if (id.isEmpty) continue;
      final prev = merged[id];
      merged[id] = TodayRecommendExposureRecord(
        productId: id,
        itemUrl: entry.item.itemUrl.trim().isNotEmpty
            ? entry.item.itemUrl.trim()
            : (prev?.itemUrl ?? ''),
        shownAt: shownAt,
        dismissedAt: prev?.dismissedAt,
      );
    }
    await _saveExposureRecords(merged);
  }

  Future<void> recordExposureDismissed({
    required String productId,
    required String itemUrl,
    required DateTime dismissedAt,
  }) async {
    if (kDemoModeEnabled) return;
    final id = productId.trim();
    if (id.isEmpty) return;
    final merged = loadExposureRecords();
    final prev = merged[id];
    merged[id] = TodayRecommendExposureRecord(
      productId: id,
      itemUrl: itemUrl.trim().isNotEmpty ? itemUrl.trim() : (prev?.itemUrl ?? ''),
      shownAt: prev?.shownAt,
      dismissedAt: dismissedAt,
    );
    await _saveExposureRecords(merged);
  }

  Future<void> _saveExposureRecords(
    Map<String, TodayRecommendExposureRecord> records,
  ) async {
    final sorted = records.values.toList()
      ..sort((a, b) {
        final ad = a.dismissedAt ?? a.shownAt;
        final bd = b.dismissedAt ?? b.shownAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    final trimmed = sorted.take(_maxExposureRecords).toList(growable: false);
    await _prefs.setString(
      _exposureKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Map<String, TodayRecommendGenrePageCursor> loadGenrePageCursors() {
    if (kDemoModeEnabled) return {};
    return TodayRecommendGenrePageStore.loadAll(_prefs);
  }

  Future<void> saveGenrePageCursors(
    Map<String, TodayRecommendGenrePageCursor> cursors,
  ) async {
    if (kDemoModeEnabled) return;
    await TodayRecommendGenrePageStore.saveAll(_prefs, cursors);
  }
}
