import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'recording_recovery.dart';

/// Bounded, live HLS MPEG-TS segment recorder.
/// Deliberately excludes master playlists, AES/DRM, fMP4, byte ranges, and
/// custom authenticated headers. Recording requires user permission/rights.
class HlsTsRecorder {
  HlsTsRecorder({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;
  bool _active = false;
  bool _stopped = false;
  bool get active => _active;

  static bool supports(Uri url) =>
      (url.scheme == 'https' || url.scheme == 'http') &&
      url.userInfo.isEmpty &&
      url.path.toLowerCase().endsWith('.m3u8');

  void stop() {
    _stopped = true;
    _client.close(force: true);
  }

  Future<File?> start(
    Uri url, {
    Directory? directory,
    Duration maxDuration = const Duration(minutes: 60),
    int maxBytes = 1024 * 1024 * 1024,
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    if (_active) {
      throw StateError('Recording already active');
    }
    if (!supports(url)) {
      throw ArgumentError('Expected an HTTP(S) .m3u8 URL');
    }
    if (maxBytes < 188 ||
        maxDuration <= Duration.zero ||
        pollInterval <= Duration.zero) {
      throw ArgumentError('Invalid recording bounds');
    }
    _active = true;
    _stopped = false;
    _client.connectionTimeout = const Duration(seconds: 12);
    _client.autoUncompress = false;
    File? file;
    IOSink? sink;
    var received = 0;
    final seen = <int>{};
    var firstSnapshot = true;
    var completed = false;
    final started = DateTime.now();
    try {
      final folder = directory ?? await getApplicationDocumentsDirectory();
      await folder.create(recursive: true);
      final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
      file = RecordingRecovery.temporaryFor(
          File('${folder.path}${Platform.pathSeparator}SanSeth-HLS-$stamp.ts'));
      sink = file.openWrite();
      while (!_stopped && DateTime.now().difference(started) < maxDuration) {
        String playlist;
        try {
          playlist = utf8.decode(await _fetch(url, maxBytes: 2 * 1024 * 1024));
        } catch (_) {
          if (_stopped) {
            break;
          }
          rethrow;
        }
        if (_stopped) {
          break;
        }
        final manifest = HlsTsManifest.parse(playlist, url);
        // LIVE playlists often contain old segments. Begin close to the live
        // edge; on later polls only consider a bounded recent window.
        final recentSegments = manifest.segments.skip(
          manifest.segments.length > (firstSnapshot ? 3 : 12)
              ? manifest.segments.length - (firstSnapshot ? 3 : 12)
              : 0,
        );
        firstSnapshot = false;
        for (final segment in recentSegments) {
          if (_stopped || DateTime.now().difference(started) >= maxDuration) {
            break;
          }
          if (seen.contains(segment.sequence)) {
            continue;
          }
          List<int> bytes;
          try {
            bytes = await _fetch(segment.url,
                maxBytes:
                    (maxBytes - received).clamp(0, 32 * 1024 * 1024).toInt());
          } catch (_) {
            if (_stopped) {
              break;
            }
            rethrow;
          }
          if (received + bytes.length > maxBytes) {
            completed = true;
            break;
          }
          // A valid TS recording must contain complete 188-byte packets.
          // Checking just the first sync byte can silently save corrupt media.
          if (bytes.isEmpty || bytes.length % 188 != 0) {
            throw const FormatException('Incomplete MPEG-TS segment');
          }
          for (var packet = 0; packet < bytes.length; packet += 188) {
            if (bytes[packet] != 0x47) {
              throw const FormatException('Invalid MPEG-TS packet sync');
            }
          }
          if (_stopped) {
            break;
          }
          sink.add(bytes);
          received += bytes.length;
          seen.add(segment.sequence);
        }
        // Retain only IDs still relevant to the current manifest. Avoid an
        // unbounded set during multi-hour sessions on low-memory Android TV.
        final keep = manifest.segments
            .skip(
              manifest.segments.length > 36 ? manifest.segments.length - 36 : 0,
            )
            .map((segment) => segment.sequence)
            .toSet();
        seen.removeWhere((sequence) => !keep.contains(sequence));
        if (completed || manifest.endList || _stopped) {
          break;
        }
        // Timer-free bounded delay: Stop() closes client but sleeping waits at
        // most the configured interval before graceful finalization.
        await Future<void>.delayed(pollInterval);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (received == 0) {
        await file.delete();
        return null;
      }
      return RecordingRecovery.finalize(file);
    } catch (_) {
      if (sink != null) {
        await sink.close().catchError((Object _) {});
      }
      // Preserve .part for manual recovery, never surface as valid media.
      rethrow;
    } finally {
      _active = false;
      _client.close(force: true);
    }
  }

  Future<List<int>> _fetch(Uri uri, {required int maxBytes}) async {
    if (uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        maxBytes <= 0) {
      throw const FormatException('Unsafe or oversized HLS request');
    }
    final request =
        await _client.getUrl(uri).timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw const HttpException('HLS resource unavailable');
    }
    final chunks = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      if (_stopped) {
        break;
      }
      if (chunks.length + chunk.length > maxBytes) {
        throw const FormatException('HLS resource exceeds size budget');
      }
      chunks.addAll(chunk);
    }
    return chunks;
  }
}

class HlsTsSegment {
  const HlsTsSegment(this.sequence, this.url);
  final int sequence;
  final Uri url;
}

class HlsTsManifest {
  const HlsTsManifest(this.segments, this.endList);
  final List<HlsTsSegment> segments;
  final bool endList;

  static HlsTsManifest parse(String raw, Uri origin) {
    final lines = raw.replaceFirst('\uFEFF', '').split(RegExp(r'\r\n|\r|\n'));
    if (lines.isEmpty || lines.first.trim() != '#EXTM3U') {
      throw const FormatException('Invalid HLS manifest');
    }
    final segments = <HlsTsSegment>[];
    var sequence = 0;
    var hasMediaTag = false;
    var endList = false;
    for (final original in lines.skip(1)) {
      final line = original.trim();
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        sequence = int.tryParse(line.substring(22).trim()) ?? -1;
        if (sequence < 0) {
          throw const FormatException('Bad media sequence');
        }
      } else if (line.startsWith('#EXTINF:')) {
        hasMediaTag = true;
      } else if (line == '#EXT-X-ENDLIST') {
        endList = true;
      } else if (line.startsWith('#EXT-X-STREAM-INF') ||
          line.startsWith('#EXT-X-I-FRAME-STREAM-INF') ||
          line.startsWith('#EXT-X-KEY') ||
          line.startsWith('#EXT-X-MAP') ||
          line.startsWith('#EXT-X-BYTERANGE') ||
          line.startsWith('#EXT-X-PART') ||
          line.startsWith('#EXT-X-PRELOAD-HINT') ||
          line.startsWith('#EXT-X-SESSION-KEY') ||
          line.startsWith('#EXT-X-DISCONTINUITY') ||
          line.startsWith('#EXT-X-GAP') ||
          line.startsWith('#EXT-X-SKIP') ||
          line.startsWith('#EXT-X-DEFINE')) {
        throw const FormatException('Unsupported encrypted/variant/fMP4 HLS');
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (!hasMediaTag) {
          throw const FormatException('Missing EXTINF segment marker');
        }
        hasMediaTag = false;
        final uri = origin.resolve(line);
        if ((uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.userInfo.isNotEmpty ||
            !uri.path.toLowerCase().endsWith('.ts')) {
          throw const FormatException('Only TS segment URLs supported');
        }
        segments.add(HlsTsSegment(sequence++, uri));
        if (segments.length > 20000) {
          throw const FormatException('Excessive HLS segments');
        }
      }
    }
    if (segments.isEmpty) {
      throw const FormatException('No TS segments found');
    }
    return HlsTsManifest(segments, endList);
  }
}
