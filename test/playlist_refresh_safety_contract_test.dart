import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup refreshes saved sources after restoring the active playlist',
      () {
    final source = File('lib/app/home_screen.dart').readAsStringSync();
    final restore = source.substring(
      source.indexOf('Future<void> _restorePlaylists()'),
      source.indexOf('Future<void> _persistPlaylists('),
    );
    expect(restore, contains('await _openPlaylist('));
    expect(restore, contains('_refreshAllSavedPlaylists(startup: true)'));
    expect(restore.indexOf('await _openPlaylist('),
        lessThan(restore.indexOf('_refreshAllSavedPlaylists(startup: true)')));
  });

  test('manual refresh retains current playback and does not reopen player',
      () {
    final source = File('lib/app/home_screen.dart').readAsStringSync();
    final refresh = source.substring(
      source.indexOf('Future<void> _refreshActive()'),
      source.indexOf('bool _sameSavedSource('),
    );
    expect(refresh, contains('await _repository.fromUrl(playlist.url)'));
    expect(refresh, isNot(contains('_selected = null')));
    expect(refresh, isNot(contains('_openPlaylist(')));
    expect(refresh, isNot(contains('_player.dispose()')));
  });

  test('refresh all is sequential and avoids protected and changed sources',
      () {
    final source = File('lib/app/home_screen.dart').readAsStringSync();
    final refresh = source.substring(
      source.indexOf('Future<void> _refreshAllSavedPlaylists('),
      source.indexOf('Future<void> _browseSavedPlaylists('),
    );
    expect(refresh, contains('for (final playlist in snapshot)'));
    expect(refresh, contains('await _repository.fromUrl(playlist.url)'));
    expect(refresh, contains('_protected(playlist)'));
    expect(refresh, contains('_sameSavedSource(playlist)'));
    expect(refresh, contains('playlist.id == _activePlaylistId'));
    expect(source, contains('Refresh all M3U playlists'));
    expect(source, contains("label: const Text('Refresh all')"));
  });
}
