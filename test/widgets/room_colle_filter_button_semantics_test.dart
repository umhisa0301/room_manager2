import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// `_RoomColleFilterButton` と同じ Semantics 契約を検証する軽量ハーネス。
class _FilterButtonSemanticsHarness extends StatelessWidget {
  const _FilterButtonSemanticsHarness({
    required this.active,
    required this.onPressed,
    this.onClear,
  });

  final bool active;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final filterLabel = active ? '商品の絞り込み条件を変更する' : '商品を絞り込む';
    final filterKey = Key(
      active
          ? 'post_management_filter_button_active'
          : 'post_management_filter_button',
    );
    return Row(
      children: [
        Semantics(
          key: filterKey,
          button: true,
          enabled: true,
          label: filterLabel,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            child: const Padding(padding: EdgeInsets.all(8), child: Text('絞込')),
          ),
        ),
        if (active && onClear != null)
          Semantics(
            key: const Key('post_management_filter_clear_button'),
            button: true,
            enabled: true,
            label: '絞り込みを解除する',
            excludeSemantics: true,
            child: InkWell(
              onTap: onClear,
              child: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
  }
}

void main() {
  group('投稿管理フィルタ Semantics', () {
    test('ソースは Key に機械ID・label に日本語を分離している', () {
      final source = File(
        'lib/screens/products_placeholder_screen.dart',
      ).readAsStringSync();
      expect(source, contains("'post_management_filter_button'"));
      expect(source, contains("'post_management_filter_button_active'"));
      expect(source, contains("'post_management_filter_clear_button'"));
      expect(source, contains('label: filterSemanticsLabel'));
      expect(source, contains("'商品を絞り込む'"));
      expect(source, contains("'商品の絞り込み条件を変更する'"));
      expect(source, contains("'絞り込みを解除する'"));
      expect(source, isNot(contains("label: 'post_management_filter_button'")));
      expect(
        source,
        isNot(contains("label: 'post_management_filter_button_active'")),
      );
      expect(
        source,
        isNot(contains("label: 'post_management_filter_clear_button'")),
      );
    });

    testWidgets('フィルタ開く / 条件変更 / クリアの日本語 label と Key', (tester) async {
      final handle = tester.ensureSemantics();
      var openTaps = 0;
      var clearTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _FilterButtonSemanticsHarness(
              active: false,
              onPressed: () => openTaps++,
            ),
          ),
        ),
      );
      await tester.pump();

      final inactive = tester.getSemantics(
        find.byKey(const Key('post_management_filter_button')),
      );
      expect(inactive.label, '商品を絞り込む');
      expect(inactive.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(inactive.hasFlag(SemanticsFlag.isEnabled), isTrue);
      expect(
        find.bySemanticsLabel('post_management_filter_button'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('商品を絞り込む'), findsOneWidget);

      await tester.tap(find.byKey(const Key('post_management_filter_button')));
      expect(openTaps, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _FilterButtonSemanticsHarness(
              active: true,
              onPressed: () => openTaps++,
              onClear: () => clearTaps++,
            ),
          ),
        ),
      );
      await tester.pump();

      final active = tester.getSemantics(
        find.byKey(const Key('post_management_filter_button_active')),
      );
      expect(active.label, '商品の絞り込み条件を変更する');
      expect(active.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(
        find.bySemanticsLabel('post_management_filter_button_active'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('商品の絞り込み条件を変更する'), findsOneWidget);

      final clear = tester.getSemantics(
        find.byKey(const Key('post_management_filter_clear_button')),
      );
      expect(clear.label, '絞り込みを解除する');
      expect(clear.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(
        find.bySemanticsLabel('post_management_filter_clear_button'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('絞り込みを解除する'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('post_management_filter_clear_button')),
      );
      expect(clearTaps, 1);

      handle.dispose();
    });
  });
}
