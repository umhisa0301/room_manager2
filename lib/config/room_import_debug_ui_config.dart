import 'package:flutter/foundation.dart' show kDebugMode;

/// ROOM 取り込み UI の開発者向けデバッグ導線。
///
/// 通常の実機確認・リリースでは表示しない。
/// 有効化: `--dart-define=ROOM_IMPORT_DEBUG_UI=true`（debug ビルドのみ）
class RoomImportDebugUiConfig {
  RoomImportDebugUiConfig._();

  static const bool _flagEnabled = bool.fromEnvironment(
    'ROOM_IMPORT_DEBUG_UI',
    defaultValue: false,
  );

  static bool get showDebugActions => kDebugMode && _flagEnabled;
}
