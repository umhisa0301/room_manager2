import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/analytics_params.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/analytics_service.dart';
import '../services/app_action_service.dart';
import '../services/post_comment_generation_exception.dart';
import '../services/post_comment_generation_limit.dart';
import '../services/post_comment_generation_service.dart';
import '../services/post_comment_generation_service_factory.dart';
import '../services/post_comment_generation_result_store.dart';
import '../services/post_comment_generation_user_message.dart';
import '../state/post_style_settings_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../ui/feedback/app_feedback.dart';
import '../utils/product_display_title.dart';
import '../widgets/app_button.dart';
import 'room_post_prepare_product_summary.dart';

/// 投稿準備用ボトムシートを表示する。
Future<void> showRoomPostPrepareBottomSheet({
  required BuildContext context,
  required RakutenSearchItem item,
  String recommendationReason = '',
  PostCommentGenerationService? generationService,
  PostCommentGenerationBucket? generationBucket,
  String? productKey,
  bool? enforceDailyGenerationLimit,
  AnalyticsPostPrepareSource analyticsSource =
      AnalyticsPostPrepareSource.unknown,
}) {
  final analytics = context.read<AnalyticsService>();
  final styleSettings = context.read<PostStyleSettingsProvider>().settings;
  unawaited(
    analytics.logPostPrepareOpened(
      source: analyticsSource,
      hasSavedStyle: isPostStyleConfigured(styleSettings),
    ),
  );
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final keyboardBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardBottom),
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HomeScreenColors.homeCardFill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusCard),
              ),
              border: Border.all(color: HomeScreenColors.homeCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(0, -2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: SingleChildScrollView(
              key: const Key('room_post_prepare_sheet'),
              padding: RakutenSearchScreenUi.addCandidateSheetContentPadding,
              child: RoomPostPrepareSheetBody(
                item: item,
                recommendationReason: recommendationReason,
                generationService:
                    generationService ??
                    PostCommentGenerationServiceFactory.create(),
                generationBucket: generationBucket,
                productKey: productKey,
                enforceDailyGenerationLimit: enforceDailyGenerationLimit,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 投稿準備シートの本文（商品サマリー・投稿文・操作ボタン）。
class RoomPostPrepareSheetBody extends StatefulWidget {
  const RoomPostPrepareSheetBody({
    super.key,
    required this.item,
    required this.recommendationReason,
    required this.generationService,
    this.generationBucket,
    this.productKey,
    this.enforceDailyGenerationLimit,
  });

  final RakutenSearchItem item;
  final String recommendationReason;
  final PostCommentGenerationService generationService;

  /// おすすめコレ等の生成制限 bucket。
  ///
  /// Remote 利用時でも未指定なら bucket 制限は適用しない（探す・商品詳細など
  /// 将来の入口では呼び出し側が bucket を明示する前提。指定漏れで無制限になる）。
  final PostCommentGenerationBucket? generationBucket;

  /// 制限判定用の安定商品キー。未指定時は [item] から解決する。
  final String? productKey;

  /// テスト用。未指定時は Remote 利用時のみ bucket 制限を適用。
  final bool? enforceDailyGenerationLimit;

  @override
  State<RoomPostPrepareSheetBody> createState() =>
      _RoomPostPrepareSheetBodyState();
}

class _RoomPostPrepareSheetBodyState extends State<RoomPostPrepareSheetBody> {
  late final TextEditingController _bodyController;
  bool _aiLoading = false;
  String? _aiError;
  bool _autoGenerateStarted = false;
  bool _userEditedBody = false;
  bool _postingToRoom = false;

  /// 再生成中に編集領域を隠す間、失敗時復元用に保持する投稿文。
  String? _bodyTextBeforeGenerate;

  static const _aiRegenerateButtonLabel = 'AIで作り直す';
  static const _copyAndOpenRoomButtonLabel = 'コピーしてROOMを開く';
  static const _aiLoadingMessage = '投稿文を作成しています';
  static const _aiLoadingHint = '商品の特徴に合わせて文章を整えています';
  static const double _bodyAreaSlidePx = 5;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoGenerateOnOpen();
    });
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  RakutenManagedProduct? _managedProduct(
    RakutenManagedProductProvider provider,
  ) {
    final id = widget.item.productId.trim();
    for (final p in provider.items) {
      if (p.productId == id) return p;
    }
    return null;
  }

  bool _isRoomUrlReady(RakutenManagedProduct? product) {
    return product != null &&
        product.extractionStatus == RakutenUrlExtractionStatus.success &&
        product.extractedUrl.trim().isNotEmpty;
  }

  static const _aiGenerationErrorMessage =
      kPostCommentGenerationGenericErrorMessage;

  bool get _generationLimitEnforced =>
      widget.generationBucket != null &&
      (widget.enforceDailyGenerationLimit ??
          isPostCommentGenerationLimitEnforced());

  String? get _effectiveProductKey =>
      widget.productKey?.trim().isNotEmpty == true
      ? widget.productKey!.trim()
      : resolvePostCommentGenerationProductKey(widget.item);

  String _limitBlockedMessage(PostCommentGenerationLimitState limitState) {
    return switch (limitState.reasonCode) {
      kPostCommentProductAlreadyGeneratedReasonCode =>
        buildPostCommentGenerationProductAlreadyGeneratedBlockedMessage(),
      kPostCommentDailyLimitReasonCode =>
        buildPostCommentGenerationDailyLimitBlockedMessage(),
      _ => buildPostCommentGenerationDailyLimitBlockedMessage(),
    };
  }

  Future<void> _maybeAutoGenerateOnOpen() async {
    if (!mounted || _autoGenerateStarted) return;
    if (_bodyController.text.trim().isNotEmpty) return;
    _autoGenerateStarted = true;

    if (await _tryRestoreSavedGeneration()) return;
    await _generateAiComment();
  }

  Future<bool> _tryRestoreSavedGeneration() async {
    if (!_generationLimitEnforced) return false;

    final productKey = _effectiveProductKey;
    if (productKey == null || productKey.isEmpty) return false;

    final saved = await PostCommentGenerationResultStore.readTodaySavedResult(
      bucketName: widget.generationBucket!.name,
      productKey: productKey,
    );
    if (saved == null || !mounted) return false;

    setState(() {
      _applyGeneratedText(saved.displayText);
      _aiError = null;
    });
    return true;
  }

  Future<void> _onRegenerateAiComment() async {
    if (_aiLoading) return;
    if (_bodyController.text.trim().isNotEmpty && _userEditedBody) {
      final confirmed = await _showRegenerateConfirmDialog();
      if (confirmed != true || !mounted) return;
      _userEditedBody = false;
    }
    await _generateAiComment();
  }

  Future<bool?> _showRegenerateConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('投稿文を作り直しますか？'),
        content: const Text('現在の投稿文は上書きされます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('作り直す'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showClearBodyConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('投稿文をクリアしますか？'),
        content: const Text('入力中の投稿文が削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('クリア'),
          ),
        ],
      ),
    );
  }

  Future<void> _onClearBody() async {
    if (_bodyController.text.trim().isEmpty || _aiLoading) return;
    final confirmed = await _showClearBodyConfirmDialog();
    if (confirmed != true || !mounted) return;
    setState(() {
      _bodyController.clear();
      _userEditedBody = false;
      _aiError = null;
    });
  }

  void _applyGeneratedText(String text) {
    _bodyController.text = text;
    _userEditedBody = false;
  }

  AnalyticsService get _analytics => context.read<AnalyticsService>();

  Future<void> _generateAiComment() async {
    if (_aiLoading) return;

    PostCommentGenerationLimitState? limitState;
    if (_generationLimitEnforced) {
      final bucket = widget.generationBucket!;
      final productKey = _effectiveProductKey;
      limitState = await resolvePostCommentGenerationAvailabilityForToday(
        bucket: bucket,
        productKey: productKey ?? '',
        enforcementEnabled: true,
      );
      if (!limitState.allowed) {
        if (!mounted) return;
        setState(() {
          _aiError = _limitBlockedMessage(limitState!);
        });
        unawaited(
          _analytics.logAiCommentGenerateError(
            source: AnalyticsAiCommentSource.postPrepare,
            errorType: AnalyticsAiCommentErrorType.limit,
          ),
        );
        return;
      }
    }

    // limit 判定の await 後。シート破棄済みなら Provider / setState に進まない。
    if (!mounted) return;
    final styleSettings = context.read<PostStyleSettingsProvider>().settings;
    final styleConfigured = isPostStyleConfigured(styleSettings);
    final remainingBefore = limitState == null
        ? null
        : (limitState.limit - limitState.usedCount).clamp(0, 1000);
    unawaited(
      _analytics.logAiCommentGenerateStart(
        source: AnalyticsAiCommentSource.postPrepare,
        remainingCountBefore: remainingBefore,
        styleConfigured: styleConfigured,
      ),
    );

    setState(() {
      _bodyTextBeforeGenerate = _bodyController.text;
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final result = await widget.generationService.generate(
        PostCommentGenerationInput(
          itemName: deriveProductDisplayTitle(widget.item.itemName),
          rawTitle: widget.item.itemName,
          recommendationReason: widget.recommendationReason,
          itemPrice: widget.item.itemPrice,
          reviewAverage: widget.item.reviewAverage,
          reviewCount: widget.item.reviewCount,
          genreName: widget.item.genreName,
          genreId: widget.item.genreId,
          shopName: widget.item.shopName,
          productUrl: widget.item.browserLaunchUrl,
          imageUrl: widget.item.imageUrl,
          styleSettings: styleSettings,
        ),
      );
      if (!mounted) return;
      if (_generationLimitEnforced) {
        final bucket = widget.generationBucket!;
        final productKey = _effectiveProductKey;
        if (productKey != null && productKey.isNotEmpty) {
          await recordSuccessfulPostCommentGeneration(
            bucket: bucket,
            productKey: productKey,
          );
          await PostCommentGenerationResultStore.saveTodayResult(
            bucketName: bucket.name,
            productKey: productKey,
            result: result,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        if (!_userEditedBody) {
          _applyGeneratedText(result.displayText);
        }
        _aiLoading = false;
        _bodyTextBeforeGenerate = null;
      });
      int? remainingAfter;
      if (_generationLimitEnforced) {
        final bucket = widget.generationBucket!;
        final productKey = _effectiveProductKey ?? '';
        final limitState =
            await resolvePostCommentGenerationAvailabilityForToday(
              bucket: bucket,
              productKey: productKey,
              enforcementEnabled: true,
            );
        remainingAfter = (limitState.limit - limitState.usedCount).clamp(
          0,
          1000,
        );
      }
      unawaited(
        _analytics.logAiCommentGenerateSuccess(
          source: AnalyticsAiCommentSource.postPrepare,
          generatedLengthBucket: bucketGeneratedTextLength(
            result.displayText.length,
          ),
          remainingCountAfter: remainingAfter,
        ),
      );
    } on PostCommentGenerationException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PostComment] generation failed code=${e.code}: ${e.message}',
        );
      }
      if (!mounted) return;
      setState(() {
        _restoreBodyTextBeforeGenerate();
        _aiLoading = false;
        _aiError = postCommentGenerationUserMessage(e);
      });
      unawaited(
        _analytics.logAiCommentGenerateError(
          source: AnalyticsAiCommentSource.postPrepare,
          errorType: classifyAnalyticsAiCommentError(e),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoreBodyTextBeforeGenerate();
        _aiLoading = false;
        _aiError = _aiGenerationErrorMessage;
      });
      unawaited(
        _analytics.logAiCommentGenerateError(
          source: AnalyticsAiCommentSource.postPrepare,
          errorType: AnalyticsAiCommentErrorType.network,
        ),
      );
    }
  }

  void _restoreBodyTextBeforeGenerate() {
    final snapshot = _bodyTextBeforeGenerate;
    _bodyTextBeforeGenerate = null;
    if (snapshot == null) return;
    _bodyController.value = TextEditingValue(
      text: snapshot,
      selection: TextSelection.collapsed(offset: snapshot.length),
    );
  }

  Future<void> _postToRoom() async {
    if (_postingToRoom || !mounted) return;
    setState(() => _postingToRoom = true);

    final productId = widget.item.productId.trim();
    final provider = context.read<RakutenManagedProductProvider>();
    final navigator = Navigator.of(context);
    final launchContext = navigator.context;

    try {
      final text = _bodyController.text.trim();
      if (text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
        unawaited(
          _analytics.logAiCommentCopied(
            source: AnalyticsAiCommentSource.postPrepare,
            textType: resolveAiCommentTextType(
              bodyText: text,
              userEditedBody: _userEditedBody,
            ),
          ),
        );
        // Sheet 閉鎖後も見えるよう root messenger で通知（ROOM 起動は遅らせない）。
        AppFeedback.successRoot(message: '投稿文をコピーしました');
        if (kDebugMode) {
          debugPrint('[ROOM_POST_PREPARE] copyText done');
        }
      }
      if (!mounted) return;

      if (kDebugMode) {
        debugPrint(
          '[ROOM_POST_PREPARE] collectRoomAndLaunch start productId=$productId',
        );
      }

      // モーダル上の context だと URL 起動が失敗することがあるため、先に閉じる。
      navigator.pop();

      if (!launchContext.mounted) return;
      final ok = await provider.collectRoomAndLaunch(
        launchContext,
        productId,
        analyticsSource: AnalyticsRoomLaunchSource.postPrepare,
      );

      if (kDebugMode) {
        debugPrint(
          ok
              ? '[ROOM_POST_PREPARE] collectRoomAndLaunch done'
              : '[ROOM_POST_PREPARE] launch failed reason=collectRoomAndLaunch returned false',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _postingToRoom = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, managedProvider, _) {
        final product = _managedProduct(managedProvider);
        final roomUrlReady = _isRoomUrlReady(product);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '投稿の準備',
              style: RakutenSearchScreenUi.screenTitleStyle(context),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              'コメントを確認してからROOMへ',
              style: RakutenSearchScreenUi.screenSubtitleStyle(context),
            ),
            const SizedBox(height: RakutenSearchScreenUi.sheetBlockGap),
            RoomPostPrepareProductSummary(item: widget.item),
            const SizedBox(height: AppDimensions.spacingSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '投稿文',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                AppSecondaryButton(
                  key: const Key('room_post_prepare_ai_button'),
                  label: _aiRegenerateButtonLabel,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  onPressed: _aiLoading ? null : _onRegenerateAiComment,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _bodyController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return Semantics(
                      button: true,
                      label: 'room_post_prepare_clear_button',
                      enabled: hasText && !_aiLoading,
                      child: IconButton(
                        key: const Key('room_post_prepare_clear_button'),
                        tooltip: '投稿文をクリア',
                        onPressed: hasText && !_aiLoading ? _onClearBody : null,
                        icon: const Icon(Icons.delete_outline),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxFieldHeight =
                    (MediaQuery.sizeOf(context).height * 0.28).clamp(
                      140.0,
                      220.0,
                    );
                final switchDuration = AppMotion.durationOf(
                  context,
                  AppMotion.normal,
                );
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFieldHeight),
                  child: AnimatedSwitcher(
                    duration: switchDuration,
                    switchInCurve: AppMotion.standard,
                    switchOutCurve: AppMotion.standard,
                    // 退場中の旧子をツリーに残すと編集欄がヒット可能・検出可能のままになるため、
                    // 入場側の Fade/Slide のみ行い現行子だけを配置する。
                    layoutBuilder: (currentChild, previousChildren) {
                      return currentChild ?? const SizedBox.shrink();
                    },
                    transitionBuilder: (child, animation) {
                      if (switchDuration == Duration.zero) {
                        return child;
                      }
                      return FadeTransition(
                        opacity: animation,
                        child: AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                _bodyAreaSlidePx * (1 - animation.value),
                              ),
                              child: child,
                            );
                          },
                          child: child,
                        ),
                      );
                    },
                    child: _aiLoading
                        ? _RoomPostPrepareAiGeneratingPanel(
                            key: const Key('room_post_prepare_ai_loading'),
                            title: _aiLoadingMessage,
                            hint: _aiLoadingHint,
                          )
                        : KeyedSubtree(
                            key: const ValueKey(
                              'room_post_prepare_body_editor',
                            ),
                            child: TextField(
                              key: const Key('room_post_prepare_body_field'),
                              controller: _bodyController,
                              minLines: 5,
                              maxLines: null,
                              scrollPhysics: const BouncingScrollPhysics(),
                              onChanged: (_) {
                                _userEditedBody = true;
                              },
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                // 空欄時は hint、入力後は本文を TextField 標準 Semantics で読み上げる。
                                hintText: '投稿文を入力またはAIで作成',
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                  height: 1.4,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFAFAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4D4DA),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4D4DA),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.accentPrimary,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
            if (_aiError != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                _aiError!,
                key: const Key('room_post_prepare_ai_error'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
            if (!roomUrlReady) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'ROOM用URLを取得中です。数十秒かかることがあります。',
                key: const Key('room_post_prepare_url_not_ready_hint'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: RakutenSearchScreenUi.gapBeforePrimaryCta),
            _RoomPostPreparePrimaryButton(
              key: const Key('room_post_prepare_room_button'),
              label: _copyAndOpenRoomButtonLabel,
              icon: Icons.open_in_new_rounded,
              isLoading: _postingToRoom,
              onPressed: roomUrlReady && !_postingToRoom && !_aiLoading
                  ? _postToRoom
                  : null,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Row(
              children: [
                Expanded(
                  child: _RoomPostPrepareOutlineButton(
                    key: const Key('room_post_prepare_rakuten_button'),
                    label: '楽天で見る',
                    icon: Icons.storefront_rounded,
                    onPressed: () {
                      AppActionService.openUrl(
                        context,
                        url: widget.item.browserLaunchUrl,
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: _RoomPostPrepareWeakButton(
                    key: const Key('room_post_prepare_close_button'),
                    label: '閉じる',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
          ],
        );
      },
    );
  }
}

/// AI投稿文生成中のプレースホルダー表示（静的ライン + 進捗）。
class _RoomPostPrepareAiGeneratingPanel extends StatelessWidget {
  const _RoomPostPrepareAiGeneratingPanel({
    super.key,
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  static const List<double> _lineWidthFactors = [1.0, 0.92, 0.78, 0.58];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.onSurface.withValues(alpha: 0.08);
    final borderColor = const Color(0xFFD4D4DA);

    return Semantics(
      liveRegion: true,
      label: '$title。$hint',
      child: Container(
        key: const Key('room_post_prepare_ai_generating_panel'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('room_post_prepare_ai_loading_text'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              key: const Key('room_post_prepare_ai_loading_hint'),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            for (var i = 0; i < _lineWidthFactors.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: _lineWidthFactors[i],
                alignment: Alignment.centerLeft,
                child: Container(
                  key: Key('room_post_prepare_ai_placeholder_line_$i'),
                  height: 10,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomPostPreparePrimaryButton extends StatelessWidget {
  const _RoomPostPreparePrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: AppColors.textOnAccent,
          backgroundColor: AppColors.accentPrimary,
          disabledForegroundColor: AppColors.textOnAccent.withValues(
            alpha: 0.72,
          ),
          disabledBackgroundColor: AppColors.accentPrimary.withValues(
            alpha: 0.34,
          ),
          minimumSize: const Size(double.infinity, _height),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnAccent.withValues(alpha: 0.9),
                ),
              )
            : Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    );
  }
}

/// おすすめコレ候補カードの Secondary CTA（白地＋ティール枠）に寄せたアウトラインボタン。
class _RoomPostPrepareOutlineButton extends StatelessWidget {
  const _RoomPostPrepareOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  static const double _minHeight = 40;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _minHeight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: HomeScreenColors.homeAccentTeal,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(double.infinity, _minHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: HomeScreenColors.homeAccentTealBorder,
              width: 1.5,
            ),
          ),
          textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// 閉じるなど補助操作向けの弱いボタン。
class _RoomPostPrepareWeakButton extends StatelessWidget {
  const _RoomPostPrepareWeakButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const double _minHeight = 40;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _minHeight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(double.infinity, _minHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.divider.withValues(alpha: 0.82)),
          ),
          textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
