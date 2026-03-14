import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // providers が空の MultiProvider は Nested のアサートで落ちるため、
    // プロバイダーを追加するまでは MaterialApp のみ返す。
    return MaterialApp(
      title: '楽天ROOM運用補助',
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}
