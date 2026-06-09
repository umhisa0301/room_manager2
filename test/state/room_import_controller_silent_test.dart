import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/user_profile.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/room_import_controller.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomImportController.runReactionSync silent', () {
    late BulkOperationStateController bulk;
    late RoomImportController ctl;
    late UserProfileProvider profileProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = UserProfileRepository(prefs);
      await repo.save(
        const UserProfile(roomUrl: 'https://room.rakuten.co.jp/testuser'),
      );
      profileProvider = UserProfileProvider(repository: repo);
      bulk = BulkOperationStateController();
      bulk.setRoomImportRunning(true);
      ctl = RoomImportController(bulkOperationState: bulk);
    });

    Widget buildHarness({
      required Future<void> Function(BuildContext) onTap,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: bulk),
          ChangeNotifierProvider.value(value: ctl),
          ChangeNotifierProvider.value(value: profileProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => onTap(context),
                child: const Text('run'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('silent=true does not show SnackBar when blocked', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          onTap: (context) => ctl.runReactionSync(context, silent: true),
        ),
      );
      await tester.tap(find.text('run'));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('silent=false shows SnackBar when blocked', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          onTap: (context) => ctl.runReactionSync(context),
        ),
      );
      await tester.tap(find.text('run'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
