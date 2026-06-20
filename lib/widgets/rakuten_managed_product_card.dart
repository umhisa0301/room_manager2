import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/debug_log_flags.dart';
import '../models/rakuten_managed_product.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../utils/room_reaction_status_display.dart';
import '../utils/room_unconfirmed_display_copy.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/room_colle_list_accent.dart';
import '../utils/display_text_utils.dart';
import '../utils/product_card_rakuten_open.dart';
import '../utils/rakuten_product_rating_display.dart';
import '../utils/shop_display_resolve.dart';
import '../utils/room_colle_card_time_format.dart';
import 'app_button.dart';
import 'room_colle_product_list_card_layout.dart';

/// 一覧カードの見た目バリアント（候補 / コレ済）。
enum RakutenManagedProductCardVariant { candidate, done }

/// 楽天ROOM管理の保存済み商品カード（左画像・右情報の横並び一覧向け）。
class RakutenManagedProductCard extends StatelessWidget {
  const RakutenManagedProductCard({
    super.key,
    required this.product,
    required this.variant,
    this.onCollectPressed,
    this.genrePrefetchLabels,
    this.isSavedShop = false,
    this.isTodayRecommendationCandidate = false,
    this.collectPostingBlocked = false,
    this.collectPostingBlockedMessage = '',
    this.roomImportEnrichHighlight = false,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final Future<void> Function(
    BuildContext context,
    RakutenManagedProduct product,
  )?
  onCollectPressed;

  /// [GenreMasterRepository] プリフェッチ後の genreId→表示名（任意）。
  final Map<String, String>? genrePrefetchLabels;
  final bool isSavedShop;
  final bool isTodayRecommendationCandidate;

  /// 1日・1時間の上限により「投稿する」を止めるとき true。
  final bool collectPostingBlocked;

  /// [collectPostingBlocked] 時にユーザーへ示す全文（ツールチップ等）。
  final String collectPostingBlockedMessage;

  /// ROOM取り込みメタ補完の直後に一覧で強調するとき true。
  final bool roomImportEnrichHighlight;

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

  /// ROOM 商品ページ or コレ導線用に抽出した URL（バッジ表示用）。
  bool get _hasRoomLinkForBadge =>
      product.extractedUrl.trim().isNotEmpty ||
      product.roomUrl.trim().isNotEmpty;

  static String _safeItemName(RakutenManagedProduct product) {
    try {
      final t = product.itemName.trim();
      return t.isEmpty ? '（商品名なし）' : t;
    } catch (_) {
      return '（商品名なし）';
    }
  }

  static String _safePriceYen(RakutenManagedProduct product) {
    try {
      return RoomColleProductListCardLayout.formatPriceYen(product.itemPrice);
    } catch (_) {
      return '価格 —';
    }
  }

  String _shopDisplayLine() {
    if (product.roomImportMetadataEnriching) return 'ショップ確認中';
    return ShopDisplayResolve.resolveDisplayShopName(
      shopName: product.shopName,
      shopCode: product.shopCode,
      screen: 'rakutenManagedProductCard',
    );
  }

  String _genreDisplayLine() {
    if (product.roomImportMetadataEnriching) return 'ジャンル確認中';
    final gn = product.genreName.trim();
    if (gn.isNotEmpty && gn != 'ジャンル未設定') return gn;
    final rn = product.resolvedGenreName.trim();
    if (rn.isNotEmpty && rn != 'ジャンル未設定') return rn;
    final id = product.genreId.trim();
    if (id.isNotEmpty) {
      final prefetched = genrePrefetchLabels?[id]?.trim();
      if (prefetched != null && prefetched.isNotEmpty) return prefetched;
      return 'ジャンル確認中';
    }
    return 'ジャンル未設定';
  }

  static String _candidateRegisteredMetaLine(DateTime addedAt) {
    final stamp = formatRoomColleCardTimestamp(addedAt, DateTime.now());
    if (stamp == null || stamp.isEmpty) {
      return '登録日 -';
    }
    return '登録日 $stamp';
  }

  static String _donePostedMetaLine(RakutenManagedProduct p) {
    switch (p.coredActivitySource) {
      case RakutenCoredActivitySource.roomImport:
        final rp = p.roomPostedAt;
        if (rp != null) {
          final s = formatRoomColleCardTimestamp(rp, DateTime.now());
          return (s == null || s.isEmpty) ? 'ROOM投稿日：-' : 'ROOM投稿日 $s';
        }
        return 'ROOM投稿日：-';
      case RakutenCoredActivitySource.manual:
        final inst = p.doneAt ?? p.addedAt;
        final s = formatRoomColleCardTimestamp(inst, DateTime.now());
        if (s == null || s.isEmpty) return '登録日 -';
        return '登録日 $s';
      case RakutenCoredActivitySource.appPost:
        final s = formatRoomColleCardTimestamp(p.doneAt, DateTime.now());
        if (s == null || s.isEmpty) return '投稿日 -';
        return '投稿日 $s';
    }
  }

  static String? _donePostedMetaTooltip(RakutenManagedProduct p) {
    if (p.coredActivitySource != RakutenCoredActivitySource.roomImport) {
      return null;
    }
    if (p.roomPostedAt != null) return null;
    return 'ROOMで投稿済みの商品です。投稿日は取得できていません。';
  }

  static String _ratingLabel(RakutenManagedProduct product) {
    if (product.reviewAverage > 0 || product.reviewCount > 0) {
      final label = RakutenProductRatingDisplay.formatProductCardLabel(
        reviewAverage: product.reviewAverage,
        reviewCount: product.reviewCount,
      );
      RakutenProductRatingDisplay.traceLog(
        source: 'rakutenManagedProductCard',
        productId: product.productId,
        reviewAverage: product.reviewAverage,
        reviewCount: product.reviewCount,
        displayText: label,
      );
      return label;
    }
    final hasPositiveSignal =
        product.feedbackSoldAt != null || product.feedbackLikedAt != null;
    if (hasPositiveSignal) return '評価 反応あり';
    if (product.feedbackWeakAt != null) return '評価 微妙';
    final label = RakutenProductRatingDisplay.formatProductCardLabel(
      reviewAverage: 0,
      reviewCount: 0,
    );
    RakutenProductRatingDisplay.traceLog(
      source: 'rakutenManagedProductCard',
      productId: product.productId,
      reviewAverage: 0,
      reviewCount: 0,
      displayText: label,
    );
    return label;
  }

  void _debugLogReactionStatusChip() {
    if (!kDebugMode) return;
    if (product.status != RakutenManagedProductStatus.done) return;
    final chip = RoomReactionStatusDisplay.chipLabelForProduct(product);
    RoomReactionStatusDisplay.logRender(
      productId: product.productId.trim(),
      roomLikeCount: product.roomLikeCount,
      roomCommentCount: product.roomCommentCount,
      chipLabel: chip,
    );
  }

  Color _heartCommentAccent(int? count) {
    return count != null && count > 0
        ? HomeScreenColors.homeAccentTeal
        : AppColors.textTertiary;
  }

  void _openRakuten(BuildContext context, String source) {
    ProductCardRakutenOpen.open(
      context: context,
      affiliateUrl: product.affiliateUrl,
      itemUrl: product.itemUrl.isNotEmpty ? product.itemUrl : product.rakutenUrl,
      screen: 'rakutenManagedProductCard',
      productId: product.productId,
      source: source,
    );
  }

  @override
  Widget build(BuildContext context) {
    ProductCardRakutenOpen.auditCard(
      screen: 'rakutenManagedProductCard',
      cardType: 'RakutenManagedProductCard',
    );
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final enrichNeed =
        RoomImportMetadataEnrichmentService.needFlagsForProduct(product);
    final theme = Theme.of(context);
    final titleStyle = RoomColleProductListCardLayout.titleTextStyle(theme);
    final priceStyle = RoomColleProductListCardLayout.priceTextStyle(theme);
    final timestampStyle = RoomColleProductListCardLayout.metaTextStyle(theme);
    final reactionStyle =
        (timestampStyle ?? theme.textTheme.bodySmall ?? const TextStyle())
            .copyWith(fontSize: 11, fontWeight: FontWeight.w700);

    if (!isCandidate) {
      _debugLogReactionStatusChip();
    }

    return RoomColleProductListCardShell(
      child: Padding(
        padding: RoomColleProductListCardLayout.cardInnerPadding.copyWith(
          bottom: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCandidate)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _candidateBadges(context)),
                    _candidateRemoveLink(context),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoomColleProductListCardThumbSlot(child: _heroImage(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCandidate) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _SmallBadge(
                              label: 'コレ済',
                              color: RoomColleListAccent.done,
                            ),
                            if (product.coredActivitySource ==
                                    RakutenCoredActivitySource.roomImport &&
                                roomImportEnrichHighlight) ...[
                              const _SmallBadge(
                                label: '補完反映',
                                color: HomeScreenColors.homeAccentTeal,
                              ),
                              if (!enrichNeed.needsPrice)
                                const _SmallBadge(
                                  label: '価格取得済み',
                                  color: Color(0xFF64748B),
                                ),
                              if (!enrichNeed.needsImage)
                                const _SmallBadge(
                                  label: '画像取得済み',
                                  color: Color(0xFF64748B),
                                ),
                            ],
                            Builder(
                              builder: (context) {
                                final chip = RoomReactionStatusDisplay.chipLabelForProduct(
                                  product,
                                );
                                final Color chipColor;
                                switch (chip) {
                                  case '反応あり':
                                    chipColor = HomeScreenColors.homeSuccess;
                                    break;
                                  case '未確認':
                                    chipColor = AppColors.textTertiary;
                                    break;
                                  case '未取り込み':
                                    chipColor = HomeScreenColors.homeMutedText;
                                    break;
                                  default:
                                    chipColor = HomeScreenColors.homeSuccess;
                                }
                                return _SmallBadge(
                                  label: chip,
                                  color: chipColor,
                                );
                              },
                            ),
                            if (RoomUnconfirmedDisplayCopy.chipLabelFor(
                                  product,
                                ) !=
                                null)
                              _SmallBadge(
                                label: RoomUnconfirmedDisplayCopy.chipLabelFor(
                                  product,
                                )!,
                                color: HomeScreenColors.homeWarning,
                              ),
                            if (product.roomLikeCount != null)
                              Text(
                                '♡${product.roomLikeCount}',
                                style: reactionStyle.copyWith(
                                  color:
                                      _heartCommentAccent(product.roomLikeCount),
                                ),
                              ),
                            if (product.roomCommentCount != null)
                              Text(
                                '💬${product.roomCommentCount}',
                                style: reactionStyle.copyWith(
                                  color: _heartCommentAccent(
                                    product.roomCommentCount,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      InkWell(
                        onTap: () => _openRakuten(context, 'title'),
                        borderRadius: BorderRadius.circular(6),
                        child: Text(
                          _safeItemName(product),
                          maxLines: RoomColleProductListCardLayout.titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: (titleStyle ?? const TextStyle()).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: (titleStyle ?? const TextStyle())
                                .color
                                ?.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _safePriceYen(product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: priceStyle,
                      ),
                      if (RoomUnconfirmedDisplayCopy.priceSublineFor(product) !=
                          null) ...[
                        const SizedBox(height: 2),
                        Text(
                          RoomUnconfirmedDisplayCopy.priceSublineFor(product)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (priceStyle ?? const TextStyle()).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (isCandidate) ...[
                        const SizedBox(height: 6),
                        _ratingRow(context),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${_shopDisplayLine()} / ${_genreDisplayLine()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: timestampStyle,
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (ctx) {
                          final line = isCandidate
                              ? _candidateRegisteredMetaLine(product.addedAt)
                              : _donePostedMetaLine(product);
                          final tip = isCandidate
                              ? null
                              : _donePostedMetaTooltip(product);
                          final compactPostedMeta =
                              !isCandidate &&
                              product.coredActivitySource ==
                                  RakutenCoredActivitySource.roomImport;
                          Widget child = Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: compactPostedMeta
                                ? reactionStyle
                                : timestampStyle,
                          );
                          if (tip != null) {
                            child = Tooltip(message: tip, child: child);
                          }
                          return child;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isCandidate) ...[
              _candidateActions(context),
            ] else ...[
              _feedbackToolbar(context),
              const SizedBox(height: 6),
              _doneActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _decisionBadge(BuildContext context) {
    return _SmallBadge(label: '今日のおすすめ', color: RoomColleListAccent.candidate);
  }

  Widget _candidateBadges(BuildContext context) {
    final badges = <Widget>[
      _SmallBadge(label: 'コレ候補', color: RoomColleListAccent.candidate),
    ];
    if (isTodayRecommendationCandidate) {
      badges.add(_decisionBadge(context));
    }
    if (isSavedShop) {
      badges.add(
        _SmallBadge(
          label: '保存ショップ',
          color: HomeScreenColors.homeMutedText,
        ),
      );
    }
    if (_hasRoomLinkForBadge) {
      badges.add(
        _SmallBadge(
          label: 'ROOM URLあり',
          color: HomeScreenColors.homeSuccess,
        ),
      );
    }
    return Wrap(spacing: 5, runSpacing: 4, children: badges);
  }

  Widget _candidateRemoveLink(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Semantics(
      button: true,
      label: 'post_management_item_remove_button',
      child: OutlinedButton.icon(
        onPressed: () => _confirmRemoveCandidate(context, provider),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6B7280),
          backgroundColor: HomeScreenColors.homeCardFill,
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(44, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: const Text('削除'),
      ),
    );
  }

  static ButtonStyle _cardOutlineButtonStyle({required bool enabled}) {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeAccentTeal,
      backgroundColor: Colors.white,
      disabledForegroundColor: const Color(0xFF9CA3AF),
      disabledBackgroundColor: Colors.white,
      side: BorderSide(
        color: enabled
            ? HomeScreenColors.homeAccentTeal
            : HomeScreenColors.homeCardBorder.withValues(alpha: 0.6),
        width: 1.5,
      ),
      elevation: 0,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle _cardPrimaryButtonStyle({required bool enabled}) {
    return FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: HomeScreenColors.homeAccentTeal,
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      disabledBackgroundColor: HomeScreenColors.homeAccentTeal.withValues(
        alpha: 0.34,
      ),
      elevation: 0,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    );
  }

  Widget _ratingRow(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFFFB300)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _ratingLabel(product),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _feedbackToolbar(BuildContext context) {
    final prov = context.read<RakutenManagedProductProvider>();
    final sold = product.feedbackSoldAt != null;
    final weak = product.feedbackWeakAt != null;
    final roomReaction = RoomReactionStatusDisplay.hasPositiveReaction(
      roomLikeCount: product.roomLikeCount,
      roomCommentCount: product.roomCommentCount,
    );
    final liked = product.feedbackLikedAt != null ||
        (!sold && !weak && roomReaction);
    if (kDebugMode && DebugLogFlags.enableVerboseReactionButtonRenderLog) {
      final source = product.feedbackLikedAt != null
          ? 'manual'
          : (roomReaction ? 'roomReaction' : 'computed');
      debugPrint(
        '[REACTION_BUTTON_STATE_RENDER] productId=${product.productId.trim()} '
        'soldSelected=$sold reactionSelected=$liked weakSelected=$weak source=$source',
      );
    }
    return Row(
      children: [
        Expanded(
          child: _FeedbackToggleButton(
            label: '売れた',
            selected: sold,
            icon: Icons.local_fire_department_rounded,
            selectedColor: const Color(0xFFE65100),
            onPressed: () async {
              final err = await prov.toggleFeedbackSold(
                context,
                product.productId,
              );
              if (!context.mounted) return;
              _showFeedbackError(context, err);
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _FeedbackToggleButton(
            label: '反応あり',
            selected: liked,
            icon: Icons.thumb_up_alt_rounded,
            selectedColor: RoomColleListAccent.done,
            onPressed: () async {
              final err = await prov.toggleFeedbackLiked(
                context,
                product.productId,
              );
              if (!context.mounted) return;
              _showFeedbackError(context, err);
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _FeedbackToggleButton(
            label: '微妙',
            selected: weak,
            icon: Icons.trending_down_rounded,
            selectedColor: const Color(0xFF795548),
            onPressed: () async {
              final err = await prov.toggleFeedbackWeak(
                context,
                product.productId,
              );
              if (!context.mounted) return;
              _showFeedbackError(context, err);
            },
          ),
        ),
      ],
    );
  }

  void _showFeedbackError(BuildContext context, String? err) {
    if (!context.mounted || err == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    final postLimitBlocked = collectPostingBlocked;
    final urlNotReady = !_canCollectRoom;
    final postActionsDisabled = postLimitBlocked || urlNotReady;
    final String postTooltip;
    if (urlNotReady) {
      postTooltip = 'ROOM用のURLが取得できるまでお待ちください';
    } else if (postLimitBlocked) {
      final m = collectPostingBlockedMessage.trim();
      postTooltip = m.isNotEmpty
          ? m
          : '直近24時間またはこの1時間の投稿上限に達しています。ホームの表示をご確認ください。';
    } else {
      postTooltip = 'ROOMのURLを開き、一覧をコレ済に移します。';
    }

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'post_management_item_open_rakuten_button',
            child: OutlinedButton.icon(
              onPressed: () async {
                final err = await provider.openRakutenItemPage(
                  context,
                  product.productId,
                );
                if (!context.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                }
              },
              style: _cardOutlineButtonStyle(enabled: true),
              icon: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: HomeScreenColors.homeAccentTeal,
              ),
              label: const Text('楽天で見る'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: postTooltip,
            child: Semantics(
              button: true,
              label: 'post_management_item_post_button',
              child: FilledButton(
                onPressed: postActionsDisabled
                    ? null
                    : () async {
                        if (onCollectPressed != null) {
                          await onCollectPressed!(context, product);
                          return;
                        }
                        await provider.collectRoomAndLaunch(
                          context,
                          product.productId,
                        );
                      },
                style: _cardPrimaryButtonStyle(enabled: !postActionsDisabled),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('投稿する', maxLines: 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveCandidate(
    BuildContext context,
    RakutenManagedProductProvider provider,
  ) async {
    final name = DisplayTextUtils.truncateProductName(_safeItemName(product));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補から外す'),
        content: Text('「$name」を候補から外します。よろしいですか？'),
        actions: [
          AppSecondaryButton(
            label: 'キャンセル',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppSecondaryButton(
            label: '候補から外す',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await provider.removeCandidate(context, product.productId);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Widget _doneActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    final roomPage = product.roomUrl.trim();
    final hasRoomPage = roomPage.isNotEmpty;
    final postUrl = product.extractedUrl.trim();
    final canOpenRoomPost =
        product.extractionStatus == RakutenUrlExtractionStatus.success &&
        postUrl.isNotEmpty;

    Future<void> openRoomPostFlow() async {
      if (canOpenRoomPost) {
        await AppActionService.openUrl(context, url: postUrl);
        return;
      }
      final profileRoom = context
          .read<UserProfileProvider>()
          .profile
          .roomUrl
          .trim();
      if (profileRoom.isNotEmpty) {
        await AppActionService.openUrl(context, url: profileRoom);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('マイページでROOMのプロフィールURLを登録してください')),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;

        final narrow = constraints.maxWidth < 300;
        final itemWidth = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        if (hasRoomPage) {
          final roomView = Tooltip(
            message: '楽天ROOMの商品ページを開きます',
            child: OutlinedButton.icon(
              onPressed: () =>
                  AppActionService.openUrl(context, url: roomPage),
              style: _cardOutlineButtonStyle(enabled: true),
              icon: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: HomeScreenColors.homeAccentTeal,
              ),
              label: const Text('ROOMで見る'),
            ),
          );

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: itemWidth,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final err = await provider.openRakutenItemPage(
                      context,
                      product.productId,
                    );
                    if (!context.mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  style: _cardOutlineButtonStyle(enabled: true),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: HomeScreenColors.homeAccentTeal,
                  ),
                  label: const Text('楽天で見る'),
                ),
              ),
              SizedBox(width: itemWidth, child: roomView),
            ],
          );
        }

        final roomPost = FilledButton(
          onPressed: () => openRoomPostFlow(),
          style: _cardPrimaryButtonStyle(enabled: true),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('ROOM投稿へ', maxLines: 1),
          ),
        );

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final err = await provider.openRakutenItemPage(
                    context,
                    product.productId,
                  );
                  if (!context.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                style: _cardOutlineButtonStyle(enabled: true),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('楽天で見る'),
              ),
            ),
            SizedBox(width: itemWidth, child: roomPost),
          ],
        );
      },
    );
  }

  Widget _heroImage(BuildContext context) {
    Widget child;
    try {
      final url = product.imageUrl.trim();
      if (url.isNotEmpty) {
        child = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: _thumbPlaceholder()),
        );
      } else {
        child = Center(child: _thumbPlaceholder());
      }
    } catch (_) {
      child = Center(child: _thumbPlaceholder());
    }
    return Material(
      color: AppColors.surfaceVariant,
      child: InkWell(
        onTap: () => _openRakuten(context, 'image'),
        child: child,
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 36,
      color: AppColors.textTertiary.withValues(alpha: 0.65),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _FeedbackToggleButton extends StatelessWidget {
  const _FeedbackToggleButton({
    required this.label,
    required this.selected,
    required this.icon,
    required this.selectedColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? selectedColor : AppColors.textSecondary;
    final bg = selected
        ? selectedColor.withValues(alpha: 0.13)
        : Colors.transparent;
    final border = selected
        ? selectedColor.withValues(alpha: 0.72)
        : AppColors.divider.withValues(alpha: 0.82);

    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          side: BorderSide(color: border, width: selected ? 1.4 : 1),
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: AppTextStyles.label.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: fg,
          ),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
