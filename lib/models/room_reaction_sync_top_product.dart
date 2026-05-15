/// 反応同期で「伸び」が大きかった商品（分析・UI サマリー用）。
class RoomReactionSyncTopProduct {
  const RoomReactionSyncTopProduct({
    required this.productId,
    required this.title,
    this.imageUrl = '',
    required this.roomLikeCount,
    required this.roomCommentCount,
    required this.previousLikeCount,
    required this.previousCommentCount,
    required this.deltaLike,
    required this.deltaComment,
  });

  final String productId;
  final String title;
  final String imageUrl;
  final int roomLikeCount;
  final int roomCommentCount;
  final int previousLikeCount;
  final int previousCommentCount;
  final int deltaLike;
  final int deltaComment;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'title': title,
        'imageUrl': imageUrl,
        'roomLikeCount': roomLikeCount,
        'roomCommentCount': roomCommentCount,
        'previousLikeCount': previousLikeCount,
        'previousCommentCount': previousCommentCount,
        'deltaLike': deltaLike,
        'deltaComment': deltaComment,
      };

  static RoomReactionSyncTopProduct? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final pid = (j['productId'] ?? '').toString().trim();
    if (pid.isEmpty) return null;
    int n(String k) => int.tryParse(j[k]?.toString() ?? '') ?? 0;
    return RoomReactionSyncTopProduct(
      productId: pid,
      title: (j['title'] ?? '').toString(),
      imageUrl: (j['imageUrl'] ?? '').toString(),
      roomLikeCount: n('roomLikeCount'),
      roomCommentCount: n('roomCommentCount'),
      previousLikeCount: n('previousLikeCount'),
      previousCommentCount: n('previousCommentCount'),
      deltaLike: n('deltaLike'),
      deltaComment: n('deltaComment'),
    );
  }
}
