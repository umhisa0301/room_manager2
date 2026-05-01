import 'dart:async';

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

/// 下部ナビの上に重なる ROOM 用メイン FAB。
/// 右端スナップ・垂直位置の永続化。コメントモードはピークタブ ⇔ ピル型展開を切り替え。
///
/// [LayoutBuilder] 配下では [Positioned] を使わず、Align + Transform.translate で配置する。
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

  /// ピーク時の幅（縦長タブ）
  static const double peekWidth = 52;

  /// 展開ピル時の幅
  static const double expandedWidth = 140;

  static const double fabHeight = 56;

  /// 左側の丸み（ピル・ピーク共通で大きめ）
  static const double borderRadiusLarge = 28;

  static const double edgeMargin = 8;

  /// 画面右端からピーク時に見える幅（幅52の約35%）
  static const double peekVisibleFromRight = 18;

  /// フッター（body 下端＝BottomNavigationBar 直上）からのオフセット
  static const double marginAboveBodyBottom = 14;

  /// body 下端との最低ギャップ
  static const double minGapAboveFooter = 12;

  /// SharedPreferences: FAB 上端の Y（body 左上基準・論理ピクセル）。
  /// 旧版の `room_fab_dy` と同じキーで互換維持。
  static const String prefTop = 'room_fab_dy';

  static const String prefDragHintSeen = 'room_fab_drag_hint_seen_v1';

  @override
  State<CommonDraggableEdgeFab> createState() => _CommonDraggableEdgeFabState();
}

class _CommonDraggableEdgeFabState extends State<CommonDraggableEdgeFab> {
  double? _fabTop;
  bool _prefsLoaded = false;
  bool _scheduledInitialFromLayout = false;

  /// コメントモードのみ: true ＝ピル展開、false ＝右端ピーク
  bool _pillExpanded = false;

  Timer? _autoPeekTimer;

  bool _verticalDragging = false;
  double _dragStartTop = 0;
  double? _longPressLastY;
  bool _clampPostFramePending = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFirstHint());
  }

  @override
  void didUpdateWidget(covariant CommonDraggableEdgeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _autoPeekTimer?.cancel();
      // ホームで展開したピルがコメントタブの追加FABに持ち越されないようにする
      _pillExpanded = false;
    }
  }

  @override
  void dispose() {
    _autoPeekTimer?.cancel();
    super.dispose();
  }

  double _minTop(double topInset) =>
      topInset + CommonDraggableEdgeFab.edgeMargin;

  double _maxTop(double h) =>
      h - CommonDraggableEdgeFab.fabHeight - CommonDraggableEdgeFab.minGapAboveFooter;

  double _defaultTop(double h) =>
      h -
      CommonDraggableEdgeFab.fabHeight -
      CommonDraggableEdgeFab.marginAboveBodyBottom;

  void _scheduleDefaultTop(double h) {
    if (_scheduledInitialFromLayout) return;
    if (_fabTop != null) return;
    _scheduledInitialFromLayout = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = _defaultTop(h).clamp(_minTop(MediaQuery.paddingOf(context).top), _maxTop(h));
      setState(() => _fabTop = t);
      _persistTop();
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

  Future<void> _persistTop() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = _fabTop;
      if (t != null) {
        await p.setDouble(CommonDraggableEdgeFab.prefTop, t);
      }
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
          content: Text('タップで展開・右端に沿って表示。縦にドラッグで移動できます'),
        ),
      );
    } catch (_) {}
  }

  void _scheduleAutoPeek() {
    _autoPeekTimer?.cancel();
    if (widget.mode != CommonFabMode.comment) return;
    if (!_pillExpanded) return;
    _autoPeekTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _pillExpanded = false);
      _persistTop();
    });
  }

  double _clampTop(double t, double topInset, double h) =>
      t.clamp(_minTop(topInset), _maxTop(h));

  /// 保存済み top を現在の高さでクリップ（回転・端末変更）
  double _correctTop(double? stored, double topInset, double h) {
    if (stored == null) return _defaultTop(h);
    return _clampTop(stored, topInset, h);
  }

  double _leftForPeek(double w) =>
      w - CommonDraggableEdgeFab.peekVisibleFromRight;

  double _leftForExpanded(double w) =>
      w - CommonDraggableEdgeFab.expandedWidth - CommonDraggableEdgeFab.edgeMargin;

  void _onTapComment(double topInset, double h) {
    if (!_prefsLoaded) return;
    if (!_pillExpanded) {
      setState(() => _pillExpanded = true);
      _scheduleAutoPeek();
      return;
    }
    _autoPeekTimer?.cancel();
    widget.onCommentTap();
  }

  void _onTapAdd() {
    if (!_prefsLoaded) return;
    widget.onAddTemplateTap();
  }

  void _expandPillFromPeek() {
    if (widget.mode != CommonFabMode.comment) return;
    if (_pillExpanded) return;
    setState(() => _pillExpanded = true);
    _scheduleAutoPeek();
  }

  void _onVerticalDragStart(DragStartDetails details, double topInset, double h) {
    _autoPeekTimer?.cancel();
    _longPressLastY = null;
    _verticalDragging = true;
    _dragStartTop = _correctTop(_fabTop, topInset, h);
  }

  void _onVerticalDragUpdate(
    DragUpdateDetails details,
    double topInset,
    double h,
  ) {
    if (!_verticalDragging) return;
    final next = (_dragStartTop + details.delta.dy).clamp(
      _minTop(topInset),
      _maxTop(h),
    );
    setState(() => _fabTop = next);
    _dragStartTop = next;
  }

  void _commitFabTop(double topInset, double h) {
    final t = _clampTop(_fabTop ?? _defaultTop(h), topInset, h);
    setState(() => _fabTop = t);
    _persistTop();
  }

  void _onVerticalDragEnd(double topInset, double h) {
    if (!_verticalDragging) return;
    _verticalDragging = false;
    _commitFabTop(topInset, h);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _autoPeekTimer?.cancel();
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
          _scheduleDefaultTop(h);
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
              _persistTop();
            }
          });
        }

        final bool isComment = widget.mode == CommonFabMode.comment;
        final bool showPill = isComment && _pillExpanded;
        final double fabWidth = showPill
            ? CommonDraggableEdgeFab.expandedWidth
            : CommonDraggableEdgeFab.peekWidth;
        final double left =
            showPill ? _leftForExpanded(w) : _leftForPeek(w);

        Widget buildFabChild() {
          if (!isComment) {
            return _PeekAddTemplateTab(icon: Icons.add_comment_rounded);
          }
          if (showPill) {
            return const _CommentExpandedPill();
          }
          return const _CommentPeekTab();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(left, top),
            child: Tooltip(
              message: isComment ? 'コメント' : 'テンプレートを追加',
              child: Material(
                elevation: showPill ? 6 : 4,
                shadowColor: Colors.black.withValues(alpha: 0.22),
                borderRadius: showPill
                    ? BorderRadius.circular(CommonDraggableEdgeFab.borderRadiusLarge)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(CommonDraggableEdgeFab.borderRadiusLarge),
                        bottomLeft: Radius.circular(CommonDraggableEdgeFab.borderRadiusLarge),
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                color: AppColors.accentPrimary,
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: isComment
                      ? () => _onTapComment(topInset, h)
                      : _onTapAdd,
                  onHorizontalDragUpdate: (d) {
                    if (!isComment || showPill) return;
                    if (d.delta.dx < -4) {
                      _expandPillFromPeek();
                    }
                  },
                  onVerticalDragStart: (d) =>
                      _onVerticalDragStart(d, topInset, h),
                  onVerticalDragUpdate: (d) =>
                      _onVerticalDragUpdate(d, topInset, h),
                  onVerticalDragEnd: (_) =>
                      _onVerticalDragEnd(topInset, h),
                  onVerticalDragCancel: () =>
                      _onVerticalDragEnd(topInset, h),
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: (d) =>
                      _onLongPressMoveUpdate(d, topInset, h),
                  onLongPressEnd: (_) => _onLongPressEnd(topInset, h),
                  onLongPressCancel: () {
                    _verticalDragging = false;
                    _longPressLastY = null;
                  },
                  child: SizedBox(
                    width: fabWidth,
                    height: CommonDraggableEdgeFab.fabHeight,
                    child: buildFabChild(),
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

/// コメント・ピーク（吹き出しのみ）
class _CommentPeekTab extends StatelessWidget {
  const _CommentPeekTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.chat_bubble_rounded,
        size: 26,
        color: AppColors.textOnAccent,
      ),
    );
  }
}

/// コメント・展開ピル
class _CommentExpandedPill extends StatelessWidget {
  const _CommentExpandedPill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_rounded,
            size: 22,
            color: AppColors.textOnAccent,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'コメント',
                maxLines: 1,
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// テンプレ追加・ピークタブ
class _PeekAddTemplateTab extends StatelessWidget {
  const _PeekAddTemplateTab({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        size: 26,
        color: AppColors.textOnAccent,
      ),
    );
  }
}
