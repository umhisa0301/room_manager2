import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/admob_config.dart';
import 'ad_placeholder_slot.dart';
import 'monetization_ad_placement.dart';

/// homeBottomBanner 用の AdMob バナー広告枠。
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

  Future<void> _loadAd() async {
    if (_disposed || !mounted) {
      return;
    }
    if (widget.loadAdForTesting == false) {
      return;
    }

    final adUnitId = AdMobConfig.homeBottomBannerAdUnitId();
    if (adUnitId == null) {
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
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('[ADMOB] banner load failed ${error.message}');
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
      debugPrint('[ADMOB] banner load failed $error');
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
