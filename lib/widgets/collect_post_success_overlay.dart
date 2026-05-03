import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// コレ完了の軽い演出（上部バナー＋わずかなキラつき）。SnackBar だけにしないための UI。
void showCollectPostSuccessCelebration(
  BuildContext context, {
  required int todayOrdinal,
}) {
  if (!context.mounted) return;
  HapticFeedback.lightImpact();
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return _CollectPostSuccessCelebrationLayer(
        todayOrdinal: todayOrdinal,
        onDone: () {
          entry.remove();
        },
      );
    },
  );
  overlay.insert(entry);
  Timer(const Duration(milliseconds: 2600), () {
    if (entry.mounted) entry.remove();
  });
}

class _CollectPostSuccessCelebrationLayer extends StatefulWidget {
  const _CollectPostSuccessCelebrationLayer({
    required this.todayOrdinal,
    required this.onDone,
  });

  final int todayOrdinal;
  final VoidCallback onDone;

  @override
  State<_CollectPostSuccessCelebrationLayer> createState() =>
      _CollectPostSuccessCelebrationLayerState();
}

class _CollectPostSuccessCelebrationLayerState
    extends State<_CollectPostSuccessCelebrationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    final scale = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
    );
    final fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
    );

    return Positioned(
      left: 12,
      right: 12,
      top: top,
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(scale),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _SparklePainter(
                              progress: _ctrl.value,
                              color: AppColors.accentPrimary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.check_rounded,
                                color: RoomCollectSuccessColors.checkGreen,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'コレ完了！',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '直近24時間で ${widget.todayOrdinal}件目',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 22,
                            color:
                                AppColors.accentPrimary.withValues(alpha: 0.9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class RoomCollectSuccessColors {
  static const Color checkGreen = Color(0xFF2E7D32);
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final t = (progress * 1.4).clamp(0.0, 1.0);
    final spots = <Offset>[
      Offset(size.width * 0.12, size.height * 0.35),
      Offset(size.width * 0.88, size.height * 0.28),
      Offset(size.width * 0.72, size.height * 0.72),
    ];
    for (var i = 0; i < spots.length; i++) {
      final p = spots[i];
      final w = 4.0 + 10 * (1 - t) * (i + 1) * 0.25;
      canvas.drawCircle(p, w * 0.25, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
