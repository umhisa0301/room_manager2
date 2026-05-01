import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

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

  /// 半収納時の幅（52 前後）
  static const double peekWidth = 52;

  /// 右側はみ出し（画面外に隠す量・24〜28）
  static const double peekHiddenFromRightEdge = 26;

  /// 展開時の最小幅（閉じる・余白・ラベル・テキストスケールに耐える）
  static const double expandedWidth = 168;

  static const double fabHeight = 56;

  static const double borderRadiusLarge = 28;

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

class _CommonDraggableEdgeFabState extends State<CommonDraggableEdgeFab>
    with SingleTickerProviderStateMixin {
  double? _fabTop;
  bool _prefsLoaded = false;
  bool _scheduledInitialFromLayout = false;

  /// false ＝半収納、true ＝展開
  bool _expanded = false;

  bool _verticalDragging = false;
  double? _longPressLastY;
  bool _clampPostFramePending = false;

  AnimationController? _chevronHintController;
  Animation<double>? _chevronHintOpacity;

  @override
  void dispose() {
    _chevronHintController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFirstHint());
  }

  @override
  void didUpdateWidget(covariant CommonDraggableEdgeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shellTabIndex != oldWidget.shellTabIndex && _expanded) {
      _disposeChevronHint();
      setState(() => _expanded = false);
    }
  }

  void _disposeChevronHint() {
    _chevronHintController?.dispose();
    _chevronHintController = null;
    _chevronHintOpacity = null;
  }

  void _collapseExpanded() {
    _disposeChevronHint();
    setState(() => _expanded = false);
  }

  void _expandFab() {
    if (!_prefsLoaded) return;
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryPlayChevronHint();
    });
  }

  Future<void> _tryPlayChevronHint() async {
    if (!mounted || !_expanded) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted || !_expanded) return;
      if (p.getBool(CommonDraggableEdgeFab.prefChevronHintSeen) == true) {
        return;
      }
      await p.setBool(CommonDraggableEdgeFab.prefChevronHintSeen, true);
      if (!mounted || !_expanded) return;

      _chevronHintController?.dispose();
      _chevronHintController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );
      _chevronHintOpacity = TweenSequence<double>(
        <TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(1),
            weight: 40,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1, end: 0).chain(
              CurveTween(curve: Curves.easeOut),
            ),
            weight: 60,
          ),
        ],
      ).animate(_chevronHintController!);

      void tick() {
        if (mounted) setState(() {});
      }

      _chevronHintController!.addListener(tick);
      await _chevronHintController!.forward();
      _chevronHintController?.removeListener(tick);
      if (mounted) {
        _disposeChevronHint();
        setState(() {});
      }
    } catch (_) {}
  }

  IconData _closeIcon() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return CupertinoIcons.xmark;
      default:
        return Icons.close_rounded;
    }
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
          content: Text(
            '半収納はタップで展開。×または外をタップで半収納。右の吹き出しでコメントへ。長押しで位置移動',
          ),
        ),
      );
    } catch (_) {}
  }

  double _clampTop(double t, double topInset, double h) =>
      t.clamp(_minTop(topInset), _maxTop(h));

  /// 右端スナップ：半収納は右に隠す、展開は余白付きで内側に収める
  double _leftForPeek(double w) =>
      w -
          CommonDraggableEdgeFab.peekWidth +
          CommonDraggableEdgeFab.peekHiddenFromRightEdge;

  double _leftForExpanded(double w, double fabW) =>
      w - fabW - CommonDraggableEdgeFab.edgeMargin;

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

        final textScaler = MediaQuery.textScalerOf(context);
        final expandExtraWidth =
            ((textScaler.scale(15) - 15) * 2.2).clamp(0.0, 44.0);
        final expandedFabWidth =
            CommonDraggableEdgeFab.expandedWidth + expandExtraWidth;

        final fabWidth = _expanded
            ? expandedFabWidth
            : CommonDraggableEdgeFab.peekWidth;
        final left = _expanded
            ? _leftForExpanded(w, expandedFabWidth)
            : _leftForPeek(w);

        final pillChild = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _expanded ? null : _expandFab,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: (d) =>
              _onLongPressMoveUpdate(d, topInset, h),
          onLongPressEnd: (_) => _onLongPressEnd(topInset, h),
          onLongPressCancel: () =>
              _onLongPressCancel(topInset, h),
          child: AnimatedContainer(
            duration: CommonDraggableEdgeFab.openCloseDuration,
            curve: CommonDraggableEdgeFab.openCloseCurve,
            width: fabWidth,
            height: CommonDraggableEdgeFab.fabHeight,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: _expanded
                  ? BorderRadius.circular(
                      CommonDraggableEdgeFab.borderRadiusLarge,
                    )
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
              boxShadow: _fabShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedScale(
              duration: CommonDraggableEdgeFab.openCloseDuration,
              curve: CommonDraggableEdgeFab.openCloseCurve,
              scale: _expanded ? 1.01 : 1.0,
              alignment: Alignment.centerRight,
              child: _expanded
                  ? _CommentExpandedRow(
                      closeIcon: _closeIcon(),
                      onCollapse: _collapseExpanded,
                      onOpenComment: _onTapComment,
                    )
                  : const _CommentPeekTab(),
            ),
          ),
        );

        final positionedChild = _expanded
            ? TapRegion(
                onTapOutside: (_) {
                  if (_expanded) _collapseExpanded();
                },
                child: pillChild,
              )
            : pillChild;

        final fabWithTooltip = _expanded
            ? positionedChild
            : Tooltip(
                message: 'コメント',
                child: positionedChild,
              );

        final columnChild = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            fabWithTooltip,
            if (_chevronHintOpacity != null)
              FadeTransition(
                opacity: _chevronHintOpacity!,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '×で半収納',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        );

        Widget positionWrapper(Widget child) {
          if (_verticalDragging) {
            return Positioned(
              left: left,
              top: top,
              child: child,
            );
          }
          return AnimatedPositioned(
            duration: CommonDraggableEdgeFab.openCloseDuration,
            curve: CommonDraggableEdgeFab.openCloseCurve,
            left: left,
            top: top,
            child: child,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            positionWrapper(columnChild),
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

class _CommentPeekTab extends StatelessWidget {
  const _CommentPeekTab();

  static final Color _hintChevronColor =
      AppColors.textOnAccent.withValues(alpha: 0.88);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.chevron_left_rounded,
          size: 18,
          color: _hintChevronColor,
        ),
        const SizedBox(width: 1),
        const Icon(
          Icons.chat_bubble_rounded,
          size: 22,
          color: AppColors.textOnAccent,
        ),
      ],
    );
  }
}

class _CommentExpandedRow extends StatelessWidget {
  const _CommentExpandedRow({
    required this.closeIcon,
    required this.onCollapse,
    required this.onOpenComment,
  });

  final IconData closeIcon;
  final VoidCallback onCollapse;
  final VoidCallback onOpenComment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '閉じて半収納',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCollapse,
              splashColor: Colors.white24,
              highlightColor: Colors.white12,
              child: SizedBox(
                width: 48,
                height: CommonDraggableEdgeFab.fabHeight,
                child: Center(
                  child: Icon(
                    closeIcon,
                    size: 22,
                    color: AppColors.textOnAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenComment,
              splashColor: Colors.white24,
              highlightColor: Colors.white12,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chat_bubble_rounded,
                      size: 21,
                      color: AppColors.textOnAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'コメント',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.textOnAccent,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
