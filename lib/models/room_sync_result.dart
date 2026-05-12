import 'rakuten_managed_product.dart';

/// [RoomSyncService] の1バッチあたりの集計（全件同期・履歴への拡張前提）。
class RoomSyncResult {
  const RoomSyncResult({
    required this.processedCount,
    required this.newlyCollectedCount,
    required this.roomUrlAddedCount,
    required this.skippedCount,
    required this.failedCount,
    this.failedRoomUrls = const [],
    this.fatalErrorMessage,
    this.listingCheckedCount = 0,
    this.listingSyncedSkipCount = 0,
    this.listingInitialCandidateCount = 0,
    this.additionalFetchStatusLabel = '不要',
    this.newlyCollectedSamples = const [],
    this.reactionHighlightSamples = const [],
    this.reactionsResyncedCount = 0,
    this.collectsExploreModeLabel = '',
    this.collectsPagesFetched = 0,
    this.collectsStopReason,
    this.collectsIncompleteExplore = false,
    this.collectsLastNextCursor,
  });

  /// 一覧段階で同期済み判定した件数（FINISH ログの processedChecked 相当）。
  final int listingCheckedCount;

  /// 一覧段階で「既に同期済み」によりスキップした件数。
  final int listingSyncedSkipCount;

  /// 初期HTML抽出で得た候補数（スクロール前の最初の塊）。
  final int listingInitialCandidateCount;

  /// 追加取得の状態（例: 不要 / 実行済み(API) / 失敗(API) / 未対応 …）。
  final String additionalFetchStatusLabel;

  /// 今バッチでコレ済に **新規追加** された商品のプレビュー（最大3件・UI用）。
  final List<RakutenManagedProduct> newlyCollectedSamples;

  /// 今バッチで確認し ROOM のいいね／コメントが付いていた商品（最大3件・UI用）。
  final List<RakutenManagedProduct> reactionHighlightSamples;

  /// 同一 ROOM キーで反応数のみ再同期した件数。
  final int reactionsResyncedCount;

  /// collects 探索モード（`normal` / `deep`）。未使用時は空文字。
  final String collectsExploreModeLabel;

  /// 今回の取り込み prepare で取得した collects API ページ数。
  final int collectsPagesFetched;

  /// collects 探索終了理由（`enoughItems` / `maxPagesReached` 等）。未使用時は null。
  final String? collectsStopReason;

  /// 通常モードでページ上限・連続既知打ち切りにより、未取り込みの掘り残しがある可能性がある。
  final bool collectsIncompleteExplore;

  /// 最後に得た collects の `nextAfterId`（ログ・再開用）。無ければ null。
  final String? collectsLastNextCursor;

  /// 実際に1件ずつ確認した ROOM 商品ページ数（最大10など）。
  final int processedCount;

  /// コレ済として新規行を追加した件数。
  final int newlyCollectedCount;

  /// 既存行に roomUrl（等）を追記した件数。
  final int roomUrlAddedCount;

  /// 同期不要（既に roomUrl 済み・同一商品に別ROOM紐付け済み等）でスキップした件数。
  final int skippedCount;

  /// 取得・解析・永続化に失敗した件数。
  final int failedCount;

  final List<String> failedRoomUrls;

  /// 一覧ページ取得など、バッチ全体を続行できないときのメッセージ（null なら致命的ではない）。
  final String? fatalErrorMessage;

  bool get hasFatalError =>
      fatalErrorMessage != null && fatalErrorMessage!.trim().isNotEmpty;
}
