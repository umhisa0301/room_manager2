/// クローズドテスト専用デモモードのビルド時フラグ。
///
/// 有効化例:
/// `flutter run --dart-define=DEMO_MODE=true`
/// `flutter build apk --dart-define=DEMO_MODE=true`
///
/// 本番ビルドでは未指定または false を前提とし、UI/遷移を出さない。
const bool kDemoModeEnabled = bool.fromEnvironment(
  'DEMO_MODE',
  defaultValue: false,
);

/// クローズドテスト専用機能を公開してよいかどうか。
///
/// - 本番ビルド: false（デモ UI / デモロジックを非活性）
/// - クローズドテストビルド: true（`--dart-define=DEMO_MODE=true` の時のみ）
const bool kClosedTestDemoAvailable = kDemoModeEnabled;

/// URLから追加のユーザー向け入口を表示するか（処理コードは残す）。
///
/// E2E 等の検証ビルドのみ有効化:
/// `--dart-define=SHOW_URL_ADD_ENTRY_POINT=true`
const bool showUrlAddEntryPoint = bool.fromEnvironment(
  'SHOW_URL_ADD_ENTRY_POINT',
  defaultValue: false,
);

/// デモ専用画面・処理の入口で呼び出す保護関数。
/// 本番で誤って到達した場合は例外で即座に停止させる。
void ensureClosedTestDemoAvailable() {
  if (!kClosedTestDemoAvailable) {
    throw StateError(
      'Closed-test demo is disabled. Build with --dart-define=DEMO_MODE=true for test builds only.',
    );
  }
}
