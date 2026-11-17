import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/core/recent_channel_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('history is recent first, unique, and never stores raw tokenized urls',
      () async {
    final a = Uri.parse('https://example.org/a.m3u8?token=secret');
    final b = Uri.parse('https://example.org/b.m3u8');
    final history = RecentChannelStore.record(
        RecentChannelStore.record(RecentChannelStore.record([], a), b), a);
    expect(history, hasLength(2));
    expect(history.first, RecentChannelStore.identifier(a));
    expect(history.join(','), isNot(contains('secret')));
    final store = RecentChannelStore();
    await store.save(history);
    expect(await store.load(), history);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(RecentChannelStore.storageKey)!.join(),
        isNot(contains('token=')));
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('history stays capped at 40 and invalid persisted ids are removed', () {
    final records = List.generate(90, (i) => Uri.parse('https://cdn.test/$i'));
    var history = <String>[];
    for (final url in records) {
      history = RecentChannelStore.record(history, url);
    }
    expect(history, hasLength(40));
    expect(history.first, RecentChannelStore.identifier(records.last));
    expect(RecentChannelStore.normalize(['bad', ...history, history.first]),
        history);
  });
}
