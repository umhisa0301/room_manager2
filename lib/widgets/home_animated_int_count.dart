import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 整数の変化時のみカウントアップ/ダウンする局所表示。
///
/// 初回は [value] を即表示し、同値 rebuild では再アニメーションしない。
/// reduce motion 時は [AppMotion.durationOf] 経由で即時表示。
class HomeAnimatedIntCount extends StatefulWidget {
  const HomeAnimatedIntCount({
    super.key,
    required this.value,
    required this.builder,
  });

  final int value;
  final Widget Function(BuildContext context, int displayValue) builder;

  @override
  State<HomeAnimatedIntCount> createState() => _HomeAnimatedIntCountState();
}

class _HomeAnimatedIntCountState extends State<HomeAnimatedIntCount> {
  late int _begin;

  @override
  void initState() {
    super.initState();
    _begin = widget.value;
  }

  @override
  void didUpdateWidget(covariant HomeAnimatedIntCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _begin = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.durationOf(context, AppMotion.emphasized);
    return TweenAnimationBuilder<int>(
      duration: duration,
      curve: AppMotion.standard,
      tween: IntTween(begin: _begin, end: widget.value),
      onEnd: () {
        // Duration.zero 時は build 中に同期発火するため setState しない。
        _begin = widget.value;
      },
      builder: (context, displayValue, child) {
        return widget.builder(context, displayValue);
      },
    );
  }
}
