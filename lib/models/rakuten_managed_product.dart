import 'package:flutter/foundation.dart';

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
enum RakutenUrlExtractionStatus { notStarted, extracting, success, failed }

/// 楽天検索結果を元にローカル保存する用の商品エンティティ（API生JSONは保持しない）。
class RakutenManagedProduct {
  const RakutenManagedProduct({
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
    this.genreName = '',
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.addedAt,
    required this.extractedUrl,
    required this.extractionStatus,
    required this.extractionErrorMessage,
    this.extractedAt,
    this.doneAt,
    this.feedbackLikedAt,
    this.feedbackSoldAt,
    this.feedbackWeakAt,
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

  /// 楽天API由来のジャンル名（保存時にあれば）。旧データは空のことがある。
  final String genreName;
  final RakutenManagedProductStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// コレ候補として登録した日時。
  final DateTime addedAt;

  /// XPath 等で抽出した URL（未抽出時は空）。
  final String extractedUrl;
  final RakutenUrlExtractionStatus extractionStatus;
  final String extractionErrorMessage;
  final DateTime? extractedAt;

  /// コレ済に移した日時（候補時は null）。
  final DateTime? doneAt;

  /// ユーザー評価「反応よかった」を付けた日時。
  final DateTime? feedbackLikedAt;

  /// ユーザー評価「売れた」を付けた日時。
  final DateTime? feedbackSoldAt;

  /// ユーザー評価「微妙」を付けた日時。
  final DateTime? feedbackWeakAt;

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
    String? genreName,
    RakutenManagedProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? addedAt,
    String? extractedUrl,
    RakutenUrlExtractionStatus? extractionStatus,
    String? extractionErrorMessage,
    DateTime? extractedAt,
    bool clearExtractedAt = false,
    DateTime? doneAt,
    bool clearDoneAt = false,
    DateTime? feedbackLikedAt,
    bool clearFeedbackLiked = false,
    DateTime? feedbackSoldAt,
    bool clearFeedbackSold = false,
    DateTime? feedbackWeakAt,
    bool clearFeedbackWeak = false,
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
      genreName: genreName ?? this.genreName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedAt: addedAt ?? this.addedAt,
      extractedUrl: extractedUrl ?? this.extractedUrl,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      extractionErrorMessage:
          extractionErrorMessage ?? this.extractionErrorMessage,
      extractedAt: clearExtractedAt ? null : (extractedAt ?? this.extractedAt),
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      feedbackLikedAt: clearFeedbackLiked
          ? null
          : (feedbackLikedAt ?? this.feedbackLikedAt),
      feedbackSoldAt: clearFeedbackSold
          ? null
          : (feedbackSoldAt ?? this.feedbackSoldAt),
      feedbackWeakAt: clearFeedbackWeak
          ? null
          : (feedbackWeakAt ?? this.feedbackWeakAt),
    );
  }

  factory RakutenManagedProduct.fromSearchItem(
    RakutenSearchItem item, {
    required RakutenManagedProductStatus status,
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
      genreName: item.genreName,
      status: status,
      createdAt: t,
      updatedAt: t,
      addedAt: t,
      extractedUrl: '',
      extractionStatus: RakutenUrlExtractionStatus.notStarted,
      extractionErrorMessage: '',
      extractedAt: null,
      doneAt: null,
      feedbackLikedAt: null,
      feedbackSoldAt: null,
      feedbackWeakAt: null,
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
      'genreName': genreName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'extractedUrl': extractedUrl,
      'extractionStatus': extractionStatus.name,
      'extractionErrorMessage': extractionErrorMessage,
      'extractedAt': extractedAt?.toIso8601String(),
      'doneAt': doneAt?.toIso8601String(),
      'feedbackLikedAt': feedbackLikedAt?.toIso8601String(),
      'feedbackSoldAt': feedbackSoldAt?.toIso8601String(),
      'feedbackWeakAt': feedbackWeakAt?.toIso8601String(),
    };
  }

  static RakutenUrlExtractionStatus _parseExtractionStatus(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) {
      return RakutenUrlExtractionStatus.notStarted;
    }
    return RakutenUrlExtractionStatus.values.firstWhere(
      (e) => e.name == t,
      orElse: () => RakutenUrlExtractionStatus.notStarted,
    );
  }

  /// [RakutenManagedProductProvider.sortedItemsForStatus] と同一のタブ所属判定。
  static bool isMemberForStatusTab(
    RakutenManagedProduct e,
    RakutenManagedProductStatus status,
  ) {
    if (e.status == status) return true;
    if (e.status == RakutenManagedProductStatus.none) {
      if (status == RakutenManagedProductStatus.done && e.doneAt != null) {
        return true;
      }
      if (status == RakutenManagedProductStatus.candidate && e.doneAt == null) {
        return true;
      }
    }
    return false;
  }

  static int _readItemPrice(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      return int.tryParse(raw.trim()) ?? 0;
    }
    return 0;
  }

  static RakutenManagedProduct? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return _fromJsonImpl(json);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ROOMコレ診断] RakutenManagedProduct.fromJson 失敗: $e\n$st');
      }
      return null;
    }
  }

  static RakutenManagedProduct? _fromJsonImpl(Map<String, dynamic> json) {
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

    var addedAt = createdAt;
    final addRaw = json['addedAt']?.toString();
    if (addRaw != null && addRaw.isNotEmpty) {
      final a = parseDt(addRaw);
      if (a != null) {
        addedAt = a;
      }
    }

    DateTime? extractedAt;
    final extAt = json['extractedAt']?.toString();
    if (extAt != null && extAt.isNotEmpty) {
      extractedAt = parseDt(extAt);
    }

    DateTime? doneAt;
    final dAt = json['doneAt']?.toString();
    if (dAt != null && dAt.isNotEmpty) {
      doneAt = parseDt(dAt);
    }

    DateTime? feedbackLikedAt;
    final fl = json['feedbackLikedAt']?.toString();
    if (fl != null && fl.isNotEmpty) {
      feedbackLikedAt = parseDt(fl);
    }
    DateTime? feedbackSoldAt;
    final fs = json['feedbackSoldAt']?.toString();
    if (fs != null && fs.isNotEmpty) {
      feedbackSoldAt = parseDt(fs);
    }
    DateTime? feedbackWeakAt;
    final fw = json['feedbackWeakAt']?.toString();
    if (fw != null && fw.isNotEmpty) {
      feedbackWeakAt = parseDt(fw);
    }

    final statusRaw = (json['status'] ?? '').toString().trim();
    var status = RakutenManagedProductStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => RakutenManagedProductStatus.candidate,
    );
    if (status == RakutenManagedProductStatus.none) {
      status = doneAt != null
          ? RakutenManagedProductStatus.done
          : RakutenManagedProductStatus.candidate;
    }

    final extRaw = (json['extractionStatus']?.toString() ?? '').trim();
    final extractionStatus = extRaw.isNotEmpty
        ? _parseExtractionStatus(extRaw)
        : RakutenUrlExtractionStatus.notStarted;

    return RakutenManagedProduct(
      productId: productId,
      itemName: itemName,
      itemPrice: _readItemPrice(json['itemPrice']),
      itemUrl: itemUrl,
      affiliateUrl: (json['affiliateUrl'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      shopName: (json['shopName'] ?? '').toString(),
      shopCode: (json['shopCode'] ?? '').toString(),
      shopUrl: (json['shopUrl'] ?? '').toString(),
      genreId: (json['genreId'] ?? '').toString(),
      genreName: (json['genreName'] ?? '').toString(),
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      addedAt: addedAt,
      extractedUrl: (json['extractedUrl'] ?? '').toString(),
      extractionStatus: extractionStatus,
      extractionErrorMessage: (json['extractionErrorMessage'] ?? '').toString(),
      extractedAt: extractedAt,
      doneAt: doneAt,
      feedbackLikedAt: feedbackLikedAt,
      feedbackSoldAt: feedbackSoldAt,
      feedbackWeakAt: feedbackWeakAt,
    );
  }
}
