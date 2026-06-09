import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/services/rakuten_item_page_url_item_code_service.dart';
import 'package:room_manager2/utils/rakuten_product_rating_display.dart';

/// Phase 4-P2 実機ログ確認用（一度だけ実行）。
///
/// flutter run -d <device> -t tool/phase4_p2_device_verify.dart \
///   --dart-define=PRODUCT_CATALOG_ENABLED=true \
///   --dart-define=SHOP_CATALOG_ENABLED=true \
///   --dart-define=CATALOG_AUDIT_LOGS=false
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[PHASE4_P2_DEVICE_VERIFY] start');
  await _verifyUrlParseCases();
  await _verifyUrlSearchApiCases();
  _verifyRatingDisplayCases();
  debugPrint('[PHASE4_P2_DEVICE_VERIFY] done');
  runApp(const _DoneApp());
}

Future<void> _verifyUrlParseCases() async {
  const itemUrl = 'https://item.rakuten.co.jp/soukaidrink/4901085161999/';
  final affiliateUrl =
      'https://hb.afl.rakuten.co.jp/hgc/test/?pc=${Uri.encodeComponent(itemUrl)}';
  final cases = <({String label, String url, bool expectSuccess})>[
    (label: 'normal', url: itemUrl, expectSuccess: true),
    (
      label: 'slug',
      url: 'https://item.rakuten.co.jp/expsjapan/cim-silicone-cover-001-/',
      expectSuccess: true,
    ),
    (label: 'affiliate', url: affiliateUrl, expectSuccess: true),
    (
      label: 'books',
      url: 'https://books.rakuten.co.jp/rb/1234567890/',
      expectSuccess: false,
    ),
    (
      label: 'fashion',
      url: 'https://brandavenue.rakuten.co.jp/item/foo/',
      expectSuccess: false,
    ),
  ];

  for (final c in cases) {
    debugPrint('[PHASE4_P2_DEVICE_VERIFY] parseCase=${c.label} url=${c.url}');
    final result = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
      c.url,
    );
    if (c.expectSuccess) {
      if (result is RakutenItemPageUrlParseSuccess) {
        debugPrint(
          '[PHASE4_P2_DEVICE_VERIFY] parseCase=${c.label} ok '
          'itemCode=${result.itemCode} normalizedUrl=${result.normalizedUrl}',
        );
      } else {
        debugPrint(
          '[PHASE4_P2_DEVICE_VERIFY] parseCase=${c.label} FAIL unexpectedFailure',
        );
      }
    } else if (result is RakutenItemPageUrlParseFailure) {
      debugPrint(
        '[PHASE4_P2_DEVICE_VERIFY] parseCase=${c.label} unsupported=${result.isUnsupportedUrlType} '
        'message=${result.userMessage}',
      );
    } else {
      debugPrint(
        '[PHASE4_P2_DEVICE_VERIFY] parseCase=${c.label} FAIL expectedUnsupported',
      );
    }
  }
}

Future<void> _verifyUrlSearchApiCases() async {
  final repo = RakutenSearchRepository(apiService: RakutenApiService());
  const apiCases =
      <({String label, String url, String shop, String item, bool apiStyle})>[
        (
          label: 'normalApi',
          url: 'https://item.rakuten.co.jp/soukaidrink/4901085161999/',
          shop: 'soukaidrink',
          item: '4901085161999',
          apiStyle: true,
        ),
        (
          label: 'slugApi',
          url: 'https://item.rakuten.co.jp/expsjapan/cim-silicone-cover-001-/',
          shop: 'expsjapan',
          item: 'cim-silicone-cover-001-',
          apiStyle: false,
        ),
      ];

  for (final c in apiCases) {
    debugPrint('[PHASE4_P2_DEVICE_VERIFY] apiCase=${c.label} start');
    final outcome = await repo.resolveProductForUrlSearch(
      inputUrl: c.url,
      shopCode: c.shop,
      pureItemCode: c.item,
      isApiStyleItemCode: c.apiStyle,
    );
    debugPrint(
      '[PHASE4_P2_DEVICE_VERIFY] apiCase=${c.label} '
      'success=${outcome.item != null} rateLimited=${outcome.rateLimited} '
      'strategy=${outcome.strategy}',
    );
  }
}

void _verifyRatingDisplayCases() {
  final withReview = RakutenProductRatingDisplay.formatProductCardLabel(
    reviewAverage: 4.33,
    reviewCount: 630,
  );
  RakutenProductRatingDisplay.traceLog(
    source: 'phase4P2DeviceVerify',
    productId: 'verify:withReview',
    reviewAverage: 4.33,
    reviewCount: 630,
    displayText: withReview,
  );

  final withoutReview = RakutenProductRatingDisplay.formatProductCardLabel(
    reviewAverage: 0,
    reviewCount: 0,
  );
  RakutenProductRatingDisplay.traceLog(
    source: 'phase4P2DeviceVerify',
    productId: 'verify:withoutReview',
    reviewAverage: 0,
    reviewCount: 0,
    displayText: withoutReview,
  );
}

class _DoneApp extends StatelessWidget {
  const _DoneApp();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: Color(0xFF1B5E20)),
    );
  }
}
