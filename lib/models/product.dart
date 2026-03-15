import 'product_status.dart';

/// 商品管理の実体モデル。
/// 追加・編集・詳細画面で共通利用し、永続化時もこの形で保存する想定。
class Product {
  const Product({
    required this.id,
    required this.productName,
    required this.productUrl,
    this.imageUrl,
    this.memo,
    required this.tags,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.quickComment,
  });

  final String id;
  final String productName;
  final String productUrl;
  final String? imageUrl;
  final String? memo;
  final List<String> tags;
  final ProductStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? quickComment;

  /// 一覧用：URL やショップの短い表示（ドメインや先頭部分）
  String get displayUrlOrShop {
    if (productUrl.isEmpty) return '—';
    try {
      final uri = Uri.parse(productUrl);
      if (uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return productUrl.length > 30 ? '${productUrl.substring(0, 30)}…' : productUrl;
  }

  /// ローカル保存用 JSON に変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'productUrl': productUrl,
      'imageUrl': imageUrl,
      'memo': memo,
      'tags': tags,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'quickComment': quickComment,
    };
  }

  /// JSON から復元。不正・欠損時は null を返す（呼び出し側でガード）
  static Product? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final id = json['id'] as String?;
      final productName = json['productName'] as String?;
      final productUrl = json['productUrl'] as String?;
      if (id == null || id.isEmpty || productName == null || productUrl == null) {
        return null;
      }
      final createdAt = _parseDateTime(json['createdAt']);
      final updatedAt = _parseDateTime(json['updatedAt']);
      if (createdAt == null || updatedAt == null) return null;

      final tags = json['tags'];
      final tagList = tags is List<dynamic>
          ? tags.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
          : <String>[];

      return Product(
        id: id,
        productName: productName,
        productUrl: productUrl,
        imageUrl: json['imageUrl'] as String?,
        memo: json['memo'] as String?,
        tags: tagList,
        status: ProductStatusExtension.fromString(json['status'] as String?),
        createdAt: createdAt,
        updatedAt: updatedAt,
        quickComment: json['quickComment'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  Product copyWith({
    String? id,
    String? productName,
    String? productUrl,
    String? imageUrl,
    String? memo,
    List<String>? tags,
    ProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? quickComment,
  }) {
    return Product(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      productUrl: productUrl ?? this.productUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      memo: memo ?? this.memo,
      tags: tags ?? List.from(this.tags),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      quickComment: quickComment ?? this.quickComment,
    );
  }
}
