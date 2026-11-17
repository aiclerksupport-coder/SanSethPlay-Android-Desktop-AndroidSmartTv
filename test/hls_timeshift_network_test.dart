import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/hls_timeshift.dart';

void main() {
  // Pure dart:io network tests must not initialize the widget binding.
  // Flutter widget tests replace HttpClient responses with HTTP 400.

  test('loopback DVR serves bounded HLS and rejects unknown paths', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final source = Uri.parse('http://127.0.0.1:${origin.port}/channel.m3u8');
    origin.listen((req) async {
      if (req.uri.path.endsWith('.m3u8')) {
        req.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl');
        req.response.write('#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:9\n'
            '#EXT-X-TARGETDURATION:4\n#EXTINF:4,\n9.ts\n');
      } else if (req.uri.path.endsWith('9.ts')) {
        req.response.add([0x47, ...List<int>.filled(187, 0)]);
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });
    final buffer = HlsTimeshift(pollEvery: const Duration(seconds: 30));
    final client = HttpClient();
    try {
      final local = await buffer.start(source);
      final response = await (await client.getUrl(local)).close();
      final data = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200);
      expect(data, contains('#EXT-X-MEDIA-SEQUENCE:9'));
      expect(data, contains('9.ts'));
      expect(buffer.bufferedDuration, const Duration(seconds: 4));
      final unknown = local.replace(path: '/invalid/live.m3u8');
      expect((await (await client.getUrl(unknown)).close()).statusCode, 404);
    } finally {
      await buffer.stop();
      client.close(force: true);
      await origin.close(force: true);
    }
  });

  test(
      'DVR rejects broken later MPEG-TS sync packets without exposing a playlist',
      () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin.listen((request) async {
      if (request.uri.path.endsWith('.m3u8')) {
        request.response.write('#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:1\n'
            '#EXT-X-TARGETDURATION:4\n#EXTINF:4,\n1.ts\n');
      } else {
        final packet = <int>[0x47, ...List<int>.filled(187, 0)];
        request.response.add([...packet, ...List<int>.filled(188, 0)]);
      }
      await request.response.close();
    });
    final timeshift = HlsTimeshift();
    try {
      await expectLater(
        timeshift.start(Uri.parse('http://127.0.0.1:${origin.port}/live.m3u8')),
        throwsFormatException,
      );
      expect(timeshift.active, isFalse);
    } finally {
      await timeshift.stop();
      await origin.close(force: true);
    }
  });
}
