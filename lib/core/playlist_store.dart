import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'saved_playlist.dart';

abstract class PlaylistStore {
  Future<List<SavedPlaylist>> load();
  Future<void> save(List<SavedPlaylist> sources);
}

/// Platform-protected storage for source URLs, which can contain auth tokens.
/// Do NOT use SharedPreferences for URLs or raw playlist content.
class SecurePlaylistStore implements PlaylistStore {
  SecurePlaylistStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'sanseth_play_sources_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<SavedPlaylist>> load() async =>
      decodePlaylists(await _storage.read(key: _key));

  @override
  Future<void> save(List<SavedPlaylist> sources) async {
    // No artificial source-count limit. Physical secure-storage quotas still apply.
    await _storage.write(key: _key, value: encodePlaylists(sources));
  }
}
