import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/rakuten_genre_master_service.dart';

void main() {
  test('genreId 100026 は簡易マスタでもパソコン・周辺機器として解決する', () {
    final name = RakutenGenreMasterService.instance.getGenreNameById('100026');
    expect(name, 'パソコン・周辺機器');
    expect(name, isNot('DVD・ブルーレイ・ソフト'));
  });
}
