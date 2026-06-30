/// 楽天商品タイトルから画面表示・AI生成用の短い商品名を導出する。
String deriveProductDisplayTitle(String rawTitle) {
  final trimmed = rawTitle.trim();
  if (trimmed.isEmpty) return 'この商品';

  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length <= 4) return trimmed;
  return '${parts.take(4).join(' ')}…';
}
