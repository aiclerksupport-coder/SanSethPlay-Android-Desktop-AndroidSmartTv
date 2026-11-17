import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'hls_ts_recorder.dart';

/// A small, local, temporary live-DVR proxy for *unencrypted MPEG-TS HLS*.
/// The saved segments are private app cache, not recordings. No DRM bypass.
/// Only the active player may access the randomly named loopback playlist.
class HlsTimeshift {
  HlsTimeshift({
    this.maxBytes = 128 * 1024 * 1024,
    this.maxWindow = const Duration(minutes: 5),
    this.pollEvery = const Duration(seconds: 3),
  });

  final int maxBytes;
  final Duration maxWindow;
  final Duration pollEvery;
  HttpClient? _client;
  HttpServer? _server;
  Directory? _cache;
  bool _stopped = false;
  int _epoch = 0;
  Future<void>? _worker;
  final List<_LocalSegment> _segments = [];
  int _bytes = 0;
  late String _secret;
  Uri? _source;
  Uri? _local;

  bool get active => !_stopped && _local != null;
  Uri? get localPlaylist => _local;
  Duration get bufferedDuration => _segments.fold(
      Duration.zero, (duration, item) => duration + item.duration);

  static bool supports(Uri uri) =>
      HlsTsRecorder.supports(uri) && uri.fragment.isEmpty;

  Future<Uri> start(Uri source) async {
    if (_worker != null || _server != null) {
      throw StateError('Timeshift already active');
    }
    if (!supports(source) ||
        maxBytes < 2 * 1024 * 1024 ||
        maxWindow <= Duration.zero ||
        pollEvery <= Duration.zero) {
      throw ArgumentError('Unsupported source or limits');
    }
    _stopped = false;
    final epoch = ++_epoch;
    _source = source;
    _secret = List<int>.generate(16, (_) => Random.secure().nextInt(256))
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    _cache = await Directory.systemTemp.createTemp('sanseth-timeshift-');
    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..autoUncompress = false;
    try {
      // A usable segment must exist before the local playlist is opened.
      await _collectOnce();
      if (_segments.isEmpty) {
        throw const FormatException('No playable TS segment');
      }
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _local =
          Uri.parse('http://127.0.0.1:${_server!.port}/$_secret/live.m3u8');
      _server!.listen(_serve, onError: (_) {}, cancelOnError: false);
      _worker = _poll(epoch);
      return _local!;
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> _poll(int epoch) async {
    while (!_stopped && _epoch == epoch) {
      await Future<void>.delayed(pollEvery);
      if (_stopped || _epoch != epoch) {
        return;
      }
      try {
        await _collectOnce();
      } catch (_) {
        // Keep last-known-good segments until the source is reachable again.
      }
    }
  }

  Future<void> _collectOnce() async {
    final origin = _source!;
    final payload = await _fetch(origin, 2 * 1024 * 1024);
    if (_stopped) {
      return;
    }
    final manifest = HlsTsManifest.parse(utf8.decode(payload), origin);
    final durationBySequence = _durations(utf8.decode(payload), manifest);
    // Avoid downloading hours of backlog when first opening a large manifest.
    final candidates = _segments.isEmpty
        ? manifest.segments.skip(max(0, manifest.segments.length - 3))
        : manifest.segments.skip(max(0, manifest.segments.length - 12));
    for (final segment in candidates) {
      if (_stopped) {
        return;
      }
      if (_segments.any((s) => s.sequence == segment.sequence)) {
        continue;
      }
      // Never download older segments after the live window has advanced.
      if (_segments.isNotEmpty && segment.sequence <= _segments.last.sequence) {
        continue;
      }
      final bytes = await _fetch(segment.url, 16 * 1024 * 1024);
      if (_stopped) {
        return;
      }
      if (bytes.length < 188 || bytes.length % 188 != 0 || bytes[0] != 0x47) {
        throw const FormatException('Invalid MPEG-TS segment');
      }
      if (bytes.length > maxBytes) {
        throw const FormatException('Segment over DVR limit');
      }
      final file = File(
          '${_cache!.path}${Platform.pathSeparator}${segment.sequence}.ts');
      // Verify sync bytes at every TS packet boundary, not only the first.
      for (var offset = 0; offset < bytes.length; offset += 188) {
        if (bytes[offset] != 0x47) {
          throw const FormatException('Invalid TS packet sync');
        }
      }
      await file.writeAsBytes(bytes, flush: true);
      // Stop can race an in-flight disk write. Do not advertise a segment
      // from a stopped or replaced session in the local playlist.
      if (_stopped || _cache == null) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
        return;
      }
      final length =
          durationBySequence[segment.sequence] ?? const Duration(seconds: 6);
      _segments
          .add(_LocalSegment(segment.sequence, file, bytes.length, length));
      _bytes += bytes.length;
      await _prune();
    }
  }

  static Map<int, Duration> _durations(String raw, HlsTsManifest manifest) {
    final values = <Duration>[];
    for (final line in raw.split(RegExp(r'\r\n|\r|\n'))) {
      if (!line.startsWith('#EXTINF:')) {
        continue;
      }
      final seconds =
          double.tryParse(line.substring(8).split(',').first.trim());
      if (seconds == null || seconds <= 0 || seconds > 120) {
        throw const FormatException('Invalid segment duration');
      }
      values.add(Duration(milliseconds: (seconds * 1000).round()));
    }
    if (values.length != manifest.segments.length) {
      throw const FormatException('HLS segment timing mismatch');
    }
    return {
      for (var i = 0; i < values.length; i++)
        manifest.segments[i].sequence: values[i],
    };
  }

  Future<void> _prune() async {
    while (_segments.length > 1 &&
        (_bytes > maxBytes || bufferedDuration > maxWindow)) {
      // An in-flight decoder request may still be reading the oldest segment.
      // Defer eviction rather than race file deletion with the local server.
      if (_segments.first.readers > 0) {
        return;
      }
      final old = _segments.removeAt(0);
      _bytes -= old.size;
      try {
        if (await old.file.exists()) {
          await old.file.delete();
        }
      } catch (_) {}
    }
  }

  Future<List<int>> _fetch(Uri url, int limit) async {
    if (url.userInfo.isNotEmpty ||
        (url.scheme != 'http' && url.scheme != 'https')) {
      throw const FormatException('Unsupported URL');
    }
    final request =
        await _client!.getUrl(url).timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const HttpException('Source unavailable');
    }
    final result = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      if (_stopped) {
        return const [];
      }
      if (result.length + chunk.length > limit) {
        throw const FormatException('HLS payload exceeds limit');
      }
      result.addAll(chunk);
    }
    return result;
  }

  void _serve(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('Access-Control-Allow-Origin', 'null');
    try {
      if (request.method != 'GET' ||
          request.uri.pathSegments.length != 2 ||
          request.uri.pathSegments.first != _secret) {
        response.statusCode = 404;
      } else if (request.uri.pathSegments.last == 'live.m3u8') {
        if (_segments.isEmpty) {
          response.statusCode = 503;
        } else {
          response.headers.contentType =
              ContentType('application', 'vnd.apple.mpegurl');
          response.write(renderManifest(_segments
              .map((s) => (
                    sequence: s.sequence,
                    duration: s.duration,
                    file: '${s.sequence}.ts',
                  ))
              .toList()));
        }
      } else {
        final name = request.uri.pathSegments.last;
        final sequence = int.tryParse(name.replaceFirst(RegExp(r'\.ts$'), ''));
        final found = name.endsWith('.ts') && sequence != null
            ? _segments.where((s) => s.sequence == sequence).toList()
            : <_LocalSegment>[];
        if (found.isEmpty) {
          response.statusCode = 404;
        } else {
          final segment = found.first;
          segment.readers++;
          try {
            response.headers.contentType = ContentType('video', 'mp2t');
            await response.addStream(segment.file.openRead());
          } finally {
            segment.readers--;
            // Eviction was deferred while a decoder was reading the segment.
            // Finish response first, then schedule a bounded cleanup.
            unawaited(_prune().catchError((Object _) {}));
          }
        }
      }
    } catch (_) {
      // An evicted file is a normal sliding-window race; never serve other files.
      // Response may already be streaming; do not mutate sent headers.
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  static String renderManifest(
      List<({int sequence, Duration duration, String file})> input) {
    if (input.isEmpty) {
      throw ArgumentError('Empty live window');
    }
    final target = input.map((s) => s.duration.inMilliseconds).reduce(max);
    final out = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#EXT-X-VERSION:3')
      ..writeln('#EXT-X-TARGETDURATION:${(target / 1000).ceil()}')
      ..writeln('#EXT-X-MEDIA-SEQUENCE:${input.first.sequence}');
    for (final segment in input) {
      out.writeln(
          '#EXTINF:${(segment.duration.inMilliseconds / 1000).toStringAsFixed(3)},');
      out.writeln(segment.file);
    }
    return out.toString();
  }

  Future<void> stop() async {
    _stopped = true;
    ++_epoch;
    _client?.close(force: true);
    await _server?.close(force: true);
    _server = null;
    _local = null;
    // Poller observes _stopped, but do not block indefinitely on network.
    final folder = _cache;
    _cache = null;
    if (folder != null) {
      try {
        await folder.delete(recursive: true);
      } catch (_) {}
    }
    _segments.clear();
    _bytes = 0;
    _worker = null;
    _client = null;
  }
}

class _LocalSegment {
  _LocalSegment(this.sequence, this.file, this.size, this.duration);
  final int sequence;
  final File file;
  final int size;
  final Duration duration;
  int readers = 0;
}
