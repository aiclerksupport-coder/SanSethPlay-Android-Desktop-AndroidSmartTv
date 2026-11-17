import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/core/favorite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favorites persist without plain playlist URLs or access tokens',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FavoriteStore();
    final url = Uri.parse('https://media.example/live?id=123&token=SECRET');
    final id = FavoriteStore.identifier(url);
    expect(id, hasLength(64));
    expect(id, isNot(contains('SECRET')));
    await store.save({id});
    expect(await store.load(), {id});
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('favorite_stream_hashes_v1'), [id]);
  });
}
