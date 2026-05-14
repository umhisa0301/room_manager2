import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/room_import_cursor_state.dart';
import '../services/room_import_collects_resume_store.dart';
import '../utils/room_sync_log.dart';

/// ROOM 取り込み／反応同期カーソルの永続化（SharedPreferences、将来の移行先を隠蔽）。
abstract class RoomSyncCursorRepository {
  Future<RoomImportCursorState?> loadImportCursor(String roomProfileKey);

  Future<void> saveImportCursor(RoomImportCursorState state);

  Future<void> clearImportCursor(String roomProfileKey, {required String reason});

  Future<RoomReactionSyncCursorState?> loadReactionCursor(String roomProfileKey);

  Future<void> saveReactionCursor(RoomReactionSyncCursorState state);

  Future<void> clearReactionCursor(String roomProfileKey, {required String reason});
}

class SharedPreferencesRoomSyncCursorRepository implements RoomSyncCursorRepository {
  SharedPreferencesRoomSyncCursorRepository(this._prefs);

  final SharedPreferences _prefs;

  static String _importKey(String profile) =>
      'room_sync_import_cursor_v1_${profile.trim().toLowerCase()}';

  static String _reactionKey(String profile) =>
      'room_sync_reaction_cursor_v1_${profile.trim().toLowerCase()}';

  @override
  Future<RoomImportCursorState?> loadImportCursor(String roomProfileKey) async {
    final key = roomProfileKey.trim();
    if (key.isEmpty) return null;
    final raw = _prefs.getString(_importKey(key))?.trim() ?? '';
    RoomImportCursorState? parsed;
    if (raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) {
          parsed = RoomImportCursorState.fromJson(m);
        }
      } catch (_) {}
    }
    if (parsed?.nextImportCursor != null &&
        parsed!.nextImportCursor!.trim().isNotEmpty) {
      roomImportCursorLog(
        'action=load cursor=${parsed.nextImportCursor} reason=json '
        'lastProcessedRoomKey=${parsed.lastProcessedRoomKey ?? '-'}',
      );
      return parsed;
    }
    final legacy = await RoomImportCollectsResumeStore.readAfterId(key);
    if (legacy != null && legacy.trim().isNotEmpty) {
      roomImportCursorLog(
        'action=load cursor=$legacy reason=migratedFromLegacyStore '
        'lastProcessedRoomKey=-',
      );
      return RoomImportCursorState(
        roomProfileKey: key,
        nextImportCursor: legacy.trim(),
      );
    }
    roomImportCursorLog(
      'action=load cursor=- reason=empty lastProcessedRoomKey=-',
    );
    return parsed;
  }

  @override
  Future<void> saveImportCursor(RoomImportCursorState state) async {
    final key = state.roomProfileKey.trim();
    if (key.isEmpty) return;
    final cursor = state.nextImportCursor?.trim();
    await _prefs.setString(_importKey(key), jsonEncode(state.toJson()));
    await RoomImportCollectsResumeStore.saveAfterId(key, cursor ?? '');
    roomImportCursorLog(
      'action=save cursor=${cursor ?? '-'} reason=persist '
      'lastProcessedRoomKey=${state.lastProcessedRoomKey ?? '-'}',
    );
  }

  @override
  Future<void> clearImportCursor(String roomProfileKey, {required String reason}) async {
    final key = roomProfileKey.trim();
    if (key.isEmpty) return;
    await _prefs.remove(_importKey(key));
    await RoomImportCollectsResumeStore.clearAfterId(key);
    roomImportCursorLog(
      'action=clear cursor=- reason=$reason lastProcessedRoomKey=-',
    );
  }

  @override
  Future<RoomReactionSyncCursorState?> loadReactionCursor(
    String roomProfileKey,
  ) async {
    final key = roomProfileKey.trim();
    if (key.isEmpty) return null;
    final raw = _prefs.getString(_reactionKey(key))?.trim() ?? '';
    if (raw.isEmpty) {
      roomReactionSyncCursorLog(
        'action=load cursor=- reason=empty lastProcessedRoomKey=-',
      );
      return null;
    }
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return null;
      final s = RoomReactionSyncCursorState.fromJson(m);
      roomReactionSyncCursorLog(
        'action=load cursor=${s?.nextReactionCursor ?? '-'} reason=json '
        'lastProcessedRoomKey=${s?.lastProcessedRoomKey ?? '-'}',
      );
      return s;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveReactionCursor(RoomReactionSyncCursorState state) async {
    final key = state.roomProfileKey.trim();
    if (key.isEmpty) return;
    await _prefs.setString(_reactionKey(key), jsonEncode(state.toJson()));
    roomReactionSyncCursorLog(
      'action=save cursor=${state.nextReactionCursor ?? '-'} reason=persist '
      'lastProcessedRoomKey=${state.lastProcessedRoomKey ?? '-'}',
    );
  }

  @override
  Future<void> clearReactionCursor(
    String roomProfileKey, {
    required String reason,
  }) async {
    final key = roomProfileKey.trim();
    if (key.isEmpty) return;
    await _prefs.remove(_reactionKey(key));
    roomReactionSyncCursorLog(
      'action=clear cursor=- reason=$reason lastProcessedRoomKey=-',
    );
  }
}
