import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/admob_config.dart';
import 'ad_placeholder_slot.dart';
import 'monetization_ad_placement.dart';

/// バナー配置（homeBottomBanner / todayRecommendationSummaryBanner）用 AdMob 枠。
class AdMobBannerAdSlot extends StatefulWidget {
  const AdMobBannerAdSlot({
    super.key,
    required this.placement,
    this.fallback,
    this.loadAdForTesting,
  });

  final MonetizationAdPlacement placement;
  final Widget? fallback;

  /// テスト用。`false` のとき広告ロードをスキップする。
  final bool? loadAdForTesting;

  @override
  State<AdMobBannerAdSlot> createState() => AdMobBannerAdSlotState();
}

@visibleForTesting
class AdMobBannerAdSlotState extends State<AdMobBannerAdSlot> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _loadFailed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  String get _placementLogLabel => widget.placement.name;

  String? _resolveAdUnitId() {
    switch (widget.placement) {
      case MonetizationAdPlacement.homeBottomBanner:
        return AdMobConfig.homeBottomBannerAdUnitId();
      case MonetizationAdPlacement.todayRecommendationSummaryBanner:
        return AdMobConfig.todayRecommendationSummaryBannerAdUnitId();
      case MonetizationAdPlacement.rakutenSearchNativeList:
      case MonetizationAdPlacement.rewardedRecommendationRefresh:
        return null;
    }
  }

  Future<void> _loadAd() async {
    if (_disposed || !mounted) {
      return;
    }
    if (widget.loadAdForTesting == false) {
      return;
    }

    debugPrint('[ADMOB] $_placementLogLabel banner load requested');

    final adUnitId = _resolveAdUnitId();
    if (adUnitId == null || adUnitId.isEmpty) {
      debugPrint(
        '[ADMOB] $_placementLogLabel skipped: ad unit id is empty',
      );
      if (mounted) {
        setState(() => _loadFailed = true);
      }
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    AdSize? size;
    try {
      size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    } catch (error) {
      debugPrint('[ADMOB] banner size resolve failed $error');
    }
    size ??= AdSize.banner;

    BannerAd? bannerAd;
    try {
      bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (_disposed || !mounted) {
              ad.dispose();
              return;
            }
            debugPrint('[ADMOB] $_placementLogLabel banner loaded');
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint(
              '[ADMOB] $_placementLogLabel banner failed to load',
            );
            ad.dispose();
            if (!mounted || _disposed) {
              return;
            }
            setState(() => _loadFailed = true);
          },
        ),
      );
      await bannerAd.load();
    } catch (error) {
      debugPrint('[ADMOB] $_placementLogLabel banner failed to load');
      bannerAd?.dispose();
      if (!mounted || _disposed) {
        return;
      }
      setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  Widget _buildFallback() {
    return widget.fallback ??
        MonetizationBannerPlaceholder(placement: widget.placement);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return _buildFallback();
    }
    final ad = _bannerAd;
    if (!_isLoaded || ad == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: '広告',
      container: true,
      child: SizedBox(
        key: Key('monetization_ad_slot_${widget.placement.name}'),
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
