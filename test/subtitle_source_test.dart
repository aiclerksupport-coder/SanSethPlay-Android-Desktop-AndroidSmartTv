import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/subtitle_source.dart';

void main() {
  test('accepts HTTPS and HTTP subtitle links', () {
    expect(parseExternalSubtitleUrl(' https://example.com/sub.vtt ')?.scheme,
        'https');
    expect(parseExternalSubtitleUrl('http://example.com/sub.srt'), isNotNull);
  });
  test('rejects local files, javascript, credentials and malformed URLs', () {
    for (final candidate in [
      'file:///sdcard/secret.srt',
      'javascript:alert(1)',
      'https://user:pass@example.com/sub.vtt',
      'not a URL',
      'ftp://example.com/sub.srt',
    ]) {
      expect(parseExternalSubtitleUrl(candidate), isNull, reason: candidate);
    }
  });
}
