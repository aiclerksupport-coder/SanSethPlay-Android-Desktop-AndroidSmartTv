import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/channel_categories.dart';
import 'package:sanseth_play/core/m3u_parser.dart';
import 'package:sanseth_play/core/saved_playlist.dart';

void main() {
  test('M3U group-title creates category views without copying playlists', () {
    final channels = M3uParser.parse('''#EXTM3U
#EXTINF:-1 group-title="News",News One
https://video.example/news1.m3u8
#EXTINF:-1 group-title="Sports",Sports One
https://video.example/sport1.m3u8
#EXTINF:-1 group-title="News",News Two
https://video.example/news2.m3u8
#EXTINF:-1,Missing Group
https://video.example/other.m3u8
''');
    expect(channels, hasLength(4));
    expect(ChannelCategories.counts(channels), {
      'News': 2,
      'Sports': 1,
      'Uncategorized': 1,
    });
    expect(ChannelCategories.labels(channels),
        ['All groups', 'News', 'Sports', 'Uncategorized']);
  });

  test('GitHub blob and raw links are the same source regardless of mode', () {
    final saved = [
      SavedPlaylist(
          id: 'p1',
          name: 'News',
          url: Uri.parse('https://github.com/owner/repo/blob/main/tv.m3u'),
          kind: PlaylistKind.remoteM3u)
    ];
    expect(
        containsPlaylistSource(
            saved,
            Uri.parse(
                'https://raw.githubusercontent.com/owner/repo/main/tv.m3u')),
        isTrue);
    expect(
        containsPlaylistSource(
            saved,
            Uri.parse(
                'https://raw.githubusercontent.com/owner/repo/main/tv.m3u#section')),
        isTrue);
    expect(
        containsPlaylistSource(
            saved, Uri.parse('https://other.example/tv.m3u')),
        isFalse);
  });

  test('identical direct stream cannot duplicate the source', () {
    final saved = [
      SavedPlaylist(
          id: 'stream',
          name: 'Live',
          url: Uri.parse('https://tv.example/live.m3u8'),
          kind: PlaylistKind.directStream)
    ];
    expect(
        containsPlaylistSource(
            saved, Uri.parse('https://tv.example/live.m3u8')),
        isTrue);
  });

  test('more than 100 independent sources round trip serialization', () {
    final sources = List.generate(
        175,
        (i) => SavedPlaylist(
            id: '$i',
            name: 'Playlist $i',
            url: Uri.parse('https://example.org/$i.m3u'),
            kind: PlaylistKind.remoteM3u));
    final restored = decodePlaylists(encodePlaylists(sources));
    expect(restored, hasLength(175));
    expect(restored.last.url.path, '/174.m3u');
  });
}
