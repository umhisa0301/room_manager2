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
