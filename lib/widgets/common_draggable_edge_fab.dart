import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// コメント画面以外で表示する右端収納型コメント FAB（半収納 ⇔ 展開）。
///
/// 内側に [Stack] を持ち、[Positioned] / [AnimatedPositioned] は必ずその [Stack] の直接の子とする。
class CommonDraggableEdgeFab extends StatefulWidget {
  const CommonDraggableEdgeFab({
    super.key,
    required this.shellTabIndex,
    required this.onCommentTap,
  });

  /// シェル下部ナビの選択インデックス。切り替わったら FAB は半収納へ戻す。
  final int shellTabIndex;

  final VoidCallback onCommentTap;

  /// 半収納時の幅（互換用・未使用）
  static const double peekWidth = 52;

  /// 右側はみ出し（互換用・未使用）
  static const double peekHiddenFromRightEdge = 26;

  /// 展開時の最小幅（互換用・未使用）
  static const double expandedWidth = 168;

  /// コメントFABの直径
  static const double fabSize = 48;

  static const double fabHeight = fabSize;

  static const double edgeMargin = 8;

  /// フッター直上からのオフセット（12〜16）
  static const double marginAboveBodyBottom = 14;

  static const double minGapAboveFooter = 12;

  /// 開閉アニメーション（180〜220ms）
  static const Duration openCloseDuration = Duration(milliseconds: 200);

  static const Curve openCloseCurve = Curves.easeOutCubic;

  /// FAB 上端の Y（body 左上基準）
  static const String prefTop = 'room_fab_dy';

  static const String prefDragHintSeen = 'room_fab_drag_hint_seen_v1';

/// 初回のみ「×で半収納」ヒントを表示したか
  static const String prefChevronHintSeen = 'room_fab_chevron_hint_seen_v1';

  /// コメントタブの＋FAB（正方形の一辺）
  static const double plusFabSize = 56;

  @override
  State<CommonDraggableEdgeFab> createState() => _CommonDraggableEdgeFabState();
}

class _CommonDraggableEdgeFabState extends State<CommonDraggableEdgeFab> {
  double? _fabTop;
  bool _prefsLoaded = false;
  bool _scheduledInitialFromLayout = false;

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
          content: Text('コメントへ移動。長押しで位置を調整できます'),
        ),
      );
    } catch (_) {}
  }

  double _clampTop(double t, double topInset, double h) =>
      t.clamp(_minTop(topInset), _maxTop(h));

  /// 右下固定（余白付き）
  double _leftForFab(double w) =>
      w - CommonDraggableEdgeFab.fabSize - CommonDraggableEdgeFab.edgeMargin;

  void _onTapComment() {
    if (!_prefsLoaded) return;
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

  static List<BoxShadow> get _fabShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 5,
          offset: const Offset(0, 1.5),
        ),
      ];

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

        final left = _leftForFab(w);

        final fab = Tooltip(
          message: 'コメント',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTapComment,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: (d) =>
                _onLongPressMoveUpdate(d, topInset, h),
            onLongPressEnd: (_) => _onLongPressEnd(topInset, h),
            onLongPressCancel: () => _onLongPressCancel(topInset, h),
            child: Container(
              width: CommonDraggableEdgeFab.fabSize,
              height: CommonDraggableEdgeFab.fabSize,
              decoration: BoxDecoration(
                color: HomeScreenColors.homeFabBlue,
                shape: BoxShape.circle,
                boxShadow: _fabShadow,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        );

        if (_verticalDragging) {
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned(left: left, top: top, child: fab),
            ],
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            AnimatedPositioned(
              duration: CommonDraggableEdgeFab.openCloseDuration,
              curve: CommonDraggableEdgeFab.openCloseCurve,
              left: left,
              top: top,
              child: fab,
            ),
          ],
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
      w -
          CommonDraggableEdgeFab.plusFabSize -
          CommonDraggableEdgeFab.edgeMargin;

  static List<BoxShadow> get _plusShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 5,
          offset: const Offset(0, 1.5),
        ),
      ];

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

        final fab = Tooltip(
          message: 'テンプレートを追加',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onPressed,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: (d) =>
                _onLongPressMoveUpdate(d, topInset, h),
            onLongPressEnd: (_) => _onLongPressEnd(topInset, h),
            onLongPressCancel: () =>
                _onLongPressCancel(topInset, h),
            child: AnimatedContainer(
              duration: CommonDraggableEdgeFab.openCloseDuration,
              curve: CommonDraggableEdgeFab.openCloseCurve,
              width: CommonDraggableEdgeFab.plusFabSize,
              height: CommonDraggableEdgeFab.plusFabSize,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
                boxShadow: _plusShadow,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 28,
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        );

        if (_verticalDragging) {
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned(left: left, top: top, child: fab),
            ],
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            AnimatedPositioned(
              duration: CommonDraggableEdgeFab.openCloseDuration,
              curve: CommonDraggableEdgeFab.openCloseCurve,
              left: left,
              top: top,
              child: fab,
            ),
          ],
        );
      },
    );
  }
}
