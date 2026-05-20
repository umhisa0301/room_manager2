import 'package:flutter/material.dart';

import '../screens/rakuten_search_screen.dart';

export '../screens/rakuten_search_screen.dart' show RakutenSearchInitialMode;

Future<void> openRakutenSearchScreen(
  BuildContext context, {
  RakutenSearchInitialMode initialMode = RakutenSearchInitialMode.product,
  bool savedShopKeywordEntry = false,
  String? initialSavedShopCode,
  String? initialScopedShopCode,
  String? initialGenreId,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => RakutenSearchScreen(
        initialMode: initialMode,
        savedShopKeywordEntry: savedShopKeywordEntry,
        initialSavedShopCode: initialSavedShopCode,
        initialScopedShopCode: initialScopedShopCode,
        initialGenreId: initialGenreId,
      ),
    ),
  );
}
