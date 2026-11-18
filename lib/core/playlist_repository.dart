import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'm3u_parser.dart';
import 'saved_playlist.dart';

class PlaylistRepository {
  PlaylistRepository({http.Client? client}) : _client = client ?? http.Client();
  static const maxBytes = 64 * 1024 * 1024;
  final http.Client _client;

  Future<List<StreamChannel>> fromText(String contents) async {
    if (utf8.encode(contents).length > maxBytes) {
      throw const FormatException(
          'Playlist device safety limit (64 MB) se badi hai.');
    }
    return compute(M3uParser.parse, contents);
  }

  Future<List<StreamChannel>> fromUrl(Uri source) async {
    var uri = normalizePlaylistUrl(source);
    // Do not interpret HLS manifests as channel lists: they describe
    // media segments, and have different EXTINF semantics from IPTV lists.
    if (uri.path.toLowerCase().endsWith('.m3u8')) {
      return [directChannel(uri)];
    }
    for (var redirects = 0; redirects <= 4; redirects++) {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response =
          await _client.send(request).timeout(const Duration(seconds: 18));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null || redirects == 4) {
          throw const FormatException('Too many redirects.');
        }
        final next = normalizePlaylistUrl(uri.resolve(location));
        if (uri.isScheme('https') && !next.isScheme('https')) {
          throw const FormatException('Unsafe HTTPS downgrade redirect.');
        }
        uri = next;
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw FormatException('Playlist download HTTP ${response.statusCode}.');
      }
      final bytes = <int>[];
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 18))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException(
              'Playlist device safety limit (64 MB) se badi hai.');
        }
        bytes.addAll(chunk);
      }
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final payload = utf8.decode(bytes, allowMalformed: true);
      if (contentType.contains('mpegurl') &&
          uri.path.toLowerCase().endsWith('.m3u8')) {
        return [directChannel(uri)];
      }
      if (!payload.trimLeft().startsWith('#EXTM3U')) {
        throw const FormatException(
            'Ye valid M3U playlist nahi hai. Direct stream mode use karein.');
      }
      return fromText(payload);
    }
    throw const FormatException('Redirect limit reached.');
  }

  StreamChannel directChannel(Uri source, {String? name}) {
    final uri = normalizePlaylistUrl(source);
    final last = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final fallback = last.isEmpty ? uri.host : last.last;
    return StreamChannel(
      name: name?.trim().isNotEmpty == true ? name!.trim() : fallback,
      url: uri,
      group: 'Direct Streams',
    );
  }

  void dispose() => _client.close();
}
