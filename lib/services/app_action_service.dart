import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// クリップボードコピーや URL 起動など、画面横断のアクションを集約する。
class AppActionService {
  AppActionService._();

  static Future<void> copyText(
    BuildContext context, {
    required String text,
    String successMessage = 'コピーしました',
    VoidCallback? onSuccess,
  }) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    onSuccess?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }

  static Future<bool> openUrl(
    BuildContext context, {
    required String url,
    bool showUserFeedback = true,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (showUserFeedback && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URLが不正です')));
      }
      return false;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && showUserFeedback && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
      }
      return ok;
    } catch (_) {
      if (showUserFeedback && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
      }
      return false;
    }
  }

  static Future<void> copyThenOpenUrl(
    BuildContext context, {
    required String text,
    required String url,
    VoidCallback? onCopied,
  }) async {
    if (text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text.trim()));
    onCopied?.call();
    if (!context.mounted) return;
    final opened = await openUrl(context, url: url, showUserFeedback: false);
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'コピーしました。ブラウザで開きました'
              : 'コピーしました。URLを開けない場合は、ブラウザのアドレス欄に貼り付けてお試しください',
        ),
      ),
    );
  }
}
