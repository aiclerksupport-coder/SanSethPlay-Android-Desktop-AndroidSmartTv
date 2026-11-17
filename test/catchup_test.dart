import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/catchup.dart';
import 'package:sanseth_play/core/m3u_parser.dart';
import 'package:sanseth_play/core/channel_cache.dart';

void main() {
  const playlist = '#EXTM3U\n'
      '#EXTINF:-1 catchup="default" catchup-days="7" '
      'catchup-source="https://archive.example.test/replay?start={utc}&length={duration}" '
      'group-title="News",Daily News\n'
      'https://live.example.test/main.m3u8\n';

  test('M3U catchup metadata and last-known-good cache roundtrip', () {
    final channel = M3uParser.parse(playlist).single;
    expect(channel.catchupDays, 7);
    expect(channel.catchupTemplate, contains('{utc}'));
    final recovered =
        ChannelCache.decode(ChannelCache.encode([channel])).single;
    expect(recovered.catchupTemplate, channel.catchupTemplate);
    expect(recovered.catchupDays, 7);
  });

  test('provider archive template resolves exact UTC seconds', () {
    final channel = M3uParser.parse(playlist).single;
    final now = DateTime.utc(2026, 11, 17, 18);
    final start = DateTime.utc(2026, 11, 17, 12);
    final end = start.add(const Duration(minutes: 30));
    final replay =
        CatchupUrl.archivedProgramme(channel, 'News', start, end, now: now);
    expect(replay, isNotNull);
    expect(replay!.url.queryParameters['start'],
        '${start.millisecondsSinceEpoch ~/ 1000}');
    expect(replay.url.queryParameters['length'], '1800');
    expect(replay.isVod, isTrue);
  });

  test('rejects future programmes and expired archive', () {
    final channel = M3uParser.parse(playlist).single;
    final now = DateTime.utc(2026, 11, 17, 18);
    expect(
        CatchupUrl.forProgramme(channel, now, now.add(const Duration(hours: 1)),
            now: now),
        isNull);
    expect(
        CatchupUrl.forProgramme(channel, now.subtract(const Duration(days: 8)),
            now.subtract(const Duration(days: 8, hours: -1)),
            now: now),
        isNull);
  });

  test('UTC calendar tokens and utcend are expanded deterministically', () {
    const source = '#EXTM3U\n'
        '#EXTINF:-1 catchup="default" catchup-days="2" '
        'catchup-source="https://archive.example.test/{Y}/{m}/{d}/{H}/{M}/{S}?end={utcend}",News\n'
        'https://live.example.test/a.m3u8\n';
    final channel = M3uParser.parse(source).single;
    final start = DateTime.utc(2026, 11, 17, 12, 9, 5);
    final stop = start.add(const Duration(minutes: 30));
    final url = CatchupUrl.forProgramme(channel, start, stop,
        now: DateTime.utc(2026, 11, 17, 18));
    expect(url!.path, '/2026/11/17/12/09/05');
    expect(
        url.queryParameters['end'], '${stop.millisecondsSinceEpoch ~/ 1000}');
  });

  test('source without catchup metadata never fabricates replay', () {
    final plain = M3uParser.parse(
            '#EXTM3U\n#EXTINF:-1,Live\nhttps://cdn.example.test/a.m3u8\n')
        .single;
    expect(
        CatchupUrl.forProgramme(plain, DateTime.utc(2026, 11, 17, 12),
            DateTime.utc(2026, 11, 17, 13),
            now: DateTime.utc(2026, 11, 17, 18)),
        isNull);
  });
}
