import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/channel.dart';
import 'package:sanseth_play/core/channel_cache.dart';

void main() {
  test('empty and malformed caches never break startup', () {
    expect(ChannelCache.decode(null), isEmpty);
    expect(ChannelCache.decode('garbage'), isEmpty);
  });
  test('cache roundtrip keeps channel metadata and safe URLs', () {
    final original = [
      StreamChannel(
          name: 'Public Channel',
          url: Uri.parse('https://example.org/live.m3u8?token=private'),
          tvgId: 'public.id',
          group: 'News')
    ];
    final restored = ChannelCache.decode(ChannelCache.encode(original));
    expect(restored.single.name, 'Public Channel');
    expect(restored.single.tvgId, 'public.id');
    expect(restored.single.url.queryParameters['token'], 'private');
  });
  test('invalid channel link is rejected on load', () {
    const payload = '{"v":1,"items":[{"n":"Invalid","u":"file:///secret"}]}';
    expect(ChannelCache.decode(payload), isEmpty);
  });
}
