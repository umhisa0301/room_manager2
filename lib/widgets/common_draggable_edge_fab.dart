import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// コメント画面以外で表示する共通コメント FAB（半収納 ⇔ 展開の2状態のみ）。
///
/// [LayoutBuilder] 配下では [Positioned] を使わず、Align + Transform.translate で配置する。
class CommonDraggableEdgeFab extends StatefulWidget {
  const CommonDraggableEdgeFab({
    super.key,
    required this.onCommentTap,
  });

  final VoidCallback onCommentTap;

  /// 半収納時の幅（44〜48）
  static const double peekWidth = 46;

  /// 展開時の幅（110〜130）
  static const double expandedWidth = 120;

  static const double fabHeight = 56;

  static const double borderRadiusLarge = 28;

  static const double edgeMargin = 8;

  /// 画面内に見える幅。幅46に対し約35%が右外＝約30%弱が隠れる（要件30〜40%隠す）
  static const double peekVisibleWidthOnScreen = 30;

  /// フッター（body 下端＝BottomNavigationBar 直上）からのオフセット（12〜16）
  static const double marginAboveBodyBottom = 14;

  static const double minGapAboveFooter = 12;

  /// FAB 上端の Y（body 左上基準）
  static const String prefTop = 'room_fab_dy';

  static const String prefDragHintSeen = 'room_fab_drag_hint_seen_v1';

  /// コメントタブの＋FAB（正方形の一辺）
  static const double plusFabSize = 56;

  @override
  State<CommonDraggableEdgeFab> createState() => _CommonDraggableEdgeFabState();
}

class _CommonDraggableEdgeFabState extends State<CommonDraggableEdgeFab> {
  double? _fabTop;
  bool _prefsLoaded = false;
  bool _scheduledInitialFromLayout = false;

  /// false ＝半収納、true ＝展開
  bool _expanded = false;

  bool _verticalDragging = false;
  double? _longPressLastY;
  bool _clampPostFramePending = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFirstHint());
  }

  double _minTop(double topInset) =>
      topInset + CommonDraggableEdgeFab.edgeMargin;

  double _maxTop(double h) =>
      h -
          CommonDraggableEdgeFab.fabHeight -
          CommonDraggableEdgeFab.minGapAboveFooter;

  double _defaultTop(double h) =>
      h -
          CommonDraggableEdgeFab.fabHeight -
          CommonDraggableEdgeFab.marginAboveBodyBottom;

  void _scheduleDefaultTop(double h, double topInset) {
    if (_scheduledInitialFromLayout) return;
    if (_fabTop != null) return;
    _scheduledInitialFromLayout = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t =
          _defaultTop(h).clamp(_minTop(topInset), _maxTop(h));
      setState(() => _fabTop = t);
      _persistTop(t);
    });
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      final dy = p.getDouble(CommonDraggableEdgeFab.prefTop);
      setState(() {
        _fabTop = dy;
        _prefsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _persistTop(double t) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(CommonDraggableEdgeFab.prefTop, t);
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
          content: Text('タップで展開。長押しのまま上下に動かして位置を変えられます'),
        ),
      );
    } catch (_) {}
  }

  double _clampTop(double t, double topInset, double h) =>
      t.clamp(_minTop(topInset), _maxTop(h));

  double _leftForPeek(double w) =>
      w - CommonDraggableEdgeFab.peekVisibleWidthOnScreen;

  double _leftForExpanded(double w) =>
      w -
          CommonDraggableEdgeFab.expandedWidth -
          CommonDraggableEdgeFab.edgeMargin;

  void _onTapComment(double topInset, double h) {
    if (!_prefsLoaded) return;
    if (!_expanded) {
      setState(() => _expanded = true);
      return;
    }
    widget.onCommentTap();
  }

  void _commitFabTop(double topInset, double h) {
    final t = _clampTop(_fabTop ?? _defaultTop(h), topInset, h);
    setState(() => _fabTop = t);
    _persistTop(t);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _verticalDragging = true;
    _longPressLastY = details.globalPosition.dy;
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    double topInset,
    double h,
  ) {
    if (!_verticalDragging) return;
    final y = details.globalPosition.dy;
    if (_longPressLastY != null) {
      final d = y - _longPressLastY!;
      final cur = _fabTop ?? _defaultTop(h);
      final next = (cur + d).clamp(_minTop(topInset), _maxTop(h));
      setState(() => _fabTop = next);
    }
    _longPressLastY = y;
  }

  void _onLongPressEnd(double topInset, double h) {
    _longPressLastY = null;
    if (!_verticalDragging) return;
    _verticalDragging = false;
    _commitFabTop(topInset, h);
  }

  void _onLongPressCancel(double topInset, double h) {
    _longPressLastY = null;
    if (!_verticalDragging) return;
    _verticalDragging = false;
    _commitFabTop(topInset, h);
  }

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
        final topInset = MediaQuery.paddingOf(context).top;

        if (!_prefsLoaded || w < 40 || h < 120) {
          return const SizedBox.shrink();
        }

        if (_fabTop == null) {
          _scheduleDefaultTop(h, topInset);
        }

        final top = _clampTop(_fabTop ?? _defaultTop(h), topInset, h);
        if (!_verticalDragging &&
            _fabTop != null &&
            (top - _fabTop!).abs() > 0.5 &&
            !_clampPostFramePending) {
          _clampPostFramePending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _clampPostFramePending = false;
            if (!mounted || _verticalDragging || _fabTop == null) return;
            final c = _clampTop(_fabTop!, topInset, h);
            if ((c - _fabTop!).abs() > 0.5) {
              setState(() => _fabTop = c);
              _persistTop(c);
            }
          });
        }

        final fabWidth =
            _expanded ? CommonDraggableEdgeFab.expandedWidth : CommonDraggableEdgeFab.peekWidth;
        final left = _expanded ? _leftForExpanded(w) : _leftForPeek(w);

        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(left, top),
            child: Tooltip(
              message: 'コメント',
              child: Material(
                elevation: _expanded ? 5 : 4,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: _expanded
                    ? BorderRadius.circular(CommonDraggableEdgeFab.borderRadiusLarge)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(
                          CommonDraggableEdgeFab.borderRadiusLarge,
                        ),
                        bottomLeft: Radius.circular(
                          CommonDraggableEdgeFab.borderRadiusLarge,
                        ),
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                color: AppColors.accentPrimary,
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _onTapComment(topInset, h),
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: (d) =>
                      _onLongPressMoveUpdate(d, topInset, h),
                  onLongPressEnd: (_) => _onLongPressEnd(topInset, h),
                  onLongPressCancel: () =>
                      _onLongPressCancel(topInset, h),
                  child: SizedBox(
                    width: fabWidth,
                    height: CommonDraggableEdgeFab.fabHeight,
                    child: _expanded
                        ? const _CommentExpandedPill()
                        : const _CommentPeekTab(),
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

/// コメントタブ専用の通常＋FAB。 `room_fab_dy` をコメント FAB と共有する。
class CommentTabPlusFab extends StatefulWidget {
  const CommentTabPlusFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  State<CommentTabPlusFab> createState() => _CommentTabPlusFabState();
}

class _CommentTabPlusFabState extends State<CommentTabPlusFab> {
  double? _fabTop;
  bool _prefsLoaded = false;
  bool _scheduledInitialFromLayout = false;
  bool _verticalDragging = false;
  double? _longPressLastY;
  bool _clampPostFramePending = false;

  static double _fabH() => CommonDraggableEdgeFab.plusFabSize;

  double _minTop(double topInset) =>
      topInset + CommonDraggableEdgeFab.edgeMargin;

  double _maxTop(double h) =>
      h - _fabH() - CommonDraggableEdgeFab.minGapAboveFooter;

  double _defaultTop(double h) =>
      h - _fabH() - CommonDraggableEdgeFab.marginAboveBodyBottom;

  void _scheduleDefaultTop(double h, double topInset) {
    if (_scheduledInitialFromLayout) return;
    if (_fabTop != null) return;
    _scheduledInitialFromLayout = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = _defaultTop(h).clamp(_minTop(topInset), _maxTop(h));
      setState(() => _fabTop = t);
      _persistTop(t);
    });
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      final dy = p.getDouble(CommonDraggableEdgeFab.prefTop);
      setState(() {
        _fabTop = dy;
        _prefsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _persistTop(double t) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(CommonDraggableEdgeFab.prefTop, t);
    } catch (_) {}
  }

  double _clampTop(double t, double topInset, double h) =>
      t.clamp(_minTop(topInset), _maxTop(h));

  void _commitFabTop(double topInset, double h) {
    final t = _clampTop(_fabTop ?? _defaultTop(h), topInset, h);
    setState(() => _fabTop = t);
    _persistTop(t);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _verticalDragging = true;
    _longPressLastY = details.globalPosition.dy;
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    double topInset,
    double h,
  ) {
    if (!_verticalDragging) return;
    final y = details.globalPosition.dy;
    if (_longPressLastY != null) {
      final d = y - _longPressLastY!;
      final cur = _fabTop ?? _defaultTop(h);
      final next = (cur + d).clamp(_minTop(topInset), _maxTop(h));
      setState(() => _fabTop = next);
    }
    _longPressLastY = y;
  }

  void _onLongPressEnd(double topInset, double h) {
    _longPressLastY = null;
    if (!_verticalDragging) return;
    _verticalDragging = false;
    _commitFabTop(topInset, h);
  }

  void _onLongPressCancel(double topInset, double h) {
    _longPressLastY = null;
    if (!_verticalDragging) return;
    _verticalDragging = false;
    _commitFabTop(topInset, h);
  }

  double _leftForPlus(double w) =>
      w - CommonDraggableEdgeFab.plusFabSize - CommonDraggableEdgeFab.edgeMargin;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

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
        final topInset = MediaQuery.paddingOf(context).top;

        if (!_prefsLoaded || w < 40 || h < 120) {
          return const SizedBox.shrink();
        }

        if (_fabTop == null) {
          _scheduleDefaultTop(h, topInset);
        }

        final top = _clampTop(_fabTop ?? _defaultTop(h), topInset, h);
        if (!_verticalDragging &&
            _fabTop != null &&
            (top - _fabTop!).abs() > 0.5 &&
            !_clampPostFramePending) {
          _clampPostFramePending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _clampPostFramePending = false;
            if (!mounted || _verticalDragging || _fabTop == null) return;
            final c = _clampTop(_fabTop!, topInset, h);
            if ((c - _fabTop!).abs() > 0.5) {
              setState(() => _fabTop = c);
              _persistTop(c);
            }
          });
        }

        final left = _leftForPlus(w);

        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(left, top),
            child: Tooltip(
              message: 'テンプレートを追加',
              child: Material(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                color: AppColors.accentPrimary,
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onPressed,
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: (d) =>
                      _onLongPressMoveUpdate(d, topInset, h),
                  onLongPressEnd: (_) => _onLongPressEnd(topInset, h),
                  onLongPressCancel: () =>
                      _onLongPressCancel(topInset, h),
                  child: SizedBox(
                    width: CommonDraggableEdgeFab.plusFabSize,
                    height: CommonDraggableEdgeFab.plusFabSize,
                    child: Icon(
                      Icons.add_rounded,
                      size: 28,
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

class _CommentPeekTab extends StatelessWidget {
  const _CommentPeekTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.chat_bubble_rounded,
        size: 22,
        color: AppColors.textOnAccent,
      ),
    );
  }
}

class _CommentExpandedPill extends StatelessWidget {
  const _CommentExpandedPill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_rounded,
            size: 20,
            color: AppColors.textOnAccent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'コメント',
                maxLines: 1,
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textOnAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
