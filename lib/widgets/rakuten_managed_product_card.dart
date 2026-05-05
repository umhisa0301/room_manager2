import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/room_colle_list_accent.dart';
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

  String _genreLabel() {
    final id = product.genreId.trim();
    final prefetched = genrePrefetchLabels?[id];
    final persisted = product.persistedGenreDisplayName?.trim();
    if (prefetched != null && prefetched.trim().isNotEmpty) {
      return prefetched.trim();
    }
    if (persisted != null && persisted.isNotEmpty) return persisted;
    return id.isEmpty ? 'ジャンル未設定' : 'ジャンル $id';
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
    final hasPositiveSignal =
        product.feedbackSoldAt != null || product.feedbackLikedAt != null;
    if (hasPositiveSignal) return '評価 反応あり';
    if (product.feedbackWeakAt != null) return '評価 微妙';
    return '評価 楽天で確認';
  }

  @override
  Widget build(BuildContext context) {
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final theme = Theme.of(context);
    final titleStyle = RoomColleProductListCardLayout.titleTextStyle(theme);
    final priceStyle = RoomColleProductListCardLayout.priceTextStyle(theme);
    final timestampStyle = RoomColleProductListCardLayout.metaTextStyle(theme);
    final reactionStyle =
        (timestampStyle ?? theme.textTheme.bodySmall ?? const TextStyle())
            .copyWith(fontSize: 11, fontWeight: FontWeight.w700);

    return RoomColleProductListCardShell(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoomColleProductListCardThumbSlot(child: _heroImage()),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCandidate) ...[
                        if (product.roomUrl.trim().isNotEmpty)
                          const Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _SmallBadge(
                                label: 'ROOM投稿済み',
                                color: Color(0xFF1B5E20),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _SmallBadge(
                                label: '未取り込み',
                                color: Color(0xFF6D4C41),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                      ],
                      if (isCandidate) ...[
                        _candidateBadges(context),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        _safeItemName(product),
                        maxLines: RoomColleProductListCardLayout.titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _safePriceYen(product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: priceStyle,
                      ),
                      if (isCandidate) ...[
                        const SizedBox(height: 6),
                        _ratingRow(context),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${product.shopName.trim().isEmpty ? 'ショップ未設定' : product.shopName.trim()} / ${_genreLabel()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: timestampStyle,
                      ),
                      if (!isCandidate &&
                          (product.roomLikeCount != null ||
                              product.roomCommentCount != null)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (product.roomLikeCount != null)
                              Text(
                                '♡${product.roomLikeCount}',
                                style: reactionStyle,
                              ),
                            if (product.roomCommentCount != null)
                              Text(
                                '💬${product.roomCommentCount}',
                                style: reactionStyle,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Builder(
                        builder: (ctx) {
                          final line = isCandidate
                              ? _candidateRegisteredMetaLine(product.addedAt)
                              : _donePostedMetaLine(product);
                          final tip = isCandidate
                              ? null
                              : _donePostedMetaTooltip(product);
                          Widget child = Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: timestampStyle,
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
              const SizedBox(height: 8),
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
    final badges = <Widget>[];
    if (isTodayRecommendationCandidate) {
      badges.add(_decisionBadge(context));
    }
    if (isSavedShop) {
      badges.add(const _SmallBadge(label: '保存ショップ', color: Color(0xFF1565C0)));
    }
    if (_hasRoomLinkForBadge) {
      badges.add(
        const _SmallBadge(label: 'ROOM URLあり', color: Color(0xFF2E7D32)),
      );
    }
    if (badges.isEmpty) {
      badges.add(
        _SmallBadge(label: 'コレ候補', color: RoomColleListAccent.candidate),
      );
    }
    return Wrap(spacing: 5, runSpacing: 4, children: badges);
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
    final liked = product.feedbackLikedAt != null;
    final sold = product.feedbackSoldAt != null;
    final weak = product.feedbackWeakAt != null;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final narrow = constraints.maxWidth < 340;
        final halfWidth = (constraints.maxWidth - gap) / 2;
        final thirdWidth = (constraints.maxWidth - gap * 2) / 3;

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

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: narrow ? halfWidth : thirdWidth,
              child: _DecisionActionButton(
                label: '楽天で見る',
                tone: _DecisionActionTone.external,
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
              ),
            ),
            SizedBox(
              width: narrow ? halfWidth : thirdWidth,
              child: Tooltip(
                message: postTooltip,
                child: _DecisionActionButton(
                  label: '投稿する',
                  tone: _DecisionActionTone.primary,
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
                ),
              ),
            ),
            SizedBox(
              width: narrow ? constraints.maxWidth : thirdWidth,
              child: _DecisionActionButton(
                label: '候補から外す',
                tone: _DecisionActionTone.destructive,
                onPressed: () => _confirmRemoveCandidate(context, provider),
              ),
            ),
          ],
        );
      },
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

    const roomViewAccent = Color(0xFFD81B60);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final rakuten = _DecisionActionButton(
          label: '楽天で見る',
          tone: _DecisionActionTone.external,
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
        );

        final narrow = constraints.maxWidth < 300;
        final itemWidth = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        if (hasRoomPage) {
          final roomView = Tooltip(
            message: '楽天ROOMの商品ページを開きます',
            child: SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () =>
                    AppActionService.openUrl(context, url: roomPage),
                style: OutlinedButton.styleFrom(
                  foregroundColor: roomViewAccent,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: roomViewAccent.withValues(alpha: 0.72),
                  ),
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('ROOMで見る'),
                ),
              ),
            ),
          );

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(width: itemWidth, child: rakuten),
              SizedBox(width: itemWidth, child: roomView),
            ],
          );
        }

        final roomPost = _DecisionActionButton(
          label: 'ROOM投稿へ',
          tone: _DecisionActionTone.primary,
          onPressed: () => openRoomPostFlow(),
        );

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(width: itemWidth, child: rakuten),
            SizedBox(width: itemWidth, child: roomPost),
          ],
        );
      },
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

enum _DecisionActionTone { external, primary, destructive }

class _DecisionActionButton extends StatelessWidget {
  const _DecisionActionButton({
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final _DecisionActionTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isPrimary = tone == _DecisionActionTone.primary;
    final isDestructive = tone == _DecisionActionTone.destructive;
    final fg = isPrimary
        ? AppColors.textOnAccent
        : isDestructive
        ? AppColors.textSecondary
        : AppColors.accentPrimary;
    final bg = isPrimary
        ? AppColors.accentPrimary
        : isDestructive
        ? AppColors.surfaceVariant
        : Colors.transparent;
    final border = isPrimary
        ? AppColors.accentPrimary
        : isDestructive
        ? AppColors.divider
        : AppColors.accentPrimary.withValues(alpha: 0.72);

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          disabledForegroundColor: AppColors.textTertiary,
          disabledBackgroundColor: isPrimary
              ? AppColors.accentPrimary.withValues(alpha: 0.28)
              : AppColors.surfaceVariant.withValues(alpha: 0.75),
          side: BorderSide(color: border, width: isPrimary ? 0 : 1),
          elevation: isPrimary ? 1.2 : 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false),
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
