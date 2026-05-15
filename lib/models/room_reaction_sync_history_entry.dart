import 'room_reaction_sync_top_product.dart';

/// 反応同期1回分の軽量履歴（分析画面向け・端末ローカル）。
class RoomReactionSyncHistoryEntry {
  const RoomReactionSyncHistoryEntry({
    required this.syncedAtIso,
    required this.checkedItems,
    required this.updatedItems,
    required this.likeIncreasedItems,
    required this.commentIncreasedItems,
    required this.unchangedItems,
    required this.stopReason,
    required this.hasNextCursor,
    required this.topReactedProducts,
  });

  final String syncedAtIso;
  final int checkedItems;
  final int updatedItems;
  final int likeIncreasedItems;
  final int commentIncreasedItems;
  final int unchangedItems;
  final String stopReason;
  final bool hasNextCursor;
  final List<RoomReactionSyncTopProduct> topReactedProducts;

  Map<String, dynamic> toJson() => {
        'syncedAt': syncedAtIso,
        'checkedItems': checkedItems,
        'updatedItems': updatedItems,
        'likeIncreasedItems': likeIncreasedItems,
        'commentIncreasedItems': commentIncreasedItems,
        'unchangedItems': unchangedItems,
        'stopReason': stopReason,
        'hasNextCursor': hasNextCursor,
        'topReactedProducts':
            topReactedProducts.map((e) => e.toJson()).toList(growable: false),
      };

  static RoomReactionSyncHistoryEntry? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final tops = <RoomReactionSyncTopProduct>[];
    final raw = j['topReactedProducts'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final p = RoomReactionSyncTopProduct.fromJson(e);
          if (p != null) tops.add(p);
        }
      }
    }
    return RoomReactionSyncHistoryEntry(
      syncedAtIso: (j['syncedAt'] ?? '').toString(),
      checkedItems: int.tryParse(j['checkedItems']?.toString() ?? '') ?? 0,
      updatedItems: int.tryParse(j['updatedItems']?.toString() ?? '') ?? 0,
      likeIncreasedItems:
          int.tryParse(j['likeIncreasedItems']?.toString() ?? '') ?? 0,
      commentIncreasedItems:
          int.tryParse(j['commentIncreasedItems']?.toString() ?? '') ?? 0,
      unchangedItems:
          int.tryParse(j['unchangedItems']?.toString() ?? '') ?? 0,
      stopReason: (j['stopReason'] ?? '').toString(),
      hasNextCursor: j['hasNextCursor'] == true,
      topReactedProducts: tops,
    );
  }
}
