import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_genre_master_entry.dart';
import 'package:room_manager2/services/genre_master_service.dart';
import 'package:room_manager2/services/rakuten_genre_master_service.dart';
import 'package:room_manager2/utils/genre_display_order.dart';
import 'package:room_manager2/utils/genre_tree_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GenreDisplayOrder', () {
    test('推奨順に含まれる genreId は指定順で並ぶ', () {
      final ids = [
        '100000',
        '100227',
        '100371',
        '551177',
        '100533',
      ];
      GenreDisplayOrder.sortGenreIds(ids);
      expect(ids, ['100371', '551177', '100533', '100227', '100000']);
    });

    test('推奨順に含まれない genreId は末尾で名称昇順', () {
      final ids = ['999999', '888888'];
      GenreDisplayOrder.sortGenreIds(
        ids,
        nameForId: (id) => id == '999999' ? 'ZZZ' : 'AAA',
      );
      expect(ids, ['888888', '999999']);
    });

    test('RakutenGenreMasterEntry 一覧を表示順でソート', () {
      final list = [
        const RakutenGenreMasterEntry(genreId: '100000', genreName: '百貨店'),
        const RakutenGenreMasterEntry(genreId: '100371', genreName: 'レディース'),
        const RakutenGenreMasterEntry(genreId: '100227', genreName: '食品'),
      ];
      GenreDisplayOrder.sortRakutenGenreMasterEntries(list);
      expect(list.map((e) => e.genreId).toList(), ['100371', '100227', '100000']);
    });

    test('ソートは ID 集合を変えない', () {
      const selected = ['100026', '100227', '100316'];
      final ids = List<String>.from(selected);
      GenreDisplayOrder.sortGenreIds(ids);
      expect(ids.toSet(), selected.toSet());
      expect(ids.length, selected.length);
    });
  });

  group('GenreDisplayOrder integration', () {
    setUpAll(() async {
      await GenreMasterService.instance.load();
    });

    test('rootNodes の先頭はレディースファッション', () {
      if (!GenreMasterService.instance.isLoaded) return;
      final roots = GenreTreeBuilder.rootNodes();
      expect(roots, isNotEmpty);
      expect(roots.first.genreId, '100371');
      expect(roots.first.genreName, 'レディースファッション');
    });

    test('getAllGenres も同じ先頭順', () {
      if (!GenreMasterService.instance.isLoaded) return;
      final entries = RakutenGenreMasterService.instance.getAllGenres();
      expect(entries, isNotEmpty);
      expect(entries.first.genreId, '100371');
      expect(entries.first.genreName, 'レディースファッション');
    });

    test('百貨店・総合通販・ギフトは推奨順の最後付近', () {
      if (!GenreMasterService.instance.isLoaded) return;
      final roots = GenreTreeBuilder.rootNodes();
      final deptStore = roots.indexWhere((n) => n.genreId == '100000');
      final ladies = roots.indexWhere((n) => n.genreId == '100371');
      expect(deptStore, greaterThan(ladies));
      expect(roots[deptStore].genreName, '百貨店・総合通販・ギフト');
    });
  });
}
