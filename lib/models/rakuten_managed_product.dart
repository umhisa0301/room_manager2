import 'package:flutter/foundation.dart';

import 'rakuten_search_item.dart';

/// コレ済へ移した経路（投稿上限・分析の「投稿」カウントは [appPost] のみ）。
enum RakutenCoredActivitySource {
  appPost,
  roomImport,

  /// アプリ外などでコレ済にした経路（投稿カウント対象外）。
  manual,
}

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
    this.resolvedGenreName = '',
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.addedAt,
    required this.extractedUrl,
    required this.extractionStatus,
    required this.extractionErrorMessage,
    this.extractedAt,
    this.roomUrl = '',
    this.doneAt,
    this.feedbackLikedAt,
    this.feedbackSoldAt,
    this.feedbackWeakAt,
    this.isRoomSynced = false,
    this.roomSyncedAt,
    this.coredActivitySource = RakutenCoredActivitySource.appPost,
    this.roomPostedAt,
    this.importedAt,
    this.roomLikeCount,
    this.roomCommentCount,
    this.roomReactionUpdatedAt,
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

  /// コレ候補登録時点で検索一覧と同じルールで解決した日本語名
  /// （同梱JSON・親「その他」遡りを含む）。好みジャンル集計などの参照用。旧データは空。
  final String resolvedGenreName;
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

  /// 楽天ROOM の **商品ページ** URL（`room.rakuten.co.jp/...`。ROOM同期・「ROOMで見る」用）。
  /// [extractedUrl] は商品ページから XPath 抽出した **コレ導線URL** で別用途。
  final String roomUrl;

  /// コレ済に移した日時（候補時は null）。
  final DateTime? doneAt;

  /// ユーザー評価「反応よかった」を付けた日時。
  final DateTime? feedbackLikedAt;

  /// ユーザー評価「売れた」を付けた日時。
  final DateTime? feedbackSoldAt;

  /// ユーザー評価「微妙」を付けた日時。
  final DateTime? feedbackWeakAt;

  /// 楽天ROOM の商品ページ URL を同期済みとして確定したか（将来の履歴・再同期の拡張用）。
  final bool isRoomSynced;

  /// [isRoomSynced] を立てた日時（未同期は null）。
  final DateTime? roomSyncedAt;

  /// コレ済にした経路（投稿上限・分析の投稿カウントは [RakutenCoredActivitySource.appPost] のみ）。
  final RakutenCoredActivitySource coredActivitySource;

  /// 楽天ROOM上で実際に投稿された日時（取り込みでは未取得のことが多く null）。
  final DateTime? roomPostedAt;

  /// ROOM投稿取り込みなどでコレ済に入れた日時（アプリ側の取り込み基準）。
  final DateTime? importedAt;

  /// ROOM 商品ページ由来のいいね数（未取得は null、0 は取得結果が 0）。
  final int? roomLikeCount;

  /// ROOM 商品ページ由来のコメント数（未取得は null）。
  final int? roomCommentCount;

  /// [roomLikeCount] / [roomCommentCount] を最後に更新した日時。
  final DateTime? roomReactionUpdatedAt;

  /// アプリの「投稿として」カウントするコレ済か。
  bool get countsTowardPostedCollectMetrics {
    if (!RakutenManagedProduct.isMemberForStatusTab(
      this,
      RakutenManagedProductStatus.done,
    )) {
      return false;
    }
    return coredActivitySource == RakutenCoredActivitySource.appPost;
  }

  /// ブラウザで開くURL（アフィリエイトURLを優先）。
  String get browserLaunchUrl =>
      affiliateUrl.trim().isNotEmpty ? affiliateUrl.trim() : itemUrl;

  /// 一覧ジャンル行の「永続化名」向け（解決済み [resolvedGenreName] を優先）。
  String? get persistedGenreDisplayName {
    final r = resolvedGenreName.trim();
    if (r.isNotEmpty) return r;
    final g = genreName.trim();
    return g.isEmpty ? null : g;
  }

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
    String? resolvedGenreName,
    RakutenManagedProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? addedAt,
    String? extractedUrl,
    RakutenUrlExtractionStatus? extractionStatus,
    String? extractionErrorMessage,
    DateTime? extractedAt,
    bool clearExtractedAt = false,
    String? roomUrl,
    bool clearRoomUrl = false,
    DateTime? doneAt,
    bool clearDoneAt = false,
    DateTime? feedbackLikedAt,
    bool clearFeedbackLiked = false,
    DateTime? feedbackSoldAt,
    bool clearFeedbackSold = false,
    DateTime? feedbackWeakAt,
    bool clearFeedbackWeak = false,
    bool? isRoomSynced,
    DateTime? roomSyncedAt,
    bool clearRoomSyncedAt = false,
    RakutenCoredActivitySource? coredActivitySource,
    DateTime? roomPostedAt,
    bool clearRoomPostedAt = false,
    DateTime? importedAt,
    bool clearImportedAt = false,
    int? roomLikeCount,
    bool clearRoomLikeCount = false,
    int? roomCommentCount,
    bool clearRoomCommentCount = false,
    DateTime? roomReactionUpdatedAt,
    bool clearRoomReactionUpdatedAt = false,
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
      resolvedGenreName: resolvedGenreName ?? this.resolvedGenreName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedAt: addedAt ?? this.addedAt,
      extractedUrl: extractedUrl ?? this.extractedUrl,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      extractionErrorMessage:
          extractionErrorMessage ?? this.extractionErrorMessage,
      extractedAt: clearExtractedAt ? null : (extractedAt ?? this.extractedAt),
      roomUrl: clearRoomUrl ? '' : (roomUrl ?? this.roomUrl),
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
      isRoomSynced: isRoomSynced ?? this.isRoomSynced,
      roomSyncedAt: clearRoomSyncedAt
          ? null
          : (roomSyncedAt ?? this.roomSyncedAt),
      coredActivitySource: coredActivitySource ?? this.coredActivitySource,
      roomPostedAt: clearRoomPostedAt
          ? null
          : (roomPostedAt ?? this.roomPostedAt),
      importedAt: clearImportedAt ? null : (importedAt ?? this.importedAt),
      roomLikeCount: clearRoomLikeCount
          ? null
          : (roomLikeCount ?? this.roomLikeCount),
      roomCommentCount: clearRoomCommentCount
          ? null
          : (roomCommentCount ?? this.roomCommentCount),
      roomReactionUpdatedAt: clearRoomReactionUpdatedAt
          ? null
          : (roomReactionUpdatedAt ?? this.roomReactionUpdatedAt),
    );
  }

  factory RakutenManagedProduct.fromSearchItem(
    RakutenSearchItem item, {
    required RakutenManagedProductStatus status,
    DateTime? now,
    String resolvedGenreName = '',
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
      resolvedGenreName: resolvedGenreName,
      status: status,
      createdAt: t,
      updatedAt: t,
      addedAt: t,
      extractedUrl: '',
      extractionStatus: RakutenUrlExtractionStatus.notStarted,
      extractionErrorMessage: '',
      extractedAt: null,
      roomUrl: '',
      doneAt: null,
      feedbackLikedAt: null,
      feedbackSoldAt: null,
      feedbackWeakAt: null,
      isRoomSynced: false,
      roomSyncedAt: null,
      coredActivitySource: RakutenCoredActivitySource.appPost,
      roomPostedAt: null,
      importedAt: null,
      roomLikeCount: null,
      roomCommentCount: null,
      roomReactionUpdatedAt: null,
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
      'resolvedGenreName': resolvedGenreName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'extractedUrl': extractedUrl,
      'extractionStatus': extractionStatus.name,
      'extractionErrorMessage': extractionErrorMessage,
      'extractedAt': extractedAt?.toIso8601String(),
      'roomUrl': roomUrl,
      'doneAt': doneAt?.toIso8601String(),
      'feedbackLikedAt': feedbackLikedAt?.toIso8601String(),
      'feedbackSoldAt': feedbackSoldAt?.toIso8601String(),
      'feedbackWeakAt': feedbackWeakAt?.toIso8601String(),
      'isRoomSynced': isRoomSynced,
      'roomSyncedAt': roomSyncedAt?.toIso8601String(),
      'coredActivitySource': coredActivitySource.name,
      'roomPostedAt': roomPostedAt?.toIso8601String(),
      'importedAt': importedAt?.toIso8601String(),
      'roomLikeCount': roomLikeCount,
      'roomCommentCount': roomCommentCount,
      'roomReactionUpdatedAt': roomReactionUpdatedAt?.toIso8601String(),
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

    final isRoomSynced = json['isRoomSynced'] == true;
    DateTime? roomSyncedAt;
    final rsAt = json['roomSyncedAt']?.toString();
    if (rsAt != null && rsAt.isNotEmpty) {
      roomSyncedAt = parseDt(rsAt);
    }

    RakutenCoredActivitySource coredSource = RakutenCoredActivitySource.appPost;
    final srcRaw = json['coredActivitySource']?.toString().trim();
    if (srcRaw != null && srcRaw.isNotEmpty) {
      coredSource = RakutenCoredActivitySource.values.firstWhere(
        (e) => e.name == srcRaw,
        orElse: () => RakutenCoredActivitySource.appPost,
      );
    }

    DateTime? roomPostedAt;
    final rpAt = json['roomPostedAt']?.toString();
    if (rpAt != null && rpAt.isNotEmpty) {
      roomPostedAt = parseDt(rpAt);
    }

    DateTime? importedAt;
    final imAt = json['importedAt']?.toString();
    if (imAt != null && imAt.isNotEmpty) {
      importedAt = parseDt(imAt);
    }

    DateTime? roomReactionUpdatedAt;
    final ruAt = json['roomReactionUpdatedAt']?.toString();
    if (ruAt != null && ruAt.isNotEmpty) {
      roomReactionUpdatedAt = parseDt(ruAt);
    }

    int? readOptInt(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    final roomLikeCount = readOptInt('roomLikeCount');
    final roomCommentCount = readOptInt('roomCommentCount');

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
      resolvedGenreName: (json['resolvedGenreName'] ?? '').toString(),
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      addedAt: addedAt,
      extractedUrl: (json['extractedUrl'] ?? '').toString(),
      extractionStatus: extractionStatus,
      extractionErrorMessage: (json['extractionErrorMessage'] ?? '').toString(),
      extractedAt: extractedAt,
      roomUrl: (json['roomUrl'] ?? '').toString(),
      doneAt: doneAt,
      feedbackLikedAt: feedbackLikedAt,
      feedbackSoldAt: feedbackSoldAt,
      feedbackWeakAt: feedbackWeakAt,
      isRoomSynced: isRoomSynced,
      roomSyncedAt: roomSyncedAt,
      coredActivitySource: coredSource,
      roomPostedAt: roomPostedAt,
      importedAt: importedAt,
      roomLikeCount: roomLikeCount,
      roomCommentCount: roomCommentCount,
      roomReactionUpdatedAt: roomReactionUpdatedAt,
    );
  }
}
