/// [RakutenManagedProductRepository.persistRoomCollectedFromRoomPage] の結果。
enum RoomCollectedPersistKind {
  /// 同一 ROOM 商品ページは既に保存済み。
  roomPageAlreadySynced,

  /// shopCode+itemCode は登録済みで、roomUrl も埋まっており追記不要。
  alreadyCollectedSkip,

  /// 既存行に roomUrl（や不足メタ）を追記した。
  updatedRoomUrlOnly,

  /// コレ済として新規行を追加した。
  insertedNewCollected,

  /// デモモードでは永続化しない。
  demoUnsupported,
}
