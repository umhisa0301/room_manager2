import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/app_action_service.dart';
import '../services/post_comment_generation_exception.dart';
import '../services/post_comment_generation_service.dart';
import '../services/post_comment_generation_service_factory.dart';
import '../state/post_style_settings_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../widgets/app_button.dart';
import 'room_post_prepare_product_summary.dart';

/// 投稿準備用ボトムシートを表示する。
Future<void> showRoomPostPrepareBottomSheet({
  required BuildContext context,
  required RakutenSearchItem item,
  String recommendationReason = '',
  PostCommentGenerationService? generationService,
}) {
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
                    generationService ?? PostCommentGenerationServiceFactory.create(),
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
  });

  final RakutenSearchItem item;
  final String recommendationReason;
  final PostCommentGenerationService generationService;

  @override
  State<RoomPostPrepareSheetBody> createState() =>
      _RoomPostPrepareSheetBodyState();
}

class _RoomPostPrepareSheetBodyState extends State<RoomPostPrepareSheetBody> {
  late final TextEditingController _bodyController;
  bool _aiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  RakutenManagedProduct? _managedProduct(RakutenManagedProductProvider provider) {
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
      '投稿文を作成できませんでした。時間をおいてもう一度お試しください。';

  Future<void> _generateAiComment() async {
    if (_aiLoading) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final styleSettings = context.read<PostStyleSettingsProvider>().settings;
      final result = await widget.generationService.generate(
        PostCommentGenerationInput(
          itemName: widget.item.itemName,
          recommendationReason: widget.recommendationReason,
          itemPrice: widget.item.itemPrice,
          reviewAverage: widget.item.reviewAverage,
          reviewCount: widget.item.reviewCount,
          styleSettings: styleSettings,
        ),
      );
      if (!mounted) return;
      setState(() {
        _bodyController.text = result.displayText;
        _aiLoading = false;
      });
    } on PostCommentGenerationException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PostComment] generation failed code=${e.code}: ${e.message}',
        );
      }
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiError = _aiGenerationErrorMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiError = _aiGenerationErrorMessage;
      });
    }
  }

  Future<void> _postToRoom(BuildContext context) async {
    final provider = context.read<RakutenManagedProductProvider>();
    final text = _bodyController.text.trim();
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    if (!context.mounted) return;
    await provider.collectRoomAndLaunch(context, widget.item.productId);
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
            const SizedBox(height: RakutenSearchScreenUi.sheetBlockGap),
            Semantics(
              label: 'room_post_prepare_body_field',
              textField: true,
              child: TextField(
                key: const Key('room_post_prepare_body_field'),
                controller: _bodyController,
                minLines: 4,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: '投稿文を入力またはAIで作成',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.35,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
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
            if (_aiLoading) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              const Center(
                child: KeyedSubtree(
                  key: Key('room_post_prepare_ai_loading'),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ],
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
            AppSecondaryButton(
              key: const Key('room_post_prepare_ai_button'),
              label: 'AIで文章を作る',
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              onPressed: _aiLoading ? null : _generateAiComment,
              expand: true,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            AppPrimaryButton(
              key: const Key('room_post_prepare_room_button'),
              label: 'ROOMで投稿',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: roomUrlReady ? () => _postToRoom(context) : null,
              expand: true,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            AppSecondaryButton(
              key: const Key('room_post_prepare_rakuten_button'),
              label: '楽天で見る',
              icon: const Icon(Icons.storefront_rounded, size: 18),
              onPressed: () {
                AppActionService.openUrl(
                  context,
                  url: widget.item.browserLaunchUrl,
                );
              },
              expand: true,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            AppSecondaryButton(
              key: const Key('room_post_prepare_close_button'),
              label: '閉じる',
              onPressed: () => Navigator.of(context).pop(),
              expand: true,
            ),
          ],
        );
      },
    );
  }
}
