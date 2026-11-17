import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/direct_ts_recorder.dart';

void main() {
  test('only direct TS HTTP(S) streams can be recorded', () {
    expect(
        DirectTsRecorder.supports(
            Uri.parse('https://example.com/live.ts?token=abc')),
        isTrue);
    expect(DirectTsRecorder.supports(Uri.parse('http://example.com/live.ts')),
        isTrue);
    expect(
        DirectTsRecorder.supports(Uri.parse('https://example.com/live.m3u8')),
        isFalse);
    expect(
        DirectTsRecorder.supports(
            Uri.parse('https://example.com/manifest.mpd')),
        isFalse);
    expect(DirectTsRecorder.supports(Uri.parse('file:///private/video.ts')),
        isFalse);
    expect(
        DirectTsRecorder.supports(Uri.parse('https://u:p@example.com/live.ts')),
        isFalse);
  });
}
