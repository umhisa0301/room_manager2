import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/room_sync_card_copy.dart';
import 'package:room_manager2/widgets/room_sync_reaction_button.dart';

void main() {
  testWidgets('enabled shows manual reaction check label and is tappable', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSyncReactionButton(
            screen: 'home',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text(RoomSyncCardCopy.manualReactionCheckLabel), findsOneWidget);
    await tester.tap(find.text(RoomSyncCardCopy.manualReactionCheckLabel));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('disabled shows busy label and is not tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSyncReactionButton(
            screen: 'home',
            enabled: false,
            label: RoomSyncCardCopy.reactionCheckBusyLabel,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text(RoomSyncCardCopy.reactionCheckBusyLabel), findsOneWidget);
    await tester.tap(find.text(RoomSyncCardCopy.reactionCheckBusyLabel));
    await tester.pump();
    expect(tapped, isFalse);
  });
}
