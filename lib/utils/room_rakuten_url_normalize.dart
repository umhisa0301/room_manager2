/// ROOM 商品ページURLの照合用キー（ホスト小文字・末尾スラッシュ除去・クエリ除去）。
abstract final class RoomRakutenUrlNormalize {
  const RoomRakutenUrlNormalize._();

  static String normalizeRoomProductPageKey(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return '';
    var path = u.path;
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    return '${u.scheme}://${u.host.toLowerCase()}$path';
  }

  static bool isLikelyRoomProductPageUrl(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || !u.hasScheme) return false;
    final h = u.host.toLowerCase();
    return h == 'room.rakuten.co.jp' || h.endsWith('.room.rakuten.co.jp');
  }

  /// 楽天商品ページの安定URL（末尾スラッシュ付き）。
  static String canonicalItemRakutenUrl({
    required String shopCode,
    required String itemPathSegment,
  }) {
    final s = shopCode.trim();
    final i = itemPathSegment.trim();
    return 'https://item.rakuten.co.jp/$s/$i/';
  }
}
