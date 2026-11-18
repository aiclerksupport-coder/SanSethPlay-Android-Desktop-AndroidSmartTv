import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'channel.dart';

/// An authorized provider account. Never print this object or URLs generated
/// from it: Xtream paths and query parameters contain credentials.
class XtreamAccount {
  XtreamAccount(
      {required this.server, required this.username, required this.password}) {
    if (!['http', 'https'].contains(server.scheme) ||
        server.host.isEmpty ||
        server.userInfo.isNotEmpty ||
        server.hasQuery ||
        server.hasFragment ||
        server.path.isNotEmpty && server.path != '/' ||
        username.trim().isEmpty ||
        password.isEmpty) {
      throw const FormatException('Invalid provider connection details');
    }
  }

  final Uri server;
  final String username;
  final String password;

  Uri action(String action, [Map<String, String> extra = const {}]) =>
      server.replace(
        path: '/player_api.php',
        queryParameters: {
          'username': username,
          'password': password,
          'action': action,
          ...extra
        },
      );

  Uri mediaUrl(
      {required String type, required String id, String extension = 'ts'}) {
    if (!RegExp(r'^\d{1,15}$').hasMatch(id) ||
        !RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension) ||
        !['live', 'movie', 'series'].contains(type)) {
      throw const FormatException('Invalid media descriptor');
    }
    return server.replace(
      pathSegments: [type, username, password, '$id.$extension'],
      queryParameters: null,
    );
  }
}

enum XtreamMediaType { live, movie, series }

class XtreamItem {
  const XtreamItem(
      {required this.id,
      required this.name,
      required this.categoryId,
      required this.type,
      this.extension = 'ts',
      this.poster});
  final String id;
  final String name;
  final String categoryId;
  final XtreamMediaType type;
  final String extension;
  final Uri? poster;
}

class XtreamEpisode {
  const XtreamEpisode(
      {required this.id,
      required this.title,
      required this.season,
      required this.extension});
  final String id;
  final String title;
  final int season;
  final String extension;
}

class XtreamClient {
  XtreamClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const maxBytes = 64 * 1024 * 1024;
  // Provider catalogs are not artificially truncated by item count.
  // A bounded response size still guards against untrusted huge payloads.

  Future<Object?> _fetch(Uri url) async {
    final response = await _client
        .send(http.Request('GET', url)..followRedirects = false)
        .timeout(const Duration(seconds: 15));
    if (response.isRedirect || response.statusCode != 200) {
      await response.stream.drain<void>();
      throw const FormatException('Provider request failed');
    }
    final bytes = <int>[];
    await for (final part
        in response.stream.timeout(const Duration(seconds: 15))) {
      if (bytes.length + part.length > maxBytes) {
        throw const FormatException('Provider response exceeds size limit');
      }
      bytes.addAll(part);
    }
    try {
      // Large provider catalogs must never JSON-decode on the Flutter UI isolate.
      // compute() uses an isolate on Android/Windows (all supported targets).
      return await compute(_decodeProviderJson, bytes);
    } catch (_) {
      throw const FormatException('Provider returned invalid JSON');
    }
  }

  Future<void> authenticate(XtreamAccount account) async {
    final result = await _fetch(account.server.replace(
        path: '/player_api.php',
        queryParameters: {
          'username': account.username,
          'password': account.password
        }));
    if (result is! Map || result['user_info'] is! Map) {
      throw const FormatException('Provider authentication unavailable');
    }
    final details = result['user_info'] as Map;
    if (details['auth'].toString() != '1' ||
        details['status'].toString().toLowerCase() != 'active') {
      throw const FormatException('Account not active or not authorized');
    }
  }

  Future<Map<String, String>> categories(
      XtreamAccount account, XtreamMediaType type) async {
    final endpoint = switch (type) {
      XtreamMediaType.live => 'get_live_categories',
      XtreamMediaType.movie => 'get_vod_categories',
      XtreamMediaType.series => 'get_series_categories',
    };
    final data = await _fetch(account.action(endpoint));
    if (data is! List) {
      throw const FormatException('Invalid category list');
    }
    final output = <String, String>{};
    for (final entry in data) {
      if (entry is! Map) {
        continue;
      }
      final id = entry['category_id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }
      output[id] = entry['category_name']?.toString() ?? 'Other';
    }
    return output;
  }

  Future<List<XtreamItem>> catalog(
      XtreamAccount account, XtreamMediaType type) async {
    final endpoint = switch (type) {
      XtreamMediaType.live => 'get_live_streams',
      XtreamMediaType.movie => 'get_vod_streams',
      XtreamMediaType.series => 'get_series',
    };
    final data = await _fetch(account.action(endpoint));
    if (data is! List) {
      throw const FormatException('Invalid provider catalog');
    }
    final items = <XtreamItem>[];
    for (final entry in data) {
      if (entry is! Map) {
        continue;
      }
      final rawId =
          entry[type == XtreamMediaType.series ? 'series_id' : 'stream_id']
                  ?.toString() ??
              '';
      if (!RegExp(r'^\d{1,15}$').hasMatch(rawId)) {
        continue;
      }
      final rawExtension =
          entry['container_extension']?.toString().toLowerCase() ?? '';
      final extension =
          RegExp(r'^(mp4|mkv|avi|ts|m3u8)$').hasMatch(rawExtension)
              ? rawExtension
              : (type == XtreamMediaType.live ? 'ts' : 'mp4');
      final posterText =
          entry['stream_icon']?.toString() ?? entry['cover']?.toString() ?? '';
      final posterUri = Uri.tryParse(posterText);
      items.add(XtreamItem(
          id: rawId,
          name: entry['name']?.toString() ?? 'Untitled',
          categoryId: entry['category_id']?.toString() ?? '',
          type: type,
          extension: extension,
          poster:
              posterUri != null && ['http', 'https'].contains(posterUri.scheme)
                  ? posterUri
                  : null));
    }
    return items;
  }

  Future<List<XtreamEpisode>> episodes(
      XtreamAccount account, String seriesId) async {
    if (!RegExp(r'^\d{1,15}$').hasMatch(seriesId)) {
      throw const FormatException('Invalid series ID');
    }
    final data = await _fetch(
        account.action('get_series_info', {'series_id': seriesId}));
    if (data is! Map || data['episodes'] is! Map) {
      throw const FormatException('Series episodes unavailable');
    }
    final result = <XtreamEpisode>[];
    for (final group in (data['episodes'] as Map).entries) {
      final season = int.tryParse(group.key.toString()) ?? 0;
      if (group.value is! List) {
        continue;
      }
      for (final raw in (group.value as List)) {
        if (raw is! Map) {
          continue;
        }
        final id = raw['id']?.toString() ?? '';
        if (!RegExp(r'^\d{1,15}$').hasMatch(id)) {
          continue;
        }
        final ext =
            raw['container_extension']?.toString().toLowerCase() ?? 'mp4';
        result.add(XtreamEpisode(
            id: id,
            title: raw['title']?.toString() ?? 'Episode $id',
            season: season,
            extension:
                RegExp(r'^(mp4|mkv|avi|ts)$').hasMatch(ext) ? ext : 'mp4'));
      }
    }
    return result..sort((a, b) => a.season.compareTo(b.season));
  }

  StreamChannel channel(XtreamAccount account, XtreamItem item,
      {String? title, String? episodeId, String? episodeExtension}) {
    final type = item.type == XtreamMediaType.live
        ? 'live'
        : item.type == XtreamMediaType.movie
            ? 'movie'
            : 'series';
    return StreamChannel(
        name: title ?? item.name,
        url: account.mediaUrl(
            type: type,
            id: episodeId ?? item.id,
            extension: episodeExtension ?? item.extension),
        group: item.type.name.toUpperCase(),
        isVod: item.type != XtreamMediaType.live);
  }

  void dispose() => _client.close();
}

// Top-level isolate entrypoint; no account details are logged.
Object? _decodeProviderJson(List<int> bytes) => jsonDecode(utf8.decode(bytes));
