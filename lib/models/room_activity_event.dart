import 'package:flutter/foundation.dart';

/// 商品・ROOM 活動向けのイベント種別（疑似 KPI / 連続日数の材料）。
enum RoomActivityEventType {
  candidateAdded,
  movedToCored,
  openedRakuten,
  feedbackLiked,
  feedbackSold,
  feedbackWeak,
  deleted,
}

/// 永続化可能な活動イベント1件。
@immutable
class RoomActivityEvent {
  const RoomActivityEvent({
    required this.id,
    required this.productId,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final RoomActivityEventType type;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
  };

  static RoomActivityEvent? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    try {
      final id = (m['id'] ?? '').toString().trim();
      final pid = (m['productId'] ?? '').toString().trim();
      if (id.isEmpty || pid.isEmpty) return null;
      final typeName = (m['type'] ?? '').toString().trim();
      final type = RoomActivityEventType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => RoomActivityEventType.openedRakuten,
      );
      final raw = m['createdAt']?.toString();
      if (raw == null || raw.isEmpty) return null;
      final at = DateTime.tryParse(raw);
      if (at == null) return null;
      return RoomActivityEvent(
        id: id,
        productId: pid,
        type: type,
        createdAt: at,
      );
    } catch (_) {
      return null;
    }
  }
}
