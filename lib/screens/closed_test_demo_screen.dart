import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ClosedTestDemoScreen extends StatefulWidget {
  const ClosedTestDemoScreen({super.key});

  static const String title = 'クローズドテスト用 疑似操作デモ';

  @override
  State<ClosedTestDemoScreen> createState() => _ClosedTestDemoScreenState();
}

class _ClosedTestDemoScreenState extends State<ClosedTestDemoScreen>
    with SingleTickerProviderStateMixin {
  static const String _tSearchCta = 'search_cta';
  static const String _tRecommendCard = 'recommend_card';
  static const String _tSearchResultCard = 'search_result_card';
  static const String _tRegisterCandidateBtn = 'register_candidate_btn';
  static const String _tRoomCollectTab = 'room_collect_tab';
  static const String _tCandidateListCard = 'candidate_list_card';
  static const String _tDoneListCard = 'done_list_card';
  static const String _tShopDiscoveryCard = 'shop_discovery_card';

  final GlobalKey _demoViewportKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _tapController;

  late final Map<String, GlobalKey> _targetKeys;
  late final List<_DemoScenarioStep> _steps;

  _DemoScene _scene = _DemoScene.home;
  String _caption = '「再生」を押すと疑似操作デモが始まります。';
  String? _activeTargetId;
  Rect? _highlightRect;
  Offset? _tapCenter;
  bool _isPlaying = false;
  bool _isPaused = false;
  int _stepIndex = 0;
  bool _playStartedOnce = false;

  @override
  void initState() {
    super.initState();
    _targetKeys = <String, GlobalKey>{
      _tSearchCta: GlobalKey(),
      _tRecommendCard: GlobalKey(),
      _tSearchResultCard: GlobalKey(),
      _tRegisterCandidateBtn: GlobalKey(),
      _tRoomCollectTab: GlobalKey(),
      _tCandidateListCard: GlobalKey(),
      _tDoneListCard: GlobalKey(),
      _tShopDiscoveryCard: GlobalKey(),
    };
    _steps = _buildScenario();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _scrollController.addListener(_refreshHighlightRect);
  }

  @override
  void dispose() {
    _tapController.dispose();
    _scrollController
      ..removeListener(_refreshHighlightRect)
      ..dispose();
    super.dispose();
  }

  List<_DemoScenarioStep> _buildScenario() {
    return <_DemoScenarioStep>[
      const _DemoScenarioStep(
        scene: _DemoScene.home,
        target: null,
        action: _DemoAction.navigate,
        delay: Duration(milliseconds: 700),
        caption: 'ホーム',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.home,
        target: _tRecommendCard,
        action: _DemoAction.highlight,
        delay: Duration(milliseconds: 1050),
        caption: 'おすすめ候補を確認',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.home,
        target: _tSearchCta,
        action: _DemoAction.highlight,
        delay: Duration(milliseconds: 980),
        caption: '検索導線を表示',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.home,
        target: _tSearchCta,
        action: _DemoAction.tap,
        delay: Duration(milliseconds: 820),
        caption: 'タップで検索へ',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.search,
        target: null,
        action: _DemoAction.navigate,
        delay: Duration(milliseconds: 720),
        caption: '検索結果',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.search,
        target: _tSearchResultCard,
        action: _DemoAction.scroll,
        delay: Duration(milliseconds: 900),
        caption: '結果をスクロール表示',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.search,
        target: _tRegisterCandidateBtn,
        action: _DemoAction.highlight,
        delay: Duration(milliseconds: 1020),
        caption: '候補登録ボタンを強調',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.search,
        target: _tRegisterCandidateBtn,
        action: _DemoAction.tap,
        delay: Duration(milliseconds: 980),
        caption: '候補に登録',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.room,
        target: null,
        action: _DemoAction.navigate,
        delay: Duration(milliseconds: 760),
        caption: 'ROOMコレ管理',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.room,
        target: _tCandidateListCard,
        action: _DemoAction.highlight,
        delay: Duration(milliseconds: 980),
        caption: '候補一覧を確認',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.room,
        target: _tDoneListCard,
        action: _DemoAction.highlight,
        delay: Duration(milliseconds: 980),
        caption: 'コレ済一覧を確認',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.room,
        target: _tDoneListCard,
        action: _DemoAction.tap,
        delay: Duration(milliseconds: 900),
        caption: 'コレ済タップ演出',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.recommend,
        target: null,
        action: _DemoAction.navigate,
        delay: Duration(milliseconds: 740),
        caption: 'おすすめ / 発掘',
      ),
      const _DemoScenarioStep(
        scene: _DemoScene.recommend,
        target: _tShopDiscoveryCard,
        action: _DemoAction.highlight,
        delay: Duration(milliseconds: 1300),
        caption: 'ショップ発掘まで確認',
      ),
    ];
  }

  Future<void> _play() async {
    if (_isPlaying && !_isPaused) return;
    if (!_isPaused) {
      _resetToStartForRecord();
    }
    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _playStartedOnce = true;
    });
    while (_isPlaying && _stepIndex < _steps.length) {
      await _waitIfPaused();
      if (!_isPlaying || !mounted) return;
      final step = _steps[_stepIndex];
      await _runStep(step);
      await _waitWithPause(step.delay);
      _stepIndex++;
    }
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _activeTargetId = null;
      _highlightRect = null;
      _caption = 'デモが完了しました。再生で最初から見直せます。';
    });
  }

  void _resetToStartForRecord() {
    _tapController.reset();
    _stepIndex = 0;
    _scene = _DemoScene.home;
    _activeTargetId = null;
    _highlightRect = null;
    _tapCenter = null;
    _caption = '再生中';
    _jumpTop();
  }

  Future<void> _runStep(_DemoScenarioStep step) async {
    if (_scene != step.scene) {
      setState(() {
        _scene = step.scene;
        _activeTargetId = null;
        _highlightRect = null;
      });
      await _waitWithPause(const Duration(milliseconds: 90));
      _jumpTop();
    }

    setState(() {
      _caption = step.caption;
      _activeTargetId = step.target;
    });

    if (step.target != null) {
      await _ensureTargetVisible(step.target!);
      _updateRectForTarget(step.target!);
    }

    if (step.action == _DemoAction.scroll && step.target != null) {
      await _animateDownThenBack();
      _updateRectForTarget(step.target!);
    }
    if (step.action == _DemoAction.tap && step.target != null) {
      await _playTap(step.target!);
    }
  }

  Future<void> _ensureTargetVisible(String targetId) async {
    final key = _targetKeys[targetId];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.25,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _animateDownThenBack() async {
    if (!_scrollController.hasClients) return;
    final current = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    final down = math.min(current + 180, max);
    await _scrollController.animateTo(
      down,
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
    );
    await _scrollController.animateTo(
      current.clamp(0, max),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _playTap(String targetId) async {
    _updateRectForTarget(targetId);
    final rect = _highlightRect;
    if (rect == null) return;
    setState(() {
      _tapCenter = rect.center;
    });
    _tapController
      ..stop()
      ..reset();
    await _tapController.forward();
  }

  void _updateRectForTarget(String targetId) {
    final key = _targetKeys[targetId];
    final targetCtx = key?.currentContext;
    final viewportCtx = _demoViewportKey.currentContext;
    if (targetCtx == null || viewportCtx == null) return;
    final targetBox = targetCtx.findRenderObject() as RenderBox?;
    final rootBox = viewportCtx.findRenderObject() as RenderBox?;
    if (targetBox == null || rootBox == null) return;
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: rootBox);
    final rect = Rect.fromLTWH(
      topLeft.dx - 4,
      topLeft.dy - 4,
      targetBox.size.width + 8,
      targetBox.size.height + 8,
    );
    if (!mounted) return;
    setState(() {
      _highlightRect = rect;
    });
  }

  void _refreshHighlightRect() {
    final target = _activeTargetId;
    if (target == null) return;
    _updateRectForTarget(target);
  }

  Future<void> _waitIfPaused() async {
    while (_isPaused && _isPlaying) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _waitWithPause(Duration duration) async {
    var elapsed = Duration.zero;
    const tick = Duration(milliseconds: 80);
    while (elapsed < duration && _isPlaying) {
      await _waitIfPaused();
      await Future<void>.delayed(tick);
      elapsed += tick;
    }
  }

  void _pauseOrResume() {
    if (!_isPlaying) return;
    setState(() {
      _isPaused = !_isPaused;
      _caption = _isPaused ? '一時停止中です。再開で続きから再生します。' : _caption;
    });
  }

  void _stop() {
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _stepIndex = 0;
      _scene = _DemoScene.home;
      _activeTargetId = null;
      _highlightRect = null;
      _tapCenter = null;
      _caption = '終了しました。再生で最初からデモを開始できます。';
    });
    _tapController.reset();
    _jumpTop();
  }

  void _jumpTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(ClosedTestDemoScreen.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              if (!_isPlaying || _isPaused) ...[
                _controlBar(context),
                const SizedBox(height: 10),
              ] else
                _recordingTopBar(),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        key: _demoViewportKey,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            transitionBuilder: (child, animation) {
                              final offset = Tween<Offset>(
                                begin: const Offset(0.14, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              );
                            },
                            child: SingleChildScrollView(
                              key: ValueKey<_DemoScene>(_scene),
                              controller: _scrollController,
                              physics: _isPlaying
                                  ? const NeverScrollableScrollPhysics()
                                  : const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                              child: _sceneBody(_scene),
                            ),
                          ),
                          if (_highlightRect != null)
                            Positioned.fromRect(
                              rect: _highlightRect!,
                              child: IgnorePointer(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF4A8DFF),
                                      width: 2.6,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4A8DFF,
                                        ).withValues(alpha: 0.28),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_tapCenter != null)
                            Positioned(
                              left: _tapCenter!.dx - 42,
                              top: _tapCenter!.dy - 42,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: 1 - _tapController.value,
                                  child: Container(
                                    width: 84 + (_tapController.value * 44),
                                    height: 84 + (_tapController.value * 44),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF4A8DFF),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: _captionBubble(),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _sceneBadge(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlBar(BuildContext context) {
    final progress = _steps.isEmpty ? 0.0 : _stepIndex / _steps.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'デモ進行: ${_stepIndex.clamp(0, _steps.length)}/${_steps.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_playStartedOnce ? '最初から再生' : '再生'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isPlaying ? _pauseOrResume : null,
                icon: Icon(
                  _isPaused
                      ? Icons.play_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(_isPaused ? '再開' : '一時停止'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('終了'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress.clamp(0, 1),
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _captionBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _caption,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordingTopBar() {
    final progress = _steps.isEmpty ? 0.0 : _stepIndex / _steps.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 5,
          value: progress.clamp(0, 1),
          backgroundColor: AppColors.surfaceVariant,
          color: AppColors.accentPrimary,
        ),
      ),
    );
  }

  Widget _sceneBadge() {
    final label = switch (_scene) {
      _DemoScene.home => 'HOME',
      _DemoScene.search => 'SEARCH',
      _DemoScene.room => 'ROOM',
      _DemoScene.recommend => 'RECOMMEND',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _sceneBody(_DemoScene scene) {
    switch (scene) {
      case _DemoScene.home:
        return _homeScene();
      case _DemoScene.search:
        return _searchScene();
      case _DemoScene.room:
        return _roomScene();
      case _DemoScene.recommend:
        return _recommendScene();
    }
  }

  Widget _homeScene() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SceneHeader(
          title: 'ホーム',
          subtitle: '今日の運用状況と主要導線をまとめて確認',
        ),
        const SizedBox(height: 10),
        _card(
          child: Row(
            children: const [
              _MiniMetric(label: '候補', value: '3件'),
              SizedBox(width: 8),
              _MiniMetric(label: 'コレ済', value: '2件'),
              SizedBox(width: 8),
              _MiniMetric(label: '保存ショップ', value: '4件'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _card(
          key: _targetKeys[_tRecommendCard],
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_awesome_outlined),
            title: Text('今日のおすすめ候補（8件）'),
            subtitle: Text('レビュー高評価の商品を優先表示'),
            trailing: Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: 8),
        _primaryButton(
          key: _targetKeys[_tSearchCta],
          label: '楽天でコレ候補を検索する',
          icon: Icons.search_rounded,
        ),
      ],
    );
  }

  Widget _searchScene() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SceneHeader(
          title: '楽天検索結果',
          subtitle: '人気順・レビュー条件で候補を絞り込み',
        ),
        const SizedBox(height: 8),
        _card(
          child: Row(
            children: const [
              Icon(Icons.filter_alt_outlined, size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'キーワード: 収納 / 最低レビュー数: 100 / ジャンル: インテリア',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < 6; i++) ...[
          _productCard(i),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _roomScene() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SceneHeader(
          title: 'ROOMコレ管理',
          subtitle: '候補登録からコレ済までを一括管理',
          trailing: Container(
            key: _targetKeys[_tRoomCollectTab],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('ROOMコレ'),
          ),
        ),
        const SizedBox(height: 8),
        _card(
          key: _targetKeys[_tCandidateListCard],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('候補一覧（3件）', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('・北欧デザイン マグカップ 2個セット'),
              Text('・軽量 折りたたみ傘 UVカット 55cm'),
              Text('・耐熱 ガラス保存容器 7点セット'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _card(
          key: _targetKeys[_tDoneListCard],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('コレ済一覧（2件）', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('・USB充電式 ハンディファン 3段風量'),
              Text('・高反発 クッションチェア 座椅子'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recommendScene() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SceneHeader(
          title: 'おすすめ / ショップ発掘',
          subtitle: '保存ショップや高スコア店から提案',
        ),
        const SizedBox(height: 8),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('おすすめ候補（本日8件）', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('・洗える ラグマット 185x185  ¥5,980'),
              Text('・ワイヤレス充電器 Qi対応 15W  ¥2,480'),
              Text('・スタッキング 保存容器 角型セット  ¥4,180'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _card(
          key: _targetKeys[_tShopDiscoveryCard],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('ショップ発掘（上位）', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('1. 北欧インテリア館  スコア 88.4'),
              Text('2. キッチンラボ      スコア 82.9'),
              Text('3. Life Gadget       スコア 81.2'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _productCard(int index) {
    final names = <String>[
      '洗える ラグマット 185x185',
      '折りたたみ 収納ボックス 3個組',
      '高見え クッションカバー 2枚',
      'LEDデスクライト 調光調色タイプ',
      'スタッキング 保存容器 角型セット',
      'ポータブル加湿器 USB静音',
    ];
    final prices = <String>['¥5,980', '¥3,880', '¥2,280', '¥4,580', '¥4,180', '¥2,680'];
    final shops = <String>[
      '北欧インテリア館',
      '北欧インテリア館',
      '北欧インテリア館',
      'Life Gadget',
      'キッチンラボ',
      'Life Gadget',
    ];

    final bool focus = index == 2;
    return _card(
      key: focus ? _targetKeys[_tSearchResultCard] : null,
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://picsum.photos/seed/search_$index/120/120',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names[index],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shops[index]}  ・  ${prices[index]}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (focus) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: _targetKeys[_tRegisterCandidateBtn],
                onPressed: () {},
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('コレ候補へ登録'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({Widget? child, Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    Key? key,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

enum _DemoScene { home, search, room, recommend }

enum _DemoAction { highlight, tap, navigate, scroll }

class _DemoScenarioStep {
  const _DemoScenarioStep({
    required this.scene,
    required this.target,
    required this.action,
    required this.delay,
    required this.caption,
  });

  final _DemoScene scene;
  final String? target;
  final _DemoAction action;
  final Duration delay;
  final String caption;
}

class _SceneHeader extends StatelessWidget {
  const _SceneHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
