import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/data/interest_category_definitions.dart';

void main() {
  group('InterestCategoryDefinitions', () {
    test('育児・子育てカテゴリが選択肢に含まれる', () {
      final ids = InterestCategoryDefinitions.all.map((e) => e.id).toList();
      expect(ids, contains('parenting'));
      expect(
        InterestCategoryDefinitions.displayNameFor('parenting'),
        '育児・子育て',
      );
    });

    test('旧 baby_kids ID は表示名を解決できる', () {
      expect(
        InterestCategoryDefinitions.displayNameFor('baby_kids'),
        '育児・子育て',
      );
    });
  });
}
