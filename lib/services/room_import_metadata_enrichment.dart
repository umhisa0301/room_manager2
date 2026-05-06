/// Phase 3 向けプレースホルダ: ROOM取り込み済みコレのメタデータを **バッチで** API 補完する処理をここに集約する想定。
///
/// 現状の取り込み直後補完は [RakutenSearchRepository.fetchFirstItemForRoomImportEnrichment] を
/// [RoomSyncService] / [RoomCollectedRegisterService] から直接呼び出す。
abstract final class RoomImportMetadataEnrichmentBatch {
  RoomImportMetadataEnrichmentBatch._();
}
