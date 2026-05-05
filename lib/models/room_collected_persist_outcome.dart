import 'room_collected_persist_kind.dart';

/// [RakutenManagedProductRepository.persistRoomCollectedFromRoomPage] の戻り。
class RoomCollectedPersistOutcome {
  const RoomCollectedPersistOutcome({
    required this.kind,
    this.productId,
  });

  final RoomCollectedPersistKind kind;

  /// 新規 or 更新後の [RakutenManagedProduct.productId]。不要な場合は null。
  final String? productId;
}
