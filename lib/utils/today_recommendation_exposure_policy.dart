/// おすすめ候補の表示・見送り履歴（永続化 JSON の1行分）。
class TodayRecommendExposureRecord {
  const TodayRecommendExposureRecord({
    required this.productId,
    this.itemUrl = '',
    this.shownAt,
    this.dismissedAt,
  });

  final String productId;
  final String itemUrl;
  final DateTime? shownAt;
  final DateTime? dismissedAt;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'itemUrl': itemUrl,
    if (shownAt != null) 'shownAt': shownAt!.toIso8601String(),
    if (dismissedAt != null) 'dismissedAt': dismissedAt!.toIso8601String(),
  };

  static TodayRecommendExposureRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = (json['productId'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    DateTime? parseDt(Object? raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return TodayRecommendExposureRecord(
      productId: id,
      itemUrl: (json['itemUrl'] ?? '').toString().trim(),
      shownAt: parseDt(json['shownAt']),
      dismissedAt: parseDt(json['dismissedAt']),
    );
  }

  TodayRecommendExposureRecord copyWith({
    String? productId,
    String? itemUrl,
    DateTime? shownAt,
    DateTime? dismissedAt,
  }) {
    return TodayRecommendExposureRecord(
      productId: productId ?? this.productId,
      itemUrl: itemUrl ?? this.itemUrl,
      shownAt: shownAt ?? this.shownAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
    );
  }
}

/// 表示済み・見送り済みの除外判定（テスト可能な純粋ロジック）。
abstract final class TodayRecommendExposurePolicy {
  /// 見送り済みの除外期間。
  static const Duration dismissedSuppressDuration = Duration(days: 30);

  /// 直近表示済みの除外期間（完全除外。枯渇時は生成側で件数不足を許容）。
  static const Duration shownSuppressDuration = Duration(days: 14);

  static bool urlsLooselyEqual(String? a, String? b) {
    final x = a?.trim().toLowerCase() ?? '';
    final y = b?.trim().toLowerCase() ?? '';
    if (x.isEmpty || y.isEmpty) return false;
    return x == y;
  }

  static String? exclusionReason({
    required String productId,
    required String itemUrl,
    required Map<String, TodayRecommendExposureRecord> recordsById,
    required DateTime now,
  }) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    final rec = recordsById[id];
    if (rec == null) return null;
    if (rec.dismissedAt != null &&
        now.difference(rec.dismissedAt!) < dismissedSuppressDuration) {
      return 'dismissedRecently';
    }
    if (rec.shownAt != null &&
        now.difference(rec.shownAt!) < shownSuppressDuration) {
      return 'shownRecently';
    }
    for (final other in recordsById.values) {
      if (other.productId == id) continue;
      if (urlsLooselyEqual(other.itemUrl, itemUrl) &&
          other.dismissedAt != null &&
          now.difference(other.dismissedAt!) < dismissedSuppressDuration) {
        return 'dismissedUrlMatch';
      }
      if (urlsLooselyEqual(other.itemUrl, itemUrl) &&
          other.shownAt != null &&
          now.difference(other.shownAt!) < shownSuppressDuration) {
        return 'shownUrlMatch';
      }
    }
    return null;
  }

  static Map<String, TodayRecommendExposureRecord> mergeRecords(
    Iterable<TodayRecommendExposureRecord> records,
  ) {
    final out = <String, TodayRecommendExposureRecord>{};
    for (final r in records) {
      final id = r.productId.trim();
      if (id.isEmpty) continue;
      final prev = out[id];
      if (prev == null) {
        out[id] = r;
        continue;
      }
      out[id] = TodayRecommendExposureRecord(
        productId: id,
        itemUrl: r.itemUrl.isNotEmpty ? r.itemUrl : prev.itemUrl,
        shownAt: _latest(prev.shownAt, r.shownAt),
        dismissedAt: _latest(prev.dismissedAt, r.dismissedAt),
      );
    }
    return out;
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
