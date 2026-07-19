import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// AppShell `_NavItem` と同じ Semantics 契約を検証する軽量ハーネス。
class _NavSemanticsHarness extends StatelessWidget {
  const _NavSemanticsHarness({
    required this.semanticsKey,
    required this.label,
    required this.semanticsLabel,
    required this.isTab,
    required this.isSelected,
    required this.onTap,
    this.tooltip,
  });

  final Key semanticsKey;
  final String label;
  final String semanticsLabel;
  final bool isTab;
  final bool isSelected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      key: semanticsKey,
      button: true,
      selected: isTab ? isSelected : null,
      enabled: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(child: Text(label)),
        ),
      ),
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: child,
      );
    }
    return child;
  }
}

void main() {
  group('AppShell nav Semantics contract', () {
    test('ソースに人間向け Semantics と探すの通常ボタン扱いがある', () {
      final source = File('lib/app_shell.dart').readAsStringSync();
      expect(source, contains("semanticsLabel: 'ホーム'"));
      expect(source, contains("semanticsLabel: '候補を追加'"));
      expect(source, contains("semanticsLabel: '投稿'"));
      expect(source, contains("semanticsLabel: '分析'"));
      expect(source, contains("semanticsLabel: 'マイページ'"));
      expect(source, contains('isTab: false'));
      expect(source, contains('excludeFromSemantics: true'));
      expect(source, contains('selected: isTab ? isSelected : null'));
    });

    testWidgets('タブは selected、探すは selected なしの通常ボタン', (tester) async {
      final handle = tester.ensureSemantics();
      var selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Row(
                  children: [
                    Expanded(
                      child: _NavSemanticsHarness(
                        semanticsKey: const Key('app_shell_nav_home'),
                        label: 'ホーム',
                        semanticsLabel: 'ホーム',
                        isTab: true,
                        isSelected: selectedIndex == 0,
                        onTap: () => setState(() => selectedIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _NavSemanticsHarness(
                        semanticsKey: const Key('app_shell_nav_search'),
                        label: '探す',
                        semanticsLabel: '候補を追加',
                        tooltip: '候補を追加',
                        isTab: false,
                        isSelected: false,
                        onTap: () {},
                      ),
                    ),
                    Expanded(
                      child: _NavSemanticsHarness(
                        semanticsKey: const Key('app_shell_nav_managed'),
                        label: '投稿',
                        semanticsLabel: '投稿',
                        isTab: true,
                        isSelected: selectedIndex == 1,
                        onTap: () => setState(() => selectedIndex = 1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final home = tester.getSemantics(
        find.byKey(const Key('app_shell_nav_home')),
      );
      expect(home.label, 'ホーム');
      expect(home.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(home.hasFlag(SemanticsFlag.isSelected), isTrue);

      final search = tester.getSemantics(
        find.byKey(const Key('app_shell_nav_search')),
      );
      expect(search.label, '候補を追加');
      expect(search.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(search.hasFlag(SemanticsFlag.hasSelectedState), isFalse);

      await tester.tap(find.byKey(const Key('app_shell_nav_managed')));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.byKey(const Key('app_shell_nav_home')))
            .hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('app_shell_nav_managed')))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('app_shell_nav_search')))
            .hasFlag(SemanticsFlag.hasSelectedState),
        isFalse,
      );

      handle.dispose();
    });
  });
}
