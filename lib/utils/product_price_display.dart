/// 商品価格の表示用フォーマット（DB 保存値は変更しない）。
abstract final class ProductPriceDisplay {
  ProductPriceDisplay._();

  static const String unknownPriceLabel = '￥ー';

  /// [price] > 0 のとき `￥1,980` 形式。0 / 負数 / null は [unknownPriceLabel]。
  static String formatYen(int? price, {String unknown = unknownPriceLabel}) {
    if (price == null || price <= 0) return unknown;
    final raw = price.toString();
    final buffer = StringBuffer('￥');
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }
}
