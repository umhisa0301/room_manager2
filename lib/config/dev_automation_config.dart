import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;

/// 開発者向け自動検証モードのビルド時フラグ。
///
/// debug 有効化例:
/// `flutter run --dart-define=DEV_AUTOMATION_ENABLED=true`
/// `flutter build apk --debug --dart-define=DEV_AUTOMATION_ENABLED=true`
///
/// 内部検証用 release 有効化例（両方必須）:
/// `flutter build appbundle --release --dart-define=INTERNAL_RELEASE_AUTOMATION_ENABLED=true --dart-define=INTERNAL_RELEASE_AUTOMATION_TOKEN=room-internal-release-automation`
///
/// Google Play 申請用 release では上記 define を付けないこと。
abstract final class DevAutomationConfig {
  static const bool kDevAutomationDartDefineEnabled = bool.fromEnvironment(
    'DEV_AUTOMATION_ENABLED',
    defaultValue: false,
  );

  /// 内部検証用 release ビルド専用（Google Play 申請ビルドでは未指定のまま）。
  static const bool kInternalReleaseAutomationDartDefineEnabled =
      bool.fromEnvironment(
    'INTERNAL_RELEASE_AUTOMATION_ENABLED',
    defaultValue: false,
  );

  static const String kInternalReleaseAutomationToken = String.fromEnvironment(
    'INTERNAL_RELEASE_AUTOMATION_TOKEN',
    defaultValue: '',
  );

  /// 内部検証用 release で要求する固定トークン（dart-define と完全一致）。
  static const String expectedInternalReleaseAutomationToken =
      'room-internal-release-automation';

  /// release かつ enabled + 正しいトークンのときのみ true。
  static const bool kInternalReleaseAutomationEnabled =
      kReleaseMode &&
      kInternalReleaseAutomationDartDefineEnabled &&
      kInternalReleaseAutomationToken ==
          expectedInternalReleaseAutomationToken;
}

/// 開発者向け自動検証モードを公開してよいかどうか。
///
/// - debug かつ `--dart-define=DEV_AUTOMATION_ENABLED=true`
/// - release かつ内部検証用 define 2 つが正しく指定されたときのみ true
/// - profile / 通常 release / define なし: false
abstract final class DevAutomationFlags {
  static const bool isEnabled =
      (kDebugMode && DevAutomationConfig.kDevAutomationDartDefineEnabled) ||
      DevAutomationConfig.kInternalReleaseAutomationEnabled;
}

/// 自動検証モード専用画面・処理の入口で呼び出す保護関数。
/// 無効時は例外で即座に停止させる（Navigator.push 前など）。
void ensureDevAutomationAvailable() {
  if (!DevAutomationFlags.isEnabled) {
    throw StateError(
      'Dev automation is disabled. For debug builds use kDebugMode with '
      '--dart-define=DEV_AUTOMATION_ENABLED=true. For internal release builds use '
      '--dart-define=INTERNAL_RELEASE_AUTOMATION_ENABLED=true and '
      '--dart-define=INTERNAL_RELEASE_AUTOMATION_TOKEN='
      '${DevAutomationConfig.expectedInternalReleaseAutomationToken}.',
    );
  }
}
