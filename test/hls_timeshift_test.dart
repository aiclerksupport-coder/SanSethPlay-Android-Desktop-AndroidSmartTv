import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/hls_timeshift.dart';

void main() {
  test('timeshift accepts signed HLS sources but excludes other formats', () {
    expect(HlsTimeshift.supports(Uri.parse('https://example.org/live.m3u8')),
        true);
    expect(
        HlsTimeshift.supports(
            Uri.parse('https://example.org/live.m3u8?token=abc')),
        true);
    expect(HlsTimeshift.supports(Uri.parse('https://example.org/clip.mp4')),
        false);
  });

  test('generated HLS window uses monotonic sequence and exact durations', () {
    final playlist = HlsTimeshift.renderManifest([
      (
        sequence: 32,
        duration: const Duration(milliseconds: 3200),
        file: '32.ts'
      ),
      (sequence: 33, duration: const Duration(seconds: 4), file: '33.ts'),
    ]);
    expect(playlist, contains('#EXT-X-MEDIA-SEQUENCE:32'));
    expect(playlist, contains('#EXT-X-TARGETDURATION:4'));
    expect(playlist, contains('#EXTINF:3.200,'));
    expect(playlist, contains('33.ts'));
    expect(playlist, isNot(contains('#EXT-X-ENDLIST')));
  });

  test('empty manifest cannot be served as working media', () {
    expect(() => HlsTimeshift.renderManifest([]), throwsArgumentError);
  });
}
