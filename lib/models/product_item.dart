/// 商品管理で扱う1件の商品データ。
/// 仮データ・実データ共通で同じ型を使い、後でリポジトリと連携しやすくする。
class ProductItem {
  const ProductItem({
    required this.id,
    this.imageUrl,
    required this.name,
    required this.shopOrUrl,
    required this.tags,
    required this.status,
    this.hasComment = false,
  });

  final String id;
  /// 画像URL。null の場合はプレースホルダー表示。
  final String? imageUrl;
  final String name;
  /// ショップ名またはURLの短い表示用文字列。
  final String shopOrUrl;
  final List<String> tags;
  /// 表示用ステータス（候補・コレ済・アーカイブなど）。
  final String status;
  /// コメント有無（将来の余白設計用）。
  final bool hasComment;
}
