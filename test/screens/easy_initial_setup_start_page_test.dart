import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/easy_initial_setup_screen.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap({
  required SharedPreferences prefs,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => EasyInitialSetupRepository(prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => UserProfileProvider(
          repository: UserProfileRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => SavedShopProvider(repository: SavedShopRepository(prefs)),
      ),
      Provider(
        create: (_) => RakutenSearchRepository(apiService: RakutenApiService()),
      ),
      Provider(create: (_) => ProductCatalogRepository(prefs)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EasyInitialSetupScreen start page', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'embeddedInEntryHost false with initialPageIndex 0 starts on profile step',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            prefs: prefs,
            child: const EasyInitialSetupScreen(
              embeddedInEntryHost: false,
              initialPageIndex: 0,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('プロフィール'), findsOneWidget);
        expect(find.text('ROOM投稿取り込み'), findsNothing);
      },
    );

    testWidgets(
      'does not jump to room url step when room url is unset and initialPageIndex is 0',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            prefs: prefs,
            child: const EasyInitialSetupScreen(
              embeddedInEntryHost: false,
              initialPageIndex: 0,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('ニックネーム（任意）'), findsOneWidget);
        expect(find.text('ROOMプロフィールURL（任意）'), findsNothing);
      },
    );
  });
}
