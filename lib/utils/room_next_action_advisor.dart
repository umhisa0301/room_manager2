import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../services/room_import_metadata_enrichment.dart';
import 'room_reaction_analytics.dart';
import 'shop_display_resolve.dart';

enum RoomNextActionType {
  exploreSimilarProducts,
  exploreShopProducts,
  confirmProductMetadata,
  openTodayRecommendations,
  importRoomPosts,
  checkReactions,
}

class RoomNextAction {
  const RoomNextAction({
    required this.type,
    required this.title,
    required this.reason,
    required this.ctaLabel,
    this.genreId,
    this.shopCode,
    this.shopName,
    this.pendingMetadataCount = 0,
  });

  final RoomNextActionType type;
  final String title;
  final String reason;
  final String ctaLabel;
  final String? genreId;
  final String? shopCode;
  final String? shopName;
  final int pendingMetadataCount;
}

/// 分析タブ向け「次にやること」提案（最大3件）。
abstract final class RoomNextActionAdvisor {
  static List<RoomNextAction> suggest({
    required List<RakutenManagedProduct> items,
    required int candidateCount,
    required int todayPostCount,
  }) {
    final done = items
        .where(
          (e) =>
              e.status == RakutenManagedProductStatus.done &&
              e.roomUrl.trim().isNotEmpty,
        )
        .toList(growable: false);
    final withReaction = done.where(roomReactionAnalyticsIsEligible).toList();
    final pendingMeta = RoomImportMetadataEnrichmentService.countPendingEnrichment(
      items,
    );

    String? topGenreId;
    String? topGenreName;
    String? topShopCode;
    String? topShopName;
    if (withReaction.isNotEmpty) {
      final genreCounts = <String, int>{};
      final shopCounts = <String, int>{};
      for (final p in withReaction) {
        final gid = p.genreId.trim();
        if (gid.isNotEmpty) {
          genreCounts[gid] = (genreCounts[gid] ?? 0) + 1;
        }
        final sc = p.shopCode.trim();
        if (sc.isNotEmpty) {
          shopCounts[sc] = (shopCounts[sc] ?? 0) + 1;
        }
      }
      if (genreCounts.isNotEmpty) {
        final top = genreCounts.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        topGenreId = top.key;
        topGenreName = withReaction
            .firstWhere(
              (e) => e.genreId.trim() == topGenreId,
              orElse: () => withReaction.first,
            )
            .genreName
            .trim();
        if (topGenreName.isEmpty) {
          topGenreName = withReaction.first.resolvedGenreName.trim();
        }
      }
      if (shopCounts.isNotEmpty) {
        final top = shopCounts.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        topShopCode = top.key;
        final sample = withReaction.firstWhere(
          (e) => e.shopCode.trim() == topShopCode,
          orElse: () => withReaction.first,
        );
        topShopName = sample.shopName.trim();
      }
    }

    final actions = <RoomNextAction>[];

    if (withReaction.isEmpty && done.length < 5) {
      actions.add(
        const RoomNextAction(
          type: RoomNextActionType.importRoomPosts,
          title: 'まずはROOM投稿を取り込みましょう',
          reason: '反応を確認するには、取り込んだ投稿が必要です',
          ctaLabel: 'ROOM投稿を取り込む',
        ),
      );
    } else if (withReaction.isEmpty) {
      actions.add(
        const RoomNextAction(
          type: RoomNextActionType.checkReactions,
          title: '反応を確認してみましょう',
          reason: 'いいね・コメントの有無を最新化できます',
          ctaLabel: '反応を確認する',
        ),
      );
    }

    if (pendingMeta >= 3 &&
        actions.length < 3 &&
        !actions.any(
          (a) => a.type == RoomNextActionType.confirmProductMetadata,
        )) {
      actions.add(
        RoomNextAction(
          type: RoomNextActionType.confirmProductMetadata,
          title: '未確認の商品情報を確認しましょう',
          reason: 'ショップ名・ジャンル未確認の商品が$pendingMeta件あります',
          ctaLabel: '商品情報を確認する',
          pendingMetadataCount: pendingMeta,
        ),
      );
    }

    if (topGenreId != null &&
        topGenreId.isNotEmpty &&
        actions.length < 3) {
      final label = topGenreName != null && topGenreName.isNotEmpty
          ? topGenreName
          : '人気ジャンル';
      actions.add(
        RoomNextAction(
          type: RoomNextActionType.exploreSimilarProducts,
          title: '反応が多い商品に近いものを探しましょう',
          reason: '「$label」に反応が集まっています',
          ctaLabel: '似た商品を探す',
          genreId: topGenreId,
        ),
      );
    }

    if (topShopCode != null &&
        topShopCode.isNotEmpty &&
        actions.length < 3) {
      final label = ShopDisplayResolve.resolveDisplayShopName(
        shopName: topShopName,
        shopCode: topShopCode,
        screen: 'roomNextActionAdvisor',
      );
      final safeLabel = label == ShopDisplayResolve.unknownShopLabel
          ? '反応の多いショップ'
          : label;
      actions.add(
        RoomNextAction(
          type: RoomNextActionType.exploreShopProducts,
          title: '反応が多いショップの商品を増やしましょう',
          reason: label == ShopDisplayResolve.unknownShopLabel
              ? '反応が集まっている商品があります'
              : '「$safeLabel」の商品に反応が集まっています',
          ctaLabel: 'このショップで探す',
          shopCode: topShopCode,
          shopName: topShopName,
        ),
      );
    }

    if (candidateCount < 3 &&
        todayPostCount == 0 &&
        actions.length < 3) {
      actions.add(
        const RoomNextAction(
          type: RoomNextActionType.openTodayRecommendations,
          title: '今日は候補を3件追加しましょう',
          reason: '候補が少ないと運用しづらいため、おすすめから追加できます',
          ctaLabel: 'おすすめコレを見る',
        ),
      );
    }

    final out = actions.take(3).toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[ROOM_NEXT_ACTION_ADVISOR] candidateCount=$candidateCount '
        'doneCount=${done.length} itemsWithReaction=${withReaction.length} '
        'topGenre=${topGenreId ?? '-'} topShop=${topShopCode ?? '-'} '
        'pendingMetadataCount=$pendingMeta actions=${out.map((e) => e.type.name).join(',')}',
      );
    }
    return out;
  }
}
