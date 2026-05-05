import 'rakuten_managed_product.dart';

/// 将来のコレ済ソート用キー（UIは未接続）。
abstract final class RoomColleAdvancedDoneSortKey {
  static const String roomLikeCountDesc = 'roomLikeCountDesc';
}

/// 将来のコレ済フィルター用キー（UIは未接続）。
abstract final class RoomColleAdvancedDoneFilterKey {
  static const String hasRoomReaction = 'hasRoomReaction';
  static const String hasRoomUrl = 'hasRoomUrl';
}

/// [RoomColleAdvancedDoneSortKey] / [RoomColleAdvancedDoneFilterKey] の評価ヘルパ。
extension RakutenManagedProductRoomColleAdvancedQuery on RakutenManagedProduct {
  bool matchesAdvancedDoneFilter(String key) {
    switch (key) {
      case RoomColleAdvancedDoneFilterKey.hasRoomUrl:
        return roomUrl.trim().isNotEmpty;
      case RoomColleAdvancedDoneFilterKey.hasRoomReaction:
        return roomLikeCount != null || roomCommentCount != null;
      default:
        return true;
    }
  }
}

/// [RoomColleAdvancedDoneSortKey.roomLikeCountDesc] 向け比較。
int compareRoomColleDoneRoomLikeCountDesc(
  RakutenManagedProduct a,
  RakutenManagedProduct b,
) {
  final la = a.roomLikeCount;
  final lb = b.roomLikeCount;
  if (la == null && lb == null) return 0;
  if (la == null) return 1;
  if (lb == null) return -1;
  final c = lb.compareTo(la);
  if (c != 0) return c;
  return a.productId.compareTo(b.productId);
}
