import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/hls_ts_recorder.dart';

void main() {
  final source = Uri.parse('https://example.org/live/channel.m3u8');

  test('accepts media playlist with ordered transport stream segments', () {
    const manifest = '#EXTM3U\n#EXT-X-TARGETDURATION:6\n'
        '#EXT-X-MEDIA-SEQUENCE:42\n#EXTINF:6.0,\n'
        'segment42.ts\n#EXTINF:6.0,\nsegment43.ts\n';
    final parsed = HlsTsManifest.parse(manifest, source);
    expect(parsed.segments.map((x) => x.sequence).toList(), [42, 43]);
    expect(parsed.segments.first.url.toString(),
        'https://example.org/live/segment42.ts');
    expect(parsed.endList, false);
  });

  test('rejects encrypted streams', () {
    const manifest = '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key"\n'
        '#EXTINF:6.0,\nsegment.ts\n';
    expect(() => HlsTsManifest.parse(manifest, source), throwsFormatException);
  });

  test('rejects variants, byte-range and fMP4', () {
    for (final tag in [
      '#EXT-X-STREAM-INF:BANDWIDTH=1200000',
      '#EXT-X-BYTERANGE:100@200',
      '#EXT-X-MAP:URI="init.mp4"',
    ]) {
      expect(
          () =>
              HlsTsManifest.parse('#EXTM3U\n$tag\n#EXTINF:4,\nseg.ts', source),
          throwsFormatException);
    }
  });

  test('rejects timeline discontinuities and malformed sequence', () {
    for (final tag in [
      '#EXT-X-DISCONTINUITY',
      '#EXT-X-GAP',
      '#EXT-X-MEDIA-SEQUENCE:not-a-number',
    ]) {
      expect(
          () =>
              HlsTsManifest.parse('#EXTM3U\n$tag\n#EXTINF:4,\nseg.ts', source),
          throwsFormatException);
    }
  });

  test('rejects external schemes and user-info credentials in segment', () {
    for (final segment in [
      'file:///etc/passwd',
      'https://user:pass@example.com/seg.ts'
    ]) {
      expect(() => HlsTsManifest.parse('#EXTM3U\n#EXTINF:4,\n$segment', source),
          throwsFormatException);
    }
  });

  test('recognizes finished video on demand transport stream playlist', () {
    final parsed = HlsTsManifest.parse(
        '#EXTM3U\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST', source);
    expect(parsed.endList, true);
  });
}
