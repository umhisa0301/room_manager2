/// ① 投稿済み商品取り込みの collects 再開位置（プロフィール単位・端末ローカル）。
class RoomImportCursorState {
  const RoomImportCursorState({
    required this.roomProfileKey,
    this.nextImportCursor,
    this.lastImportStartedAt,
    this.lastImportFinishedAt,
    this.lastImportedCount = 0,
    this.lastProcessedRoomKey,
  });

  final String roomProfileKey;

  /// collects API の `afterId` 相当。未設定なら先頭から。
  final String? nextImportCursor;

  final String? lastImportStartedAt;
  final String? lastImportFinishedAt;
  final int lastImportedCount;
  final String? lastProcessedRoomKey;

  RoomImportCursorState copyWith({
    String? roomProfileKey,
    String? nextImportCursor,
    String? lastImportStartedAt,
    String? lastImportFinishedAt,
    int? lastImportedCount,
    String? lastProcessedRoomKey,
    bool clearNextImportCursor = false,
  }) {
    return RoomImportCursorState(
      roomProfileKey: roomProfileKey ?? this.roomProfileKey,
      nextImportCursor: clearNextImportCursor
          ? null
          : (nextImportCursor ?? this.nextImportCursor),
      lastImportStartedAt: lastImportStartedAt ?? this.lastImportStartedAt,
      lastImportFinishedAt: lastImportFinishedAt ?? this.lastImportFinishedAt,
      lastImportedCount: lastImportedCount ?? this.lastImportedCount,
      lastProcessedRoomKey:
          lastProcessedRoomKey ?? this.lastProcessedRoomKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'roomProfileKey': roomProfileKey,
    'nextImportCursor': nextImportCursor,
    'lastImportStartedAt': lastImportStartedAt,
    'lastImportFinishedAt': lastImportFinishedAt,
    'lastImportedCount': lastImportedCount,
    'lastProcessedRoomKey': lastProcessedRoomKey,
  };

  static RoomImportCursorState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final key = json['roomProfileKey']?.toString().trim() ?? '';
    if (key.isEmpty) return null;
    return RoomImportCursorState(
      roomProfileKey: key,
      nextImportCursor: _readJsonString(json, 'nextImportCursor'),
      lastImportStartedAt: _readJsonString(json, 'lastImportStartedAt'),
      lastImportFinishedAt: _readJsonString(json, 'lastImportFinishedAt'),
      lastImportedCount: _readJsonInt(json, 'lastImportedCount') ?? 0,
      lastProcessedRoomKey: _readJsonString(json, 'lastProcessedRoomKey'),
    );
  }

  static String? _readJsonString(Map<String, dynamic> json, String k) {
    final v = json[k]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static int? _readJsonInt(Map<String, dynamic> json, String k) {
    final v = json[k];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }
}

/// ② 反応数同期の collects 再開位置（プロフィール単位・端末ローカル）。
class RoomReactionSyncCursorState {
  const RoomReactionSyncCursorState({
    required this.roomProfileKey,
    this.nextReactionCursor,
    this.lastReactionSyncStartedAt,
    this.lastReactionSyncFinishedAt,
    this.lastFullReactionCycleCompletedAt,
    this.lastUpdatedCount = 0,
    this.lastProcessedRoomKey,
  });

  final String roomProfileKey;
  final String? nextReactionCursor;
  final String? lastReactionSyncStartedAt;
  final String? lastReactionSyncFinishedAt;
  final String? lastFullReactionCycleCompletedAt;
  final int lastUpdatedCount;
  final String? lastProcessedRoomKey;

  RoomReactionSyncCursorState copyWith({
    String? roomProfileKey,
    String? nextReactionCursor,
    String? lastReactionSyncStartedAt,
    String? lastReactionSyncFinishedAt,
    String? lastFullReactionCycleCompletedAt,
    int? lastUpdatedCount,
    String? lastProcessedRoomKey,
    bool clearNextReactionCursor = false,
  }) {
    return RoomReactionSyncCursorState(
      roomProfileKey: roomProfileKey ?? this.roomProfileKey,
      nextReactionCursor: clearNextReactionCursor
          ? null
          : (nextReactionCursor ?? this.nextReactionCursor),
      lastReactionSyncStartedAt:
          lastReactionSyncStartedAt ?? this.lastReactionSyncStartedAt,
      lastReactionSyncFinishedAt:
          lastReactionSyncFinishedAt ?? this.lastReactionSyncFinishedAt,
      lastFullReactionCycleCompletedAt:
          lastFullReactionCycleCompletedAt ??
          this.lastFullReactionCycleCompletedAt,
      lastUpdatedCount: lastUpdatedCount ?? this.lastUpdatedCount,
      lastProcessedRoomKey:
          lastProcessedRoomKey ?? this.lastProcessedRoomKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'roomProfileKey': roomProfileKey,
    'nextReactionCursor': nextReactionCursor,
    'lastReactionSyncStartedAt': lastReactionSyncStartedAt,
    'lastReactionSyncFinishedAt': lastReactionSyncFinishedAt,
    'lastFullReactionCycleCompletedAt': lastFullReactionCycleCompletedAt,
    'lastUpdatedCount': lastUpdatedCount,
    'lastProcessedRoomKey': lastProcessedRoomKey,
  };

  static RoomReactionSyncCursorState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final key = json['roomProfileKey']?.toString().trim() ?? '';
    if (key.isEmpty) return null;
    return RoomReactionSyncCursorState(
      roomProfileKey: key,
      nextReactionCursor: RoomImportCursorState._readJsonString(
        json,
        'nextReactionCursor',
      ),
      lastReactionSyncStartedAt: RoomImportCursorState._readJsonString(
        json,
        'lastReactionSyncStartedAt',
      ),
      lastReactionSyncFinishedAt: RoomImportCursorState._readJsonString(
        json,
        'lastReactionSyncFinishedAt',
      ),
      lastFullReactionCycleCompletedAt: RoomImportCursorState._readJsonString(
        json,
        'lastFullReactionCycleCompletedAt',
      ),
      lastUpdatedCount: RoomImportCursorState._readJsonInt(
            json,
            'lastUpdatedCount',
          ) ??
          0,
      lastProcessedRoomKey: RoomImportCursorState._readJsonString(
        json,
        'lastProcessedRoomKey',
      ),
    );
  }
}
