import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/channel_health.dart';

void main() {
  test('never hide unknown streams or a confirmed playing stream', () {
    var time = DateTime.utc(2026, 11, 18);
    final store = ChannelHealthStore(now: () => time);
    final url = Uri.parse('https://example.com/live.m3u8?token=private');
    expect(store.status(url), ChannelHealth.unknown);
    store.probeResult(url, reachable: false, definitiveMissing: true);
    expect(store.status(url), ChannelHealth.unknown);
    store.probeResult(url, reachable: false, definitiveMissing: true);
    expect(store.status(url), ChannelHealth.unavailable);
    store.playing(url);
    expect(store.status(url), ChannelHealth.playing);
    store.probeResult(url, reachable: false, definitiveMissing: true);
    expect(store.status(url), ChannelHealth.playing);
    store.playbackFailed(url);
    expect(store.status(url), ChannelHealth.playing);
    time = time.add(const Duration(hours: 3));
    expect(store.status(url), ChannelHealth.unknown);
    store.dispose();
  });

  test('unavailable cache automatically expires and never permanently hides',
      () {
    var time = DateTime.utc(2026, 11, 18);
    final store = ChannelHealthStore(now: () => time);
    final url = Uri.parse('https://example.com/dead.m3u8');
    store.probeResult(url, reachable: false, definitiveMissing: true);
    store.probeResult(url, reachable: false, definitiveMissing: true);
    expect(store.status(url), ChannelHealth.unavailable);
    time = time.add(const Duration(minutes: 6));
    expect(store.status(url), ChannelHealth.unknown);
    store.dispose();
  });

  test('network/auth uncertainty never becomes a dead channel', () {
    final store = ChannelHealthStore();
    final url = Uri.parse('https://example.com/geo-blocked.m3u8');
    for (var i = 0; i < 9; i++) {
      store.probeResult(url, reachable: false, definitiveMissing: false);
    }
    expect(store.status(url), ChannelHealth.unknown);
    store.dispose();
  });
}
