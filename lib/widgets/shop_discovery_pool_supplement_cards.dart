import 'package:flutter/material.dart';

import '../services/shop_discovery_pool_supplement_ui_bridge.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import 'app_card.dart';

/// 補助枠カードの文言（断定を避けた控えめ表現）。
abstract final class ShopDiscoveryPoolSupplementCardCopy {
  ShopDiscoveryPoolSupplementCardCopy._();

  static const String sectionTitle = '追加で見つかったショップ候補';
  static const String supplementLabel = 'アプリ内データより';

  static String reasonText(
    ShopDiscoveryPoolSupplementUiDisplayCandidate candidate,
  ) {
    if (candidate.genreAligned) {
      return '検索キーワードと関連するジャンルの商品が見つかりました';
    }
    if (candidate.strongItemEvidence) {
      return '商品名に検索キーワードを含む商品が多く見つかりました';
    }
    return '関連する商品が見つかりました';
  }
}

/// ShopPool supplement の UI 表示候補を、通常 API 結果とは別枠で並べる。
class ShopDiscoveryPoolSupplementCardsSection extends StatelessWidget {
  const ShopDiscoveryPoolSupplementCardsSection({
    super.key,
    required this.candidates,
    this.onCandidateTap,
  });

  final List<ShopDiscoveryPoolSupplementUiDisplayCandidate> candidates;
  final ValueChanged<ShopDiscoveryPoolSupplementUiDisplayCandidate>?
      onCandidateTap;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.screenPadH,
        0,
        RakutenSearchScreenUi.screenPadH,
        RakutenSearchScreenUi.gapFieldStack,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeScreenColors.subActionRowFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HomeScreenColors.deckOutline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ShopDiscoveryPoolSupplementCardCopy.sectionTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '通常の検索結果とは別枠の候補です',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: HomeScreenColors.footnoteMuted,
                  height: 1.32,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < candidates.length; index++) ...[
                if (index > 0) const SizedBox(height: 6),
                _ShopDiscoveryPoolSupplementCard(
                  candidate: candidates[index],
                  onTap: onCandidateTap,
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopDiscoveryPoolSupplementCard extends StatelessWidget {
  const _ShopDiscoveryPoolSupplementCard({
    required this.candidate,
    this.onTap,
  });

  final ShopDiscoveryPoolSupplementUiDisplayCandidate candidate;
  final ValueChanged<ShopDiscoveryPoolSupplementUiDisplayCandidate>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = ShopDiscoveryPoolSupplementCardCopy.reasonText(candidate);

    return AppCard(
      padding: const EdgeInsets.all(10),
      radius: 10,
      backgroundColor: HomeScreenColors.roomContentWellFill,
      borderColor: HomeScreenColors.deckOutline,
      onTap: onTap == null ? null : () => onTap!(candidate),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  candidate.shopName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: HomeScreenColors.flowStepBadgeFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HomeScreenColors.deckOutline),
                ),
                child: Text(
                  ShopDiscoveryPoolSupplementCardCopy.supplementLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: HomeScreenColors.statusAccentStrong,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.metricTileCaptionColor,
              height: 1.35,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
