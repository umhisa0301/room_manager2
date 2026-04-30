import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// 全画面共通 FAB の動作モード（コメント遷移 / テンプレ追加）。
enum CommonFabMode {
  /// コメントタブへ遷移する。
  comment,

  /// テンプレート追加画面を開く。
  addTemplate,
}

/// 下部ナビの上に重なる ROOM 用メイン FAB。位置・収納状態を SharedPreferences に保存する。
class CommonDraggableEdgeFab extends StatefulWidget {
  const CommonDraggableEdgeFab({
    super.key,
    required this.mode,
    required this.onCommentTap,
    required this.onAddTemplateTap,
  });

  final CommonFabMode mode;
  final VoidCallback onCommentTap;
  final VoidCallback onAddTemplateTap;

  static const double fabSize = 64;
  static const double borderRadius = 20;
  static const double edgeMargin = 8;
  static const double peekVisible = 22;
  static const double collapseEdgePx = 28;

  /// SharedPreferences キー（座標は展開時の left / top、論理ピクセル）。
  static const String prefDx = 'room_fab_dx';
  static const String prefDy = 'room_fab_dy';
  static const String prefCollapsed = 'room_fab_collapsed';
  static const String prefDragHintSeen = 'room_fab_drag_hint_seen_v1';

  @override
  State<CommonDraggableEdgeFab> createState() => _CommonDraggableEdgeFabState();
}

class _CommonDraggableEdgeFabState extends State<CommonDraggableEdgeFab> {
  double? _expandedLeft;
  double? _expandedTop;
  bool _collapsed = false;
  bool _prefsLoaded = false;
  bool _scheduledInitialFromLayout = false;

  Offset? _longPressLastGlobal;
  bool _longPressDragging = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFirstHint());
  }

  void _scheduleDefaultPosition(double maxLeft, double maxTop) {
    if (_scheduledInitialFromLayout) return;
    if (_expandedLeft != null || _expandedTop != null) return;
    _scheduledInitialFromLayout = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _expandedLeft = maxLeft;
        _expandedTop = maxTop;
      });
      _persistGeometry();
    });
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      final dx = p.getDouble(CommonDraggableEdgeFab.prefDx);
      final dy = p.getDouble(CommonDraggableEdgeFab.prefDy);
      setState(() {
        _expandedLeft = dx;
        _expandedTop = dy;
        _collapsed = p.getBool(CommonDraggableEdgeFab.prefCollapsed) ?? false;
        _prefsLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _prefsLoaded = true);
      }
    }
  }

  Future<void> _persistGeometry() async {
    try {
      final p = await SharedPreferences.getInstance();
      final el = _expandedLeft;
      final et = _expandedTop;
      if (el != null) {
        await p.setDouble(CommonDraggableEdgeFab.prefDx, el);
      }
      if (et != null) {
        await p.setDouble(CommonDraggableEdgeFab.prefDy, et);
      }
      await p.setBool(CommonDraggableEdgeFab.prefCollapsed, _collapsed);
    } catch (_) {}
  }

  Future<void> _maybeShowFirstHint() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (p.getBool(CommonDraggableEdgeFab.prefDragHintSeen) == true) {
        return;
      }
      await p.setBool(CommonDraggableEdgeFab.prefDragHintSeen, true);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('長押しで移動、右端に寄せると収納できます'),
        ),
      );
    } catch (_) {}
  }

  void _expandWithBounds(double maxLeft, double maxTop) {
    setState(() {
      _collapsed = false;
      _expandedLeft = (_expandedLeft ?? maxLeft).clamp(
        CommonDraggableEdgeFab.edgeMargin,
        maxLeft,
      );
      _expandedTop = (_expandedTop ?? maxTop).clamp(
        CommonDraggableEdgeFab.edgeMargin,
        maxTop,
      );
    });
    _persistGeometry();
  }

  void _handleTap(double maxLeft, double maxTop) {
    if (!_prefsLoaded) return;
    if (_collapsed) {
      _expandWithBounds(maxLeft, maxTop);
      return;
    }
    if (widget.mode == CommonFabMode.comment) {
      widget.onCommentTap();
    } else {
      widget.onAddTemplateTap();
    }
  }

  void _onLongPressStart(
    LongPressStartDetails details,
    double maxLeft,
    double maxTop,
  ) {
    if (_collapsed) {
      _expandWithBounds(maxLeft, maxTop);
    }
    _longPressDragging = true;
    _longPressLastGlobal = details.globalPosition;
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    double maxLeft,
    double maxTop,
  ) {
    if (!_longPressDragging || _longPressLastGlobal == null) return;
    final delta = details.globalPosition - _longPressLastGlobal!;
    _longPressLastGlobal = details.globalPosition;
    var el = _expandedLeft ?? maxLeft;
    var et = _expandedTop ?? maxTop;
    el = (el + delta.dx).clamp(CommonDraggableEdgeFab.edgeMargin, maxLeft);
    et = (et + delta.dy).clamp(CommonDraggableEdgeFab.edgeMargin, maxTop);
    setState(() {
      _expandedLeft = el;
      _expandedTop = et;
    });
  }

  void _onLongPressEnd(LongPressEndDetails details, double w, double h) {
    if (!_longPressDragging) return;
    _longPressDragging = false;
    _longPressLastGlobal = null;
    final maxLeft = w -
        CommonDraggableEdgeFab.fabSize -
        CommonDraggableEdgeFab.edgeMargin;
    final maxTop = h -
        CommonDraggableEdgeFab.fabSize -
        CommonDraggableEdgeFab.edgeMargin;
    var el = _expandedLeft ?? maxLeft;
    var et = _expandedTop ?? maxTop;
    el = el.clamp(CommonDraggableEdgeFab.edgeMargin, maxLeft);
    et = et.clamp(CommonDraggableEdgeFab.edgeMargin, maxTop);
    final rightGap = w - (el + CommonDraggableEdgeFab.fabSize);
    var nextCollapsed = false;
    if (rightGap < CommonDraggableEdgeFab.collapseEdgePx) {
      nextCollapsed = true;
    } else if (rightGap < CommonDraggableEdgeFab.fabSize * 0.35) {
      el = maxLeft;
    }
    setState(() {
      _expandedLeft = el;
      _expandedTop = et;
      _collapsed = nextCollapsed;
    });
    _persistGeometry();
  }

  void _onLongPressCancel() {
    _longPressDragging = false;
    _longPressLastGlobal = null;
  }

  IconData get _icon => widget.mode == CommonFabMode.comment
      ? Icons.chat_bubble_rounded
      : Icons.add_comment_rounded;

  String get _tooltip => widget.mode == CommonFabMode.comment
      ? 'コメント'
      : 'テンプレートを追加';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final kb = MediaQuery.viewInsetsOf(context).bottom;
        final screenH = MediaQuery.sizeOf(context).height;
        if (kb > screenH * 0.2) {
          return const SizedBox.shrink();
        }

        final w = constraints.maxWidth;
        final h = (constraints.maxHeight - kb).clamp(0.0, double.infinity);
        final maxLeft = w -
            CommonDraggableEdgeFab.fabSize -
            CommonDraggableEdgeFab.edgeMargin;
        final maxTop = h -
            CommonDraggableEdgeFab.fabSize -
            CommonDraggableEdgeFab.edgeMargin;

        if (!_prefsLoaded || maxLeft < CommonDraggableEdgeFab.edgeMargin) {
          return const SizedBox.shrink();
        }

        if (_expandedLeft == null && _expandedTop == null) {
          _scheduleDefaultPosition(maxLeft, maxTop);
        }

        var el = _expandedLeft ?? maxLeft;
        var et = _expandedTop ?? maxTop;
        el = el.clamp(CommonDraggableEdgeFab.edgeMargin, maxLeft);
        et = et.clamp(CommonDraggableEdgeFab.edgeMargin, maxTop);

        final collapsedLeft =
            (w - CommonDraggableEdgeFab.peekVisible).clamp(
          CommonDraggableEdgeFab.edgeMargin,
          w - CommonDraggableEdgeFab.edgeMargin,
        );
        final showLeft = _collapsed ? collapsedLeft : el;
        final showTop = et;

        // Positioned は Stack の直接の子にしか置けない。このウィジェットは Stack の子として
        // LayoutBuilder 内に載るため、Align + Transform.translate で同じ座標を再現する。
        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(showLeft, showTop),
            child: Tooltip(
              message: _tooltip,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _handleTap(maxLeft, maxTop),
                onHorizontalDragUpdate: (d) {
                  if (!_collapsed) return;
                  if (d.delta.dx < -3) {
                    _expandWithBounds(maxLeft, maxTop);
                  }
                },
                onLongPressStart: (d) =>
                    _onLongPressStart(d, maxLeft, maxTop),
                onLongPressMoveUpdate: (d) =>
                    _onLongPressMoveUpdate(d, maxLeft, maxTop),
                onLongPressEnd: (d) => _onLongPressEnd(d, w, h),
                onLongPressCancel: _onLongPressCancel,
                child: Material(
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      CommonDraggableEdgeFab.borderRadius,
                    ),
                  ),
                  color: AppColors.accentPrimary,
                  child: SizedBox(
                    width: CommonDraggableEdgeFab.fabSize,
                    height: CommonDraggableEdgeFab.fabSize,
                    child: Icon(
                      _icon,
                      size: 30,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
