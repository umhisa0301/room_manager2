import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/room_colle_list_accent.dart';
import '../utils/room_colle_candidate_stale.dart';
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

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

  bool get _hasRoomUrl => product.extractedUrl.trim().isNotEmpty;

  static String _safeItemName(RakutenManagedProduct product) {
    try {
      final t = product.itemName.trim();
      return t.isEmpty ? '（商品名なし）' : t;
    } catch (_) {
      return '（商品名なし）';
    }
  }

  static String _safeShopName(RakutenManagedProduct product) {
    try {
      final t = product.shopName.trim();
      return t.isEmpty ? 'ショップ名なし' : t;
    } catch (_) {
      return 'ショップ名なし';
    }
  }

  static String _safePriceYen(RakutenManagedProduct product) {
    try {
      return RoomColleProductListCardLayout.formatPriceYen(product.itemPrice);
    } catch (_) {
      return '価格 —';
    }
  }

  static String _dateMetaLabel({
    required bool isCandidate,
    required DateTime? instant,
  }) {
    final stamp = formatRoomColleCardTimestamp(instant, DateTime.now());
    if (stamp == null || stamp.isEmpty) {
      return isCandidate ? '登録日: -' : 'コレ日: -';
    }
    return isCandidate ? '登録日: $stamp' : 'コレ日: $stamp';
  }

  @override
  Widget build(BuildContext context) {
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final stateAccent = isCandidate
        ? RoomColleListAccent.candidate
        : RoomColleListAccent.done;

    final theme = Theme.of(context);
    final titleStyle = RoomColleProductListCardLayout.titleTextStyle(theme);
    final priceStyle = RoomColleProductListCardLayout.priceTextStyle(theme);
    final shopStyle = RoomColleProductListCardLayout.shopTextStyle(theme);
    final tsInstant = isCandidate ? product.addedAt : product.doneAt;
    final timestampStyle = RoomColleProductListCardLayout.metaTextStyle(theme);
    final staleSpec = isCandidate
        ? RoomColleCandidateStaleSpec.resolve(product.addedAt, DateTime.now())
        : null;
    final genreLineBase =
        shopStyle ?? theme.textTheme.bodySmall ?? const TextStyle();
    final genreLineStyle = genreLineBase.copyWith(
      fontSize: (genreLineBase.fontSize ?? 12) - 1,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return RoomColleProductListCardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoomColleProductListCardThumbSlot(child: _heroImage()),
          Expanded(
            child: Padding(
              padding: RoomColleProductListCardLayout.rightColumnPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        _safeItemName(product),
                        maxLines: RoomColleProductListCardLayout.titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _safePriceYen(product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: priceStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _safeShopName(product),
                        maxLines: RoomColleProductListCardLayout.shopMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: shopStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RakutenProductGenreDisplay.resolve(
                          apiGenreName: null,
                          persistedGenreName: product.persistedGenreDisplayName,
                          prefetchedGenreName:
                              genrePrefetchLabels?[product.genreId.trim()],
                          genreId: product.genreId,
                          traceItemCode: product.productId,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: genreLineStyle,
                      ),
                      const SizedBox(height: 3),
                      if (staleSpec != null) ...[
                        RoomColleCandidateStaleChip(spec: staleSpec),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        _dateMetaLabel(
                          isCandidate: isCandidate,
                          instant: tsInstant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: timestampStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _feedbackToolbar(context),
                  const SizedBox(height: 5),
                  if (isCandidate)
                    _candidateActions(context)
                  else
                    _doneActions(context, stateAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackToolbar(BuildContext context) {
    final prov = context.read<RakutenManagedProductProvider>();
    final liked = product.feedbackLikedAt != null;
    final sold = product.feedbackSoldAt != null;
    final weak = product.feedbackWeakAt != null;
    return Row(
      children: [
        Expanded(
          child: AppSecondaryButton(
            label: liked ? '反応◎' : '反応',
            onPressed: () async {
              final err = await prov.toggleFeedbackLiked(
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
            height: 30,
            expand: true,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AppSecondaryButton(
            label: sold ? '売れた◎' : '売れた',
            onPressed: () async {
              final err = await prov.toggleFeedbackSold(
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
            height: 30,
            expand: true,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AppSecondaryButton(
            label: weak ? '微妙◎' : '微妙',
            onPressed: () async {
              final err = await prov.toggleFeedbackWeak(
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
            height: 30,
            expand: true,
          ),
        ),
      ],
    );
  }

  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 34,
          child: AppPrimaryButton(
            label: '楽天で見る',
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
            icon: const Icon(Icons.open_in_new_rounded),
            height: 36,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 44,
          child: Tooltip(
            message: _canCollectRoom
                ? 'ROOMのURLを開き、一覧をコレ済に移します。'
                : 'ROOM用のURLが取得できるまでお待ちください',
            child: AppPrimaryButton(
              label: 'ROOMに投稿',
              onPressed: _canCollectRoom
                  ? () async {
                      if (onCollectPressed != null) {
                        await onCollectPressed!(context, product);
                        return;
                      }
                      await provider.collectRoomAndLaunch(
                        context,
                        product.productId,
                      );
                    }
                  : null,
              icon: Icon(
                _canCollectRoom
                    ? Icons.favorite_rounded
                    : Icons.hourglass_top_rounded,
              ),
              height: 36,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 22,
          child: AppSecondaryButton(
            label: '削除',
            onPressed: () => _confirmRemoveCandidate(context, provider),
            icon: const Icon(Icons.delete_outline_rounded),
            expand: true,
            height: 36,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveCandidate(
    BuildContext context,
    RakutenManagedProductProvider provider,
  ) async {
    final name = _safeItemName(product);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補から削除'),
        content: Text('「$name」をコレ候補から削除します。よろしいですか？'),
        actions: [
          AppSecondaryButton(
            label: 'キャンセル',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppSecondaryButton(
            label: '削除',
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

  Widget _doneActions(BuildContext context, Color stateAccent) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 40,
          child: AppPrimaryButton(
            label: '楽天で見る',
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
            icon: const Icon(Icons.open_in_new_rounded),
            height: 36,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 36,
          child: Tooltip(
            message: _hasRoomUrl ? 'ROOMの画面を開きます' : 'ROOM用のリンクが取得されていません',
            child: AppSecondaryButton(
              label: 'ROOMで確認',
              onPressed: _hasRoomUrl
                  ? () => AppActionService.openUrl(
                      context,
                      url: product.extractedUrl.trim(),
                    )
                  : null,
              icon: Icon(
                _hasRoomUrl
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.link_off_rounded,
              ),
              expand: true,
              height: 36,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 24,
          child: AppSecondaryButton(
            label: 'ID',
            onPressed: product.productId.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: product.productId.trim()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('商品IDをコピーしました'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            icon: const Icon(Icons.copy_rounded),
            expand: true,
            height: 36,
          ),
        ),
      ],
    );
  }

  Widget _heroImage() {
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
    return ColoredBox(color: AppColors.surfaceVariant, child: child);
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 30,
      color: AppColors.textTertiary.withValues(alpha: 0.65),
    );
  }
}
