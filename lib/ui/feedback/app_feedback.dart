import 'package:flutter/material.dart';

import '../../app_messenger.dart';
import '../../theme/app_theme.dart';

/// SnackBar の見た目トーン。
enum AppFeedbackTone { success, error, info }

/// 小規模な共通 SnackBar / Feedback ヘルパー。
///
/// 業務処理・Analytics・Clipboard・Navigation は扱わない。
abstract final class AppFeedback {
  AppFeedback._();

  /// 短い成功（約2秒）。
  static const Duration durationShortSuccess = Duration(milliseconds: 2000);

  /// 通常情報（約3秒）。
  static const Duration durationInfo = Duration(milliseconds: 3000);

  /// エラー（約4秒）。
  static const Duration durationError = Duration(milliseconds: 4000);

  /// 成功フィードバック（local messenger）。
  static void success(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      tone: AppFeedbackTone.success,
      duration: duration,
      action: action,
    );
  }

  /// エラーフィードバック（local messenger）。
  static void error(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      tone: AppFeedbackTone.error,
      duration: duration,
      action: action,
    );
  }

  /// 情報フィードバック（local messenger）。
  static void info(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      tone: AppFeedbackTone.info,
      duration: duration,
      action: action,
    );
  }

  /// root [ScaffoldMessenger] で成功を表示する。
  static void successRoot({
    required String message,
    BuildContext? context,
    Duration? duration,
    SnackBarAction? action,
  }) {
    showRoot(
      context: context,
      message: message,
      tone: AppFeedbackTone.success,
      duration: duration,
      action: action,
    );
  }

  /// root [ScaffoldMessenger] でエラーを表示する。
  static void errorRoot({
    required String message,
    BuildContext? context,
    Duration? duration,
    SnackBarAction? action,
  }) {
    showRoot(
      context: context,
      message: message,
      tone: AppFeedbackTone.error,
      duration: duration,
      action: action,
    );
  }

  /// root [ScaffoldMessenger] で情報を表示する。
  static void infoRoot({
    required String message,
    BuildContext? context,
    Duration? duration,
    SnackBarAction? action,
  }) {
    showRoot(
      context: context,
      message: message,
      tone: AppFeedbackTone.info,
      duration: duration,
      action: action,
    );
  }

  /// local [ScaffoldMessenger]（[context] 近傍）へ表示する。
  static void show(
    BuildContext context, {
    required String message,
    AppFeedbackTone tone = AppFeedbackTone.info,
    Duration? duration,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    showOnMessenger(
      messenger,
      message: message,
      tone: tone,
      duration: duration,
      action: action,
    );
  }

  /// root messenger へ表示する。未準備時は [context] の local にフォールバック。
  static void showRoot({
    BuildContext? context,
    required String message,
    AppFeedbackTone tone = AppFeedbackTone.info,
    Duration? duration,
    SnackBarAction? action,
  }) {
    final messenger =
        appRootScaffoldMessengerKey.currentState ??
        (context != null ? ScaffoldMessenger.maybeOf(context) : null);
    if (messenger == null) return;
    showOnMessenger(
      messenger,
      message: message,
      tone: tone,
      duration: duration,
      action: action,
    );
  }

  /// 指定した [ScaffoldMessengerState] へ表示する。
  ///
  /// 表示前に現在の SnackBar を [ScaffoldMessengerState.removeCurrentSnackBar]
  /// で置換し、連続操作時のキュー積み上がりを抑える。
  static void showOnMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    AppFeedbackTone tone = AppFeedbackTone.info,
    Duration? duration,
    SnackBarAction? action,
  }) {
    final text = message.trim();
    if (text.isEmpty) return;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      _buildSnackBar(
        message: text,
        tone: tone,
        duration: duration ?? _defaultDuration(tone),
        action: action,
      ),
    );
  }

  static Duration _defaultDuration(AppFeedbackTone tone) {
    return switch (tone) {
      AppFeedbackTone.success => durationShortSuccess,
      AppFeedbackTone.info => durationInfo,
      AppFeedbackTone.error => durationError,
    };
  }

  static SnackBar _buildSnackBar({
    required String message,
    required AppFeedbackTone tone,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final (Color background, IconData icon) = switch (tone) {
      AppFeedbackTone.success => (
        AppColors.success,
        Icons.check_circle_outline,
      ),
      AppFeedbackTone.error => (AppColors.error, Icons.error_outline),
      AppFeedbackTone.info => (AppColors.textPrimary, Icons.info_outline),
    };

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: background,
      action: action,
      content: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
