import 'package:flutter/foundation.dart';

/// ユーザー向けショップ名の解決（shopCode を UI に出さない）。
abstract final class ShopDisplayResolve {
  static const String unknownShopLabel = 'ショップ未確認';

  static final RegExp _shopCodeLike = RegExp(
    r'^[a-z0-9][a-z0-9\-_]{1,48}$',
    caseSensitive: false,
  );

  /// shopCode らしい文字列か（例: girl-k, es-toys）。
  static bool looksLikeShopCode(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.length > 50) return false;
    if (t.contains(' ') || t.contains('　')) return false;
    if (_shopCodeLike.hasMatch(t) && !t.contains('ショップ') && !t.contains('店')) {
      return true;
    }
    return false;
  }

  static String resolveDisplayShopName({
    String? shopName,
    String? shopCode,
    String screen = 'unknown',
  }) {
    final name = shopName?.trim() ?? '';
    if (name.isNotEmpty &&
        name != 'ショップ名不明' &&
        name != 'ショップ未設定' &&
        !looksLikeShopCode(name)) {
      _audit(screen: screen, shopCode: shopCode, shopName: name, uiText: name);
      return name;
    }
    _audit(
      screen: screen,
      shopCode: shopCode,
      shopName: shopName,
      uiText: unknownShopLabel,
      fallback: 'shopUnknown',
    );
    return unknownShopLabel;
  }

  static void _audit({
    required String screen,
    String? shopCode,
    String? shopName,
    required String uiText,
    String fallback = 'resolvedShopName',
  }) {
    if (!kDebugMode) return;
    final sc = shopCode?.trim() ?? '';
    final sn = shopName?.trim() ?? '';
    final exposed = sc.isNotEmpty && uiText == sc;
    debugPrint(
      '[SHOP_CODE_UI_AUDIT] screen=$screen rawShopCode=${sc.isEmpty ? '-' : sc} '
      'rawShopName=${sn.isEmpty ? '-' : sn} uiText=$uiText '
      'shopCodeExposed=$exposed fallback=$fallback',
    );
  }
}
