import 'room_sync_log.dart';

/// ROOM同期カードのボタン表示ログ（Home / MyPage 共通）。
abstract final class RoomSyncButtonVisibility {
  static String jobLabel({
    required bool importing,
    required bool syncingReactions,
    required bool enrichingMetadata,
  }) {
    if (importing) return 'importingCollectedItems';
    if (syncingReactions) return 'syncingReactions';
    if (enrichingMetadata) return 'enrichingMetadata';
    return 'none';
  }

  static void logHiddenWhileBusy({
    required String screen,
    required String job,
    required String button,
  }) {
    roomSyncButtonVisibilityLog(
      'screen=$screen job=$job button=$button visible=false reason=hiddenWhileBusy',
    );
  }

  static void logIdleVisible({
    required String screen,
    required String button,
  }) {
    roomSyncButtonVisibilityLog(
      'screen=$screen job=none button=$button visible=true reason=idle',
    );
  }
}
