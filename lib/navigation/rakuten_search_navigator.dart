import 'package:flutter/material.dart';

import '../screens/rakuten_search_screen.dart';

Future<void> openRakutenSearchScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const RakutenSearchScreen()),
  );
}
