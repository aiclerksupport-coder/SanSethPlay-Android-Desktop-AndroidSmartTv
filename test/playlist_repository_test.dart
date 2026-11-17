import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanseth_play/core/playlist_repository.dart';

void main() {
  test('redirected GitHub M3U loads and parses as channels', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'example.org') {
        return http.Response('', 302, headers: {
          'location': 'https://raw.githubusercontent.com/demo/repo/main/tv.m3u'
        });
      }
      return http.Response('''#EXTM3U
#EXTINF:-1 group-title="News",Channel One
https://cdn.example.org/live.m3u8
''', 200);
    });
    final repo = PlaylistRepository(client: client);
    final results =
        await repo.fromUrl(Uri.parse('https://example.org/list.m3u'));
    expect(results, hasLength(1));
    expect(results.single.name, 'Channel One');
    repo.dispose();
  });

  test('M3U8 URLs do not parse HLS segments as separate channels', () async {
    final repo = PlaylistRepository(
        client: MockClient((_) async => throw StateError(
            'Direct stream must not be downloaded as a playlist')));
    final results =
        await repo.fromUrl(Uri.parse('https://example.org/live/index.m3u8'));
    expect(results, hasLength(1));
    expect(results.single.url.path, '/live/index.m3u8');
    repo.dispose();
  });

  test('reject redirect downgrade from https to http', () async {
    final repo = PlaylistRepository(
        client: MockClient((request) async => http.Response('', 302,
            headers: {'location': 'http://bad.example/test.m3u'})));
    await expectLater(
      repo.fromUrl(Uri.parse('https://example.org/channels.m3u')),
      throwsFormatException,
    );
    repo.dispose();
  });
}
