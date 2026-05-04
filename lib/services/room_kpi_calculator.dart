import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_activity_event.dart';

/// KPI 計算用の商品スナップショット（永続モデルと分離）。
@immutable
class RoomKpiProductRecord {
  const RoomKpiProductRecord({
    required this.productId,
    required this.title,
    this.candidateAddedAt,
    this.coredAt,
    this.isLiked = false,
    this.isSold = false,
    this.isWeak = false,
    this.categoryName,
  });

  final String productId;
  final String title;
  final DateTime? candidateAddedAt;
  final DateTime? coredAt;
  final bool isLiked;
  final bool isSold;
  final bool isWeak;
  final String? categoryName;

  static RoomKpiProductRecord fromManagedProduct(RakutenManagedProduct p) {
    return RoomKpiProductRecord(
      productId: p.productId,
      title: p.itemName,
      candidateAddedAt: p.addedAt,
      coredAt: p.doneAt,
      isLiked: p.feedbackLikedAt != null,
      isSold: p.feedbackSoldAt != null,
      isWeak: p.feedbackWeakAt != null,
      categoryName: p.genreId.trim().isEmpty ? null : p.genreId.trim(),
    );
  }

  /// ランキング用スコア: 売れた×3 + 反応×1 - 微妙×1
  int get reactionRankScore {
    return (isSold ? 3 : 0) + (isLiked ? 1 : 0) - (isWeak ? 1 : 0);
  }
}

@immutable
class RoomKpiSummary {
  const RoomKpiSummary({
    required this.todayCoredCount,
    required this.consecutiveActiveDays,
    required this.weeklyReactionScore,
    required this.weeklyActivityCount,
    required this.likedProductCount,
    required this.soldProductCount,
    required this.staleCandidateCount,
  });

  final int todayCoredCount;
  final int consecutiveActiveDays;
  final int weeklyReactionScore;
  final int weeklyActivityCount;
  final int likedProductCount;
  final int soldProductCount;
  final int staleCandidateCount;
}

class RoomKpiCalculator {
  RoomKpiCalculator._();

  static RoomKpiSummary calculate({
    required List<RoomKpiProductRecord> products,
    required List<RoomActivityEvent> events,
    DateTime? now,
  }) {
    final DateTime baseNow = now ?? DateTime.now();
    final DateTime todayStart = DateTime(
      baseNow.year,
      baseNow.month,
      baseNow.day,
    );
    final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));
    final DateTime weekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - 1),
    );

    final int todayCoredCount = events.where((event) {
      return event.type == RoomActivityEventType.movedToCored &&
          !event.createdAt.isBefore(todayStart) &&
          event.createdAt.isBefore(tomorrowStart);
    }).length;

    final int consecutiveActiveDays = _calculateConsecutiveActiveDays(
      events: events,
      baseDate: todayStart,
    );

    final List<RoomActivityEvent> weeklyEvents = events.where((event) {
      return !event.createdAt.isBefore(weekStart) &&
          event.createdAt.isBefore(tomorrowStart);
    }).toList();

    final int weeklyReactionScore = weeklyEvents.fold<int>(0, (score, event) {
      switch (event.type) {
        case RoomActivityEventType.feedbackLiked:
          return score + 1;
        case RoomActivityEventType.feedbackSold:
          return score + 3;
        case RoomActivityEventType.feedbackWeak:
          return score - 1;
        case RoomActivityEventType.candidateAdded:
        case RoomActivityEventType.movedToCored:
        case RoomActivityEventType.openedRakuten:
        case RoomActivityEventType.deleted:
          return score;
      }
    });

    final int weeklyActivityCount = weeklyEvents.length;

    final int likedProductCount = products
        .where((product) => product.isLiked)
        .length;
    final int soldProductCount = products
        .where((product) => product.isSold)
        .length;

    final int staleCandidateCount = products.where((product) {
      try {
        if (product.coredAt != null) return false;
        final added = product.candidateAddedAt;
        if (added == null) return false;
        final addedDay = DateTime(added.year, added.month, added.day);
        final days = todayStart.difference(addedDay).inDays;
        return days >= 3;
      } catch (_) {
        return false;
      }
    }).length;

    return RoomKpiSummary(
      todayCoredCount: todayCoredCount,
      consecutiveActiveDays: consecutiveActiveDays,
      weeklyReactionScore: weeklyReactionScore,
      weeklyActivityCount: weeklyActivityCount,
      likedProductCount: likedProductCount,
      soldProductCount: soldProductCount,
      staleCandidateCount: staleCandidateCount,
    );
  }

  static int _calculateConsecutiveActiveDays({
    required List<RoomActivityEvent> events,
    required DateTime baseDate,
  }) {
    final Set<DateTime> activeDates = events.map((event) {
      return DateTime(
        event.createdAt.year,
        event.createdAt.month,
        event.createdAt.day,
      );
    }).toSet();

    var streak = 0;
    var current = baseDate;

    while (activeDates.contains(current)) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    }

    return streak;
  }
}

@immutable
class HomeInsightItem {
  const HomeInsightItem({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionType,
  });

  final String title;
  final String message;
  final String actionLabel;

  /// `stale_candidates` | `weekly_activity` | `candidate_list` | `activity`
  final String actionType;
}

class HomeInsightBuilder {
  HomeInsightBuilder._();

  static List<HomeInsightItem> build({required RoomKpiSummary summary}) {
    final items = <HomeInsightItem>[];

    if (summary.staleCandidateCount > 0) {
      items.add(
        HomeInsightItem(
          title: '放置候補があります',
          message: '3日以上コレ済にしていない候補が${summary.staleCandidateCount}件あります。',
          actionLabel: '候補を見る',
          actionType: 'stale_candidates',
        ),
      );
    }

    if (summary.weeklyReactionScore >= 5) {
      items.add(
        const HomeInsightItem(
          title: '今週は反応が良いです',
          message: '評価ログの流れが良い状態です。分析タブで振り返れます。',
          actionLabel: '分析を見る',
          actionType: 'weekly_activity',
        ),
      );
    }

    if (summary.todayCoredCount == 0) {
      items.add(
        const HomeInsightItem(
          title: '今日のコレがまだありません',
          message: '1件だけでも進めると連続活動が伸びます。',
          actionLabel: 'コレ候補を見る',
          actionType: 'candidate_list',
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const HomeInsightItem(
          title: '順調です',
          message: 'このペースでROOM活動を続けていきましょう。',
          actionLabel: '分析を見る',
          actionType: 'activity',
        ),
      );
    }

    return items.take(3).toList(growable: false);
  }
}
