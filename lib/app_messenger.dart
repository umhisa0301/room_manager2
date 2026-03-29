import 'package:flutter/material.dart';

/// アプリ全体で [SnackBar] 表示に使う [ScaffoldMessenger]（外部アプリから復帰後の通知など）。
final GlobalKey<ScaffoldMessengerState> appRootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
