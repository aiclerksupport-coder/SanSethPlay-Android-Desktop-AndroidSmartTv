import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/m3u_parser.dart';

void main() {
  test('parses groups, id, logo and channel', () {
    const source = """#EXTM3U
#EXTINF:-1 tvg-id="news" tvg-logo="https://a.test/icon.png" group-title="News, World",News HD
https://cdn.example.com/live/index.m3u8
""";
    final channels = M3uParser.parse(source);
    expect(channels, hasLength(1));
    expect(channels.first.name, 'News HD');
    expect(channels.first.group, 'News, World');
    expect(channels.first.tvgId, 'news');
    expect(channels.first.url.scheme, 'https');
  });

  test('rejects unsafe local schemes and resets metadata', () {
    const source = """#EXTM3U
#EXTINF:-1 group-title="A",One
file:///etc/passwd
#EXTINF:-1,Two
https://cdn.example.com/two.m3u8
""";
    final channels = M3uParser.parse(source);
    expect(channels, hasLength(1));
    expect(channels.single.name, 'Two');
    expect(channels.single.group, 'Uncategorized');
  });
  test('handles BOM, CR-only legacy M3U and tvg-name fallback', () {
    const source = '\uFEFF#EXTM3U\r'
        '#EXTINF:-1 tvg-name="News HD" group-title="Live",\r'
        '#EXTGRP:World News\r'
        'https://cdn.example.org/live.m3u8\r';
    final channels = M3uParser.parse(source);
    expect(channels, hasLength(1));
    expect(channels.first.name, 'News HD');
    expect(channels.first.group, 'World News');
  });
}
