import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'channel.dart';

/// Stores only the last selected channel and its owning playlist.
/// Source URLs can include provider tokens, so never log or store in plain prefs.
class LastWatched {
  const LastWatched(this.playlistId, this.channel);
  final String playlistId;
  final StreamChannel channel;
}

class LastWatchedStore {
  LastWatchedStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const key = 'sanseth_last_watched_v1';

  Future<void> save(String playlistId, StreamChannel channel) async {
    await _storage.write(
        key: key,
        value: jsonEncode({
          'playlistId': playlistId,
          'name': channel.name,
          'url': channel.url.toString(),
          'group': channel.group,
          'vod': channel.isVod,
        }));
  }

  Future<LastWatched?> load() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final id = data['playlistId'];
      final name = data['name'];
      final rawUrl = data['url'];
      final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
      if (id is! String ||
          id.isEmpty ||
          name is! String ||
          url == null ||
          !((url.isScheme('http') || url.isScheme('https')) &&
              url.host.isNotEmpty &&
              url.userInfo.isEmpty)) {
        return null;
      }
      return LastWatched(
          id,
          StreamChannel(
            name: name,
            url: url,
            group:
                data['group'] is String ? data['group'] as String : 'Live TV',
            isVod: data['vod'] == true,
          ));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: key);
}
