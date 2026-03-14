import '../models/product_item.dart';

/// 商品管理画面用の仮データ。
/// 後で API/DB に差し替え可能なようにリストで返す。
List<ProductItem> getDummyProducts() {
  return [
    const ProductItem(
      id: '1',
      imageUrl: null,
      name: 'ベビー布団 洗える コンパクト',
      shopOrUrl: '楽天市場 ○○ベビー',
      tags: ['育児', '寝具'],
      status: '候補',
      hasComment: false,
    ),
    const ProductItem(
      id: '2',
      imageUrl: null,
      name: '無印風 フラップ付き収納ボックス',
      shopOrUrl: '楽天ルーム インテリア',
      tags: ['インテリア', '収納'],
      status: 'コレ済',
      hasComment: true,
    ),
    const ProductItem(
      id: '3',
      imageUrl: null,
      name: 'シリコンスチーマー 3点セット',
      shopOrUrl: '楽天市場 キッチン雑貨',
      tags: ['キッチン'],
      status: '候補',
      hasComment: false,
    ),
    const ProductItem(
      id: '4',
      imageUrl: null,
      name: 'ワイヤレスイヤホン ノイキャン',
      shopOrUrl: '楽天市場 家電ストア',
      tags: ['ガジェット', 'オーディオ'],
      status: 'アーカイブ',
      hasComment: false,
    ),
    const ProductItem(
      id: '5',
      imageUrl: null,
      name: '子ども用 学習デスク 幅80cm',
      shopOrUrl: '楽天市場 家具の森',
      tags: ['育児', 'インテリア'],
      status: '候補',
      hasComment: true,
    ),
    const ProductItem(
      id: '6',
      imageUrl: null,
      name: 'スマートウォッチ 歩数計 防水',
      shopOrUrl: '楽天市場 スポーツ用品',
      tags: ['ガジェット'],
      status: 'コレ済',
      hasComment: false,
    ),
  ];
}
