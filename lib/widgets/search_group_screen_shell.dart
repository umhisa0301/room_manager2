import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';

/// 「探す」グループ画面向けの薄い共通シェル（背景・SafeArea・余白・任意の上部帯のみ）。
///
/// データ取得や状態管理は持たず、[child] を包むだけに留める。
class SearchGroupScreenShell extends StatelessWidget {
  const SearchGroupScreenShell({
    super.key,
    required this.child,
    this.backgroundColor,
    this.contentPadding,
    this.title,
    this.subtitle,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.maintainBottomViewPadding = true,
  });

  /// 土台の背景色。未指定時は楽天検索画面と同系の [HomeScreenColors.canvas]。
  final Color? backgroundColor;

  /// [SafeArea] 内側の共通パディング。未指定時は左右 [AppDimensions.screenPaddingH]、
  /// 上下 [AppDimensions.spacingSm]。
  final EdgeInsetsGeometry? contentPadding;

  /// 上部帯のタイトル（任意）。
  final String? title;

  /// 上部帯の補助文（任意）。
  final String? subtitle;

  final Widget child;

  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool maintainBottomViewPadding;

  bool get _hasHeaderBand {
    final t = title?.trim();
    final s = subtitle?.trim();
    return (t != null && t.isNotEmpty) || (s != null && s.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? HomeScreenColors.canvas;
    final pad =
        contentPadding ??
        const EdgeInsets.symmetric(
          horizontal: AppDimensions.screenPaddingH,
          vertical: AppDimensions.spacingSm,
        );

    return ColoredBox(
      color: bg,
      child: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: Padding(
          padding: pad,
          child: _hasHeaderBand
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchGroupHeaderBand(
                      title: title?.trim(),
                      subtitle: subtitle?.trim(),
                    ),
                    SizedBox(height: RakutenSearchScreenUi.gapSection),
                    Expanded(child: child),
                  ],
                )
              : SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

class _SearchGroupHeaderBand extends StatelessWidget {
  const _SearchGroupHeaderBand({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: RakutenSearchScreenUi.listFilterStripDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title!.isNotEmpty)
              Text(
                title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RakutenSearchScreenUi.sectionHeadingAccent(context),
              ),
            if (title != null &&
                title!.isNotEmpty &&
                subtitle != null &&
                subtitle!.isNotEmpty)
              const SizedBox(height: AppDimensions.spacingXs),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: RakutenSearchScreenUi.bodyCaption(context),
              ),
          ],
        ),
      ),
    );
  }
}
