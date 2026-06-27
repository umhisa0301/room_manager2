import 'package:flutter/material.dart';

import 'tutorial_target_locator.dart';
import 'tutorial_tooltip_card.dart';

/// ハイライト＋説明カード。タップは基本的に透過し、説明カードのみ操作可能。
class TutorialSpotlightLayer extends StatefulWidget {
  const TutorialSpotlightLayer({
    super.key,
    required this.targetKey,
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.isLastStep,
    required this.onNext,
    required this.onSkip,
  });

  final Key? targetKey;
  final String title;
  final String body;
  final String stepLabel;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<TutorialSpotlightLayer> createState() => _TutorialSpotlightLayerState();
}

class _TutorialSpotlightLayerState extends State<TutorialSpotlightLayer> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareTarget());
  }

  @override
  void didUpdateWidget(covariant TutorialSpotlightLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepareTarget());
    }
  }

  Future<void> _prepareTarget() async {
    if (!mounted) return;
    final key = widget.targetKey;
    if (key != null) {
      await ensureTargetVisible(key);
      if (!mounted) return;
    }
    _refreshTargetRect();
  }

  void _refreshTargetRect() {
    if (!mounted) return;
    final key = widget.targetKey;
    final next = key == null ? null : globalRectForKey(key);
    if (_targetRect != next) {
      setState(() => _targetRect = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom + 72;
  final tooltipBottom = bottomInset + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          dismissible: false,
          color: Colors.transparent,
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _SpotlightPainter(
              screenSize: media.size,
              targetRect: _targetRect,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: tooltipBottom,
          child: TutorialTooltipCard(
            title: widget.title,
            body: widget.body,
            stepLabel: widget.stepLabel,
            isLastStep: widget.isLastStep,
            onNext: widget.onNext,
            onSkip: widget.onSkip,
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.screenSize,
    required this.targetRect,
  });

  final Size screenSize;
  final Rect? targetRect;

  static const _overlayColor = Color(0x99000000);
  static const _highlightPadding = 8.0;
  static const _highlightRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height));

  Path clipPath = overlayPath;
    final rect = targetRect;
    if (rect != null) {
      final padded = rect.inflate(_highlightPadding);
      final hole = RRect.fromRectAndRadius(
        padded,
        const Radius.circular(_highlightRadius),
      );
      clipPath = Path.combine(
        PathOperation.difference,
        overlayPath,
        Path()..addRRect(hole),
      );
    }

    canvas.drawPath(clipPath, Paint()..color = _overlayColor);

    if (rect != null) {
      final padded = rect.inflate(_highlightPadding);
      final border = RRect.fromRectAndRadius(
        padded,
        const Radius.circular(_highlightRadius),
      );
      canvas.drawRRect(
        border,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.screenSize != screenSize ||
        oldDelegate.targetRect != targetRect;
  }
}
