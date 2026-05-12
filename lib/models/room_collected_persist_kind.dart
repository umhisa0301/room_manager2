/// [RakutenManagedProductRepository.persistRoomCollectedFromRoomPage] の結果。
enum RoomCollectedPersistKind {
  /// 同一 ROOM 商品ページは既に保存済み（反応数のみ更新する場合は [roomReactionsUpdated]）。
  roomPageAlreadySynced,

  /// 同一 ROOM キーで反応数・同期時刻のみ更新した（楽天APIなし）。
  roomReactionsUpdated,

  /// shopCode+itemCode は登録済みで、roomUrl も埋まっており追記不要。
  alreadyCollectedSkip,

  /// 既存行に roomUrl（や不足メタ）を追記した。
  updatedRoomUrlOnly,

  /// コレ済として新規行を追加した。
  insertedNewCollected,

  /// デモモードでは永続化しない。
  demoUnsupported,
}
