import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../models/saved_shop.dart';
import '../models/today_recommendation.dart';

/// クローズドテスト用データ（実データと完全分離）。
abstract final class DemoModeData {
  static List<RakutenManagedProduct> managedProducts() {
    final now = DateTime.now();
    return <RakutenManagedProduct>[
      RakutenManagedProduct(
        productId: 'demo_item_001',
        itemName: '北欧デザイン マグカップ 2個セット',
        itemPrice: 2980,
        itemUrl: 'https://item.rakuten.co.jp/demo/scandi-mug-set/',
        affiliateUrl: 'https://item.rakuten.co.jp/demo/scandi-mug-set/?scid=demo',
        imageUrl: 'https://picsum.photos/seed/demo001/400/400',
        shopName: 'くらし雑貨ストア',
        shopCode: 'demo_shop_001',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-001/',
        genreId: '100717',
        genreName: 'キッチン用品・食器・調理器具',
        resolvedGenreName: '食器',
        status: RakutenManagedProductStatus.candidate,
        createdAt: now.subtract(const Duration(days: 6, hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 4)),
        addedAt: now.subtract(const Duration(days: 6, hours: 2)),
        extractedUrl: 'https://room.rakuten.co.jp/demo/collect/001',
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractionErrorMessage: '',
        extractedAt: now.subtract(const Duration(days: 6, hours: 1)),
      ),
      RakutenManagedProduct(
        productId: 'demo_item_002',
        itemName: '軽量 折りたたみ傘 UVカット 55cm',
        itemPrice: 3680,
        itemUrl: 'https://item.rakuten.co.jp/demo/uv-umbrella/',
        affiliateUrl: 'https://item.rakuten.co.jp/demo/uv-umbrella/?scid=demo',
        imageUrl: 'https://picsum.photos/seed/demo002/400/400',
        shopName: 'Daily Outdoor',
        shopCode: 'demo_shop_002',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-002/',
        genreId: '207640',
        genreName: 'バッグ・小物・ブランド雑貨',
        resolvedGenreName: '傘',
        status: RakutenManagedProductStatus.candidate,
        createdAt: now.subtract(const Duration(days: 5, hours: 5)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
        addedAt: now.subtract(const Duration(days: 5, hours: 5)),
        extractedUrl: 'https://room.rakuten.co.jp/demo/collect/002',
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractionErrorMessage: '',
        extractedAt: now.subtract(const Duration(days: 5, hours: 4)),
      ),
      RakutenManagedProduct(
        productId: 'demo_item_003',
        itemName: '耐熱 ガラス保存容器 7点セット',
        itemPrice: 4480,
        itemUrl: 'https://item.rakuten.co.jp/demo/glass-container/',
        affiliateUrl:
            'https://item.rakuten.co.jp/demo/glass-container/?scid=demo',
        imageUrl: 'https://picsum.photos/seed/demo003/400/400',
        shopName: 'キッチンラボ',
        shopCode: 'demo_shop_003',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-003/',
        genreId: '100628',
        genreName: 'キッチン用品・食器・調理器具',
        resolvedGenreName: '保存容器',
        status: RakutenManagedProductStatus.candidate,
        createdAt: now.subtract(const Duration(days: 3, hours: 3)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 6)),
        addedAt: now.subtract(const Duration(days: 3, hours: 3)),
        extractedUrl: 'https://room.rakuten.co.jp/demo/collect/003',
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractionErrorMessage: '',
        extractedAt: now.subtract(const Duration(days: 3, hours: 2)),
      ),
      RakutenManagedProduct(
        productId: 'demo_item_101',
        itemName: 'USB充電式 ハンディファン 3段風量',
        itemPrice: 2580,
        itemUrl: 'https://item.rakuten.co.jp/demo/handy-fan/',
        affiliateUrl: 'https://item.rakuten.co.jp/demo/handy-fan/?scid=demo',
        imageUrl: 'https://picsum.photos/seed/demo101/400/400',
        shopName: 'Life Gadget',
        shopCode: 'demo_shop_004',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-004/',
        genreId: '565421',
        genreName: '家電',
        resolvedGenreName: '季節家電',
        status: RakutenManagedProductStatus.done,
        createdAt: now.subtract(const Duration(days: 8, hours: 8)),
        updatedAt: now.subtract(const Duration(days: 2, hours: 2)),
        addedAt: now.subtract(const Duration(days: 8, hours: 8)),
        extractedUrl: 'https://room.rakuten.co.jp/demo/collect/101',
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractionErrorMessage: '',
        extractedAt: now.subtract(const Duration(days: 8, hours: 7)),
        doneAt: now.subtract(const Duration(days: 2, hours: 2)),
      ),
      RakutenManagedProduct(
        productId: 'demo_item_102',
        itemName: '高反発 クッションチェア 座椅子',
        itemPrice: 6980,
        itemUrl: 'https://item.rakuten.co.jp/demo/cushion-chair/',
        affiliateUrl: 'https://item.rakuten.co.jp/demo/cushion-chair/?scid=demo',
        imageUrl: 'https://picsum.photos/seed/demo102/400/400',
        shopName: '北欧インテリア館',
        shopCode: 'demo_shop_005',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-005/',
        genreId: '215538',
        genreName: 'インテリア・寝具・収納',
        resolvedGenreName: '座椅子',
        status: RakutenManagedProductStatus.done,
        createdAt: now.subtract(const Duration(days: 10, hours: 6)),
        updatedAt: now.subtract(const Duration(days: 4, hours: 3)),
        addedAt: now.subtract(const Duration(days: 10, hours: 6)),
        extractedUrl: 'https://room.rakuten.co.jp/demo/collect/102',
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractionErrorMessage: '',
        extractedAt: now.subtract(const Duration(days: 10, hours: 5)),
        doneAt: now.subtract(const Duration(days: 4, hours: 3)),
      ),
    ];
  }

  static List<SavedShop> savedShops() {
    final now = DateTime.now();
    return <SavedShop>[
      SavedShop(
        shopId: 'demo_shop_001',
        shopName: 'くらし雑貨ストア',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-001/',
        savedAt: now.subtract(const Duration(days: 14)),
        lastViewedAt: now.subtract(const Duration(days: 1, hours: 8)),
      ),
      SavedShop(
        shopId: 'demo_shop_003',
        shopName: 'キッチンラボ',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-003/',
        savedAt: now.subtract(const Duration(days: 12)),
        lastViewedAt: now.subtract(const Duration(days: 2, hours: 4)),
      ),
      SavedShop(
        shopId: 'demo_shop_004',
        shopName: 'Life Gadget',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-004/',
        savedAt: now.subtract(const Duration(days: 9)),
        lastViewedAt: now.subtract(const Duration(hours: 20)),
      ),
      SavedShop(
        shopId: 'demo_shop_005',
        shopName: '北欧インテリア館',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-005/',
        savedAt: now.subtract(const Duration(days: 7)),
        lastViewedAt: now.subtract(const Duration(days: 3, hours: 5)),
      ),
    ];
  }

  static List<RakutenSearchItem> searchItems() {
    return <RakutenSearchItem>[
      _searchItem(
        id: 'demo_search_001',
        name: 'ステンレス 保温マグ 500ml',
        price: 3280,
        shopName: 'くらし雑貨ストア',
        shopCode: 'demo_shop_001',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-001/',
        genreId: '100717',
        genreName: 'キッチン用品・食器・調理器具',
        reviewCount: 268,
        reviewAverage: 4.52,
      ),
      _searchItem(
        id: 'demo_search_002',
        name: 'シリコン調理スプーン 2本セット',
        price: 1780,
        shopName: 'キッチンラボ',
        shopCode: 'demo_shop_003',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-003/',
        genreId: '100628',
        genreName: 'キッチン用品・食器・調理器具',
        reviewCount: 194,
        reviewAverage: 4.41,
      ),
      _searchItem(
        id: 'demo_search_003',
        name: 'ワイヤレス充電器 Qi対応 15W',
        price: 2480,
        shopName: 'Life Gadget',
        shopCode: 'demo_shop_004',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-004/',
        genreId: '565421',
        genreName: '家電',
        reviewCount: 311,
        reviewAverage: 4.36,
      ),
      _searchItem(
        id: 'demo_search_004',
        name: 'LEDデスクライト 調光調色タイプ',
        price: 4580,
        shopName: 'Life Gadget',
        shopCode: 'demo_shop_004',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-004/',
        genreId: '565421',
        genreName: '家電',
        reviewCount: 143,
        reviewAverage: 4.22,
      ),
      _searchItem(
        id: 'demo_search_005',
        name: '洗える ラグマット 185x185',
        price: 5980,
        shopName: '北欧インテリア館',
        shopCode: 'demo_shop_005',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-005/',
        genreId: '215538',
        genreName: 'インテリア・寝具・収納',
        reviewCount: 402,
        reviewAverage: 4.58,
      ),
      _searchItem(
        id: 'demo_search_006',
        name: '折りたたみ 収納ボックス 3個組',
        price: 3880,
        shopName: '北欧インテリア館',
        shopCode: 'demo_shop_005',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-005/',
        genreId: '215783',
        genreName: 'インテリア・寝具・収納',
        reviewCount: 256,
        reviewAverage: 4.47,
      ),
      _searchItem(
        id: 'demo_search_007',
        name: 'UVカット ロングカーディガン',
        price: 2980,
        shopName: 'Daily Outdoor',
        shopCode: 'demo_shop_002',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-002/',
        genreId: '100371',
        genreName: 'レディースファッション',
        reviewCount: 129,
        reviewAverage: 4.19,
      ),
      _searchItem(
        id: 'demo_search_008',
        name: '撥水 トートバッグ 大容量',
        price: 3420,
        shopName: 'Daily Outdoor',
        shopCode: 'demo_shop_002',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-002/',
        genreId: '110933',
        genreName: 'バッグ・小物・ブランド雑貨',
        reviewCount: 177,
        reviewAverage: 4.33,
      ),
      _searchItem(
        id: 'demo_search_009',
        name: '木製 カッティングボード まな板',
        price: 2380,
        shopName: 'キッチンラボ',
        shopCode: 'demo_shop_003',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-003/',
        genreId: '210168',
        genreName: 'キッチン用品・食器・調理器具',
        reviewCount: 88,
        reviewAverage: 4.11,
      ),
      _searchItem(
        id: 'demo_search_010',
        name: 'スタッキング 保存容器 角型セット',
        price: 4180,
        shopName: 'キッチンラボ',
        shopCode: 'demo_shop_003',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-003/',
        genreId: '100628',
        genreName: 'キッチン用品・食器・調理器具',
        reviewCount: 221,
        reviewAverage: 4.49,
      ),
      _searchItem(
        id: 'demo_search_011',
        name: 'ポータブル加湿器 USB静音',
        price: 2680,
        shopName: 'Life Gadget',
        shopCode: 'demo_shop_004',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-004/',
        genreId: '565421',
        genreName: '家電',
        reviewCount: 197,
        reviewAverage: 4.27,
      ),
      _searchItem(
        id: 'demo_search_012',
        name: '高見え クッションカバー 2枚',
        price: 2280,
        shopName: '北欧インテリア館',
        shopCode: 'demo_shop_005',
        shopUrl: 'https://www.rakuten.co.jp/demo-shop-005/',
        genreId: '205718',
        genreName: 'インテリア・寝具・収納',
        reviewCount: 164,
        reviewAverage: 4.35,
      ),
    ];
  }

  static TodayRecommendationBundle todayRecommendationBundle() {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final picks = <TodayRecommendationEntry>[
      TodayRecommendationEntry(item: _byId('demo_search_005')),
      TodayRecommendationEntry(item: _byId('demo_search_003')),
      TodayRecommendationEntry(item: _byId('demo_search_010')),
      TodayRecommendationEntry(item: _byId('demo_search_011')),
      TodayRecommendationEntry(item: _byId('demo_search_008')),
      TodayRecommendationEntry(item: _byId('demo_search_001')),
      TodayRecommendationEntry(item: _byId('demo_search_006')),
      TodayRecommendationEntry(item: _byId('demo_search_012')),
    ];
    return TodayRecommendationBundle(
      localDateKey: dateKey,
      generatedAt: now.subtract(const Duration(hours: 2)),
      entries: picks,
    );
  }

  static List<RakutenSearchItem> querySearchItems(
    RakutenProductSearchCondition condition,
  ) {
    final c = condition.normalized();
    final src = searchItems();
    return src.where((e) {
      if (c.shopCode != null && c.shopCode!.isNotEmpty) {
        if (e.shopCode.trim() != c.shopCode!.trim()) return false;
      }
      if (c.genreId != null && c.genreId!.isNotEmpty) {
        if (e.genreId.trim() != c.genreId!.trim()) return false;
      }
      final kw = c.keyword.trim();
      if (kw.isNotEmpty) {
        final joined =
            '${e.itemName} ${e.shopName} ${e.genreName}'.toLowerCase();
        if (!joined.contains(kw.toLowerCase())) return false;
      }
      if (c.minPrice != null && e.itemPrice < c.minPrice!) return false;
      if (c.maxPrice != null && e.itemPrice > c.maxPrice!) return false;
      if (c.minReviewCount != null && e.reviewCount < c.minReviewCount!) {
        return false;
      }
      if (c.minCommentCount != null && e.reviewCount < c.minCommentCount!) {
        return false;
      }
      if (c.minReviewAverage != null &&
          e.reviewAverage < c.minReviewAverage!) {
        return false;
      }
      if (c.excludeKeyword.trim().isNotEmpty &&
          e.itemName.toLowerCase().contains(c.excludeKeyword.toLowerCase())) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static RakutenSearchItem _byId(String id) {
    return searchItems().firstWhere((e) => e.productId == id);
  }

  static RakutenSearchItem _searchItem({
    required String id,
    required String name,
    required int price,
    required String shopName,
    required String shopCode,
    required String shopUrl,
    required String genreId,
    required String genreName,
    required int reviewCount,
    required double reviewAverage,
  }) {
    final url = 'https://item.rakuten.co.jp/demo/$id/';
    return RakutenSearchItem(
      productId: id,
      itemName: name,
      itemPrice: price,
      itemUrl: url,
      affiliateUrl: '$url?scid=demo',
      imageUrl: 'https://picsum.photos/seed/$id/400/400',
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
      genreName: genreName,
    );
  }
}
