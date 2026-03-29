import 'rakuten_search_item.dart';

/// 楽天ROOM周りでローカル管理する商品の状態（将来「コレ済」等を追加しやすい）。
enum RakutenManagedProductStatus {
  /// 未登録（永続化されていない想定。照合時は一覧に無い場合と同義）。
  none,

  /// コレ候補。
  candidate,

  /// コレ済（本ステップでは未使用。永続化スキーマのみ先に用意）。
  done,
}

/// 商品ページからの URL 抽出ジョブの状態。
enum RakutenUrlExtractionStatus {
  notStarted,
  extracting,
  success,
  failed,
}

/// 楽天検索結果を元にローカル保存する用の商品エンティティ（API生JSONは保持しない）。
class RakutenManagedProduct {
  RakutenManagedProduct({
    required this.productId,
    required this.itemName,
    required this.itemPrice,
    required this.itemUrl,
    required this.affiliateUrl,
    required this.imageUrl,
    required this.shopName,
    required this.shopCode,
    required this.shopUrl,
    required this.genreId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.extractedUrl = '',
    this.extractionErrorMessage = '',
    this.extractionStatus = RakutenUrlExtractionStatus.notStarted,
    this.extractedAt,
  });

  /// 楽天の itemCode（アプリ内の [RakutenSearchItem.productId] と同一）。
  final String productId;
  final String itemName;
  final int itemPrice;
  final String itemUrl;
  final String affiliateUrl;
  final String imageUrl;
  final String shopName;
  final String shopCode;
  final String shopUrl;
  final String genreId;
  final RakutenManagedProductStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String extractedUrl;
  final String extractionErrorMessage;
  final RakutenUrlExtractionStatus extractionStatus;
  final DateTime? extractedAt;

  /// ブラウザで開くURL（アフィリエイトURLを優先）。
  String get browserLaunchUrl =>
      affiliateUrl.trim().isNotEmpty ? affiliateUrl.trim() : itemUrl;

  RakutenManagedProduct copyWith({
    String? productId,
    String? itemName,
    int? itemPrice,
    String? itemUrl,
    String? affiliateUrl,
    String? imageUrl,
    String? shopName,
    String? shopCode,
    String? shopUrl,
    String? genreId,
    RakutenManagedProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? extractedUrl,
    String? extractionErrorMessage,
    RakutenUrlExtractionStatus? extractionStatus,
    DateTime? extractedAt,
  }) {
    return RakutenManagedProduct(
      productId: productId ?? this.productId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      itemUrl: itemUrl ?? this.itemUrl,
      affiliateUrl: affiliateUrl ?? this.affiliateUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      shopName: shopName ?? this.shopName,
      shopCode: shopCode ?? this.shopCode,
      shopUrl: shopUrl ?? this.shopUrl,
      genreId: genreId ?? this.genreId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extractedUrl: extractedUrl ?? this.extractedUrl,
      extractionErrorMessage:
          extractionErrorMessage ?? this.extractionErrorMessage,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      extractedAt: extractedAt ?? this.extractedAt,
    );
  }

  factory RakutenManagedProduct.fromSearchItem(
    RakutenSearchItem item, {
    required RakutenManagedProductStatus status,
    RakutenUrlExtractionStatus initialExtractionStatus =
        RakutenUrlExtractionStatus.extracting,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    return RakutenManagedProduct(
      productId: item.productId,
      itemName: item.itemName,
      itemPrice: item.itemPrice,
      itemUrl: item.itemUrl,
      affiliateUrl: item.affiliateUrl,
      imageUrl: item.imageUrl,
      shopName: item.shopName,
      shopCode: item.shopCode,
      shopUrl: item.shopUrl,
      genreId: item.genreId,
      status: status,
      createdAt: t,
      updatedAt: t,
      extractedUrl: '',
      extractionErrorMessage: '',
      extractionStatus: initialExtractionStatus,
      extractedAt: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'itemUrl': itemUrl,
      'affiliateUrl': affiliateUrl,
      'imageUrl': imageUrl,
      'shopName': shopName,
      'shopCode': shopCode,
      'shopUrl': shopUrl,
      'genreId': genreId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'extractedUrl': extractedUrl,
      'extractionErrorMessage': extractionErrorMessage,
      'extractionStatus': extractionStatus.name,
      if (extractedAt != null) 'extractedAt': extractedAt!.toIso8601String(),
    };
  }

  static RakutenUrlExtractionStatus _parseExtractionStatus(String? raw) {
    return RakutenUrlExtractionStatus.values.firstWhere(
      (e) => e.name == (raw ?? '').toString(),
      orElse: () => RakutenUrlExtractionStatus.notStarted,
    );
  }

  static RakutenManagedProduct? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final productId = (json['productId'] ?? '').toString().trim();
    if (productId.isEmpty) return null;
    final itemName = (json['itemName'] ?? '').toString();
    final itemUrl = (json['itemUrl'] ?? '').toString();
    final createdRaw = json['createdAt']?.toString();
    final updatedRaw = json['updatedAt']?.toString();
    if (createdRaw == null ||
        createdRaw.isEmpty ||
        updatedRaw == null ||
        updatedRaw.isEmpty) {
      return null;
    }
    DateTime? parseDt(String s) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final createdAt = parseDt(createdRaw);
    final updatedAt = parseDt(updatedRaw);
    if (createdAt == null || updatedAt == null) return null;

    final status = RakutenManagedProductStatus.values.firstWhere(
      (e) => e.name == (json['status'] ?? '').toString(),
      orElse: () => RakutenManagedProductStatus.candidate,
    );

    DateTime? extractedAt;
    final extRaw = json['extractedAt']?.toString();
    if (extRaw != null && extRaw.isNotEmpty) {
      extractedAt = parseDt(extRaw);
    }

    return RakutenManagedProduct(
      productId: productId,
      itemName: itemName,
      itemPrice: (json['itemPrice'] as num?)?.toInt() ?? 0,
      itemUrl: itemUrl,
      affiliateUrl: (json['affiliateUrl'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      shopName: (json['shopName'] ?? '').toString(),
      shopCode: (json['shopCode'] ?? '').toString(),
      shopUrl: (json['shopUrl'] ?? '').toString(),
      genreId: (json['genreId'] ?? '').toString(),
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      extractedUrl: (json['extractedUrl'] ?? '').toString(),
      extractionErrorMessage: (json['extractionErrorMessage'] ?? '').toString(),
      extractionStatus: _parseExtractionStatus(
        json['extractionStatus']?.toString(),
      ),
      extractedAt: extractedAt,
    );
  }
}
