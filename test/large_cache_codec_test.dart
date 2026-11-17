import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/channel.dart';
import 'package:sanseth_play/core/channel_cache.dart';

void main() {
  test('20,000 channels survive cache codec without truncation', () {
    final list = List.generate(
        20000,
        (index) => StreamChannel(
              name: 'Channel $index',
              url: Uri.parse(
                  'https://example.org/channel/$index.m3u8?key=private'),
              group: 'Group ${index % 100}',
              tvgId: 'id-$index',
            ));
    final snapshot = ChannelCache.encode(list);
    final restored = ChannelCache.decode(snapshot);
    expect(restored.length, 20000);
    expect(restored.last.tvgId, 'id-19999');
    expect(restored.first.url.queryParameters['key'], 'private');
  });

  test('unknown codec version is not trusted', () {
    expect(ChannelCache.decode('{"v":999,"items":[]}'), isEmpty);
  });
}
