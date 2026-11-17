import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/saved_playlist.dart';

void main() {
  test('GitHub blob URLs convert to raw media source', () {
    final parsed = normalizePlaylistUrl(Uri.parse(
        'https://github.com/iptv-org/iptv/blob/master/streams/in.m3u'));
    expect(parsed.host, 'raw.githubusercontent.com');
    expect(parsed.path, '/iptv-org/iptv/master/streams/in.m3u');
  });

  test('source serialization preserves name URL type and supports restart', () {
    final original = [
      SavedPlaylist(
        id: '123',
        name: 'My favorite GitHub IPTV',
        url: Uri.parse(
            'https://raw.githubusercontent.com/example/streams/main/tv.m3u'),
        kind: PlaylistKind.remoteM3u,
      ),
      SavedPlaylist(
        id: '124',
        name: 'Live Channel',
        url: Uri.parse('https://example.org/live.m3u8?token=top-secret'),
        kind: PlaylistKind.directStream,
      ),
    ];
    final restored = decodePlaylists(encodePlaylists(original));
    expect(restored.map((e) => e.id), ['123', '124']);
    expect(restored[1].url.queryParameters['token'], 'top-secret');
    expect(restored[1].kind, PlaylistKind.directStream);
  });

  test('unsafe schemes and URL userinfo rejected', () {
    expect(() => normalizePlaylistUrl(Uri.parse('file:///etc/passwd')),
        throwsFormatException);
    expect(
        () => normalizePlaylistUrl(
            Uri.parse('https://user:secret@example.com/a.m3u')),
        throwsFormatException);
    expect(
        decodePlaylists(
            '[{"id":"bad","name":"x","url":"file:///x","kind":"remoteM3u"}]'),
        isEmpty);
  });
}
