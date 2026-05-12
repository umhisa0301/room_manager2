/// ROOM 取り込みメタ補完の **検証モード**（楽天API を1件成功させるまでの実験用）。
///
/// 有効時は [RoomImportMetadataEnrichmentService] が **固定 productId 1件のみ** を処理し、
/// パターン A→B→C を順に試します（セッション内のブロック・成功パターン記憶あり）。
///
/// ビルド例:
/// `--dart-define=ROOM_IMPORT_ENRICH_VERIFY=true`
class RoomImportEnrichmentVerifyConfig {
  RoomImportEnrichmentVerifyConfig._();

  static const bool enabled = bool.fromEnvironment(
    'ROOM_IMPORT_ENRICH_VERIFY',
    defaultValue: false,
  );

  /// 補完対象に限定する `RakutenManagedProduct.productId`（完全一致）。
  /// 複合 ID の場合は末尾 `:4901085161999` でもマッチさせる（`_verifyRowEligible`）。
  static const String fixedProductId = String.fromEnvironment(
    'ROOM_IMPORT_ENRICH_VERIFY_PRODUCT_ID',
    defaultValue: '4901085161999',
  );

  /// パターン C 用キーワード（店舗・商品に合わせて変更可）。
  static const String patternCKeyword = String.fromEnvironment(
    'ROOM_IMPORT_ENRICH_VERIFY_PATTERN_C_KEYWORD',
    defaultValue: 'タリーズコーヒー',
  );
}
