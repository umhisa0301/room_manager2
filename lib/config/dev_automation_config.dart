import 'package:flutter/foundation.dart' show kDebugMode;

/// 開発者向け自動検証モードのビルド時フラグ。
///
/// 有効化例:
/// `flutter run --dart-define=DEV_AUTOMATION_ENABLED=true`
/// `flutter build apk --dart-define=DEV_AUTOMATION_ENABLED=true`
///
/// 本番・profile ビルドでは [kDebugMode] が false のため、
/// dart-define が true でも UI / 処理は完全に無効化される。
abstract final class DevAutomationConfig {
  static const bool kDevAutomationDartDefineEnabled = bool.fromEnvironment(
    'DEV_AUTOMATION_ENABLED',
    defaultValue: false,
  );
}

/// 開発者向け自動検証モードを公開してよいかどうか。
///
/// - 本番 / profile ビルド: false（[kDebugMode] が false）
/// - debug かつ `--dart-define=DEV_AUTOMATION_ENABLED=true` のみ true
abstract final class DevAutomationFlags {
  static const bool isEnabled =
      kDebugMode && DevAutomationConfig.kDevAutomationDartDefineEnabled;
}

/// 自動検証モード専用画面・処理の入口で呼び出す保護関数。
/// 無効時は例外で即座に停止させる（Navigator.push 前など）。
void ensureDevAutomationAvailable() {
  if (!DevAutomationFlags.isEnabled) {
    throw StateError(
      'Dev automation is disabled. Requires kDebugMode and '
      '--dart-define=DEV_AUTOMATION_ENABLED=true for verification builds only.',
    );
  }
}
