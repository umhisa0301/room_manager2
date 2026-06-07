import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/config/demo_mode.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/widgets/add_candidate_entry_sheet.dart';

void main() {
  testWidgets('URLから追加入口は showUrlAddEntryPoint=false では非表示', (tester) async {
    if (showUrlAddEntryPoint) return;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => BulkOperationStateController(),
            child: AddCandidateEntrySheetBody(
              roomTourSearchBlocked: false,
              onTapRakutenProductSearch: () {},
              onTapGenreSearch: () {},
              onTapSavedShops: () {},
              onTapAddFromUrl: () {},
              onTapShopDiscovery: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('URLから追加'), findsNothing);
    expect(find.byKey(const Key('add_candidate_from_url')), findsNothing);
    expect(find.text('楽天で商品を探す'), findsOneWidget);
  });
}
