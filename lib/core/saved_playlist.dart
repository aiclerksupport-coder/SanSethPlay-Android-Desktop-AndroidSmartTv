import 'dart:convert';

/// Only references and small metadata are persisted. Never log [url].
enum PlaylistKind { remoteM3u, directStream }

class SavedPlaylist {
  const SavedPlaylist({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
  });

  final String id;
  final String name;
  final Uri url;
  final PlaylistKind kind;

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'url': url.toString(),
        'kind': kind.name,
      };

  static SavedPlaylist? fromJson(Object? data) {
    if (data is! Map) {
      return null;
    }
    final id = data['id'];
    final name = data['name'];
    final rawUrl = data['url'];
    final kind = data['kind'];
    if (id is! String ||
        name is! String ||
        rawUrl is! String ||
        kind is! String ||
        id.isEmpty ||
        name.isEmpty) {
      return null;
    }
    final url = Uri.tryParse(rawUrl);
    final parsedKind = PlaylistKind.values.where((e) => e.name == kind);
    if (url == null || !isHttpUrl(url) || parsedKind.isEmpty) {
      return null;
    }
    return SavedPlaylist(id: id, name: name, url: url, kind: parsedKind.first);
  }
}

bool isHttpUrl(Uri url) =>
    (url.isScheme('https') || url.isScheme('http')) &&
    url.host.isNotEmpty &&
    url.userInfo.isEmpty;

/// Public GitHub file-page links are not raw M3U files.
/// Preserve query strings on existing raw/Gist/custom URLs.
Uri normalizePlaylistUrl(Uri uri) {
  if (!isHttpUrl(uri)) {
    throw const FormatException('Valid HTTP/HTTPS URL daalein.');
  }
  if (uri.host.toLowerCase() == 'github.com' &&
      uri.pathSegments.length >= 5 &&
      uri.pathSegments[2] == 'blob') {
    final segments = uri.pathSegments;
    return Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      pathSegments: [
        segments[0],
        segments[1],
        segments[3],
        ...segments.skip(4)
      ],
    );
  }
  return uri;
}

String encodePlaylists(Iterable<SavedPlaylist> playlists) =>
    jsonEncode(playlists.map((e) => e.toJson()).toList());

List<SavedPlaylist> decodePlaylists(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw const FormatException('Saved playlist index is damaged.');
  }
  if (decoded is! List) {
    throw const FormatException('Invalid playlist index.');
  }
  return decoded
      .map(SavedPlaylist.fromJson)
      .whereType<SavedPlaylist>()
      .toList();
}

/// Identifies the same saved source across GitHub blob/raw links, URL fragments,
/// default ports, and source modes. Query strings are intentionally preserved:
/// signed playlists may use tokens and query parameters as their identity.
String playlistSourceKey(Uri source) {
  final normalized = normalizePlaylistUrl(source);
  final scheme = normalized.scheme.toLowerCase();
  final host = normalized.host.toLowerCase();
  final defaultPort = (scheme == 'https' && normalized.port == 443) ||
      (scheme == 'http' && normalized.port == 80);
  final base = normalized.replace(
    scheme: scheme,
    host: host,
    port: defaultPort ? 0 : normalized.port,
    fragment: '',
  );
  return base.toString();
}

/// Source kind does NOT participate: one stream URL can only appear once.
bool containsPlaylistSource(Iterable<SavedPlaylist> saved, Uri candidate) {
  final key = playlistSourceKey(candidate);
  return saved.any((item) => playlistSourceKey(item.url) == key);
}
