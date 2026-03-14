import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 今後、ChangeNotifier 等をここに追加
      ],
      child: MaterialApp(
        title: '楽天ROOM運用補助',
        theme: AppTheme.lightTheme,
        home: const AppShell(),
      ),
    );
  }
}
