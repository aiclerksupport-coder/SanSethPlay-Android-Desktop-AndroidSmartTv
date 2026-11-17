import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'recording_recovery.dart';

/// Bounded recording of an HTTP(S) MPEG transport *byte stream*.
/// Does not record HLS (.m3u8), DASH, DRM, or timeshift content.
/// Never log or persist authorization-bearing input URLs.
class DirectTsRecorder {
  DirectTsRecorder({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;
  bool _active = false;
  bool _cancelled = false;
  Future<File?>? _task;

  bool get active => _active;

  static bool supports(Uri url) =>
      (url.scheme == 'https' || url.scheme == 'http') &&
      url.userInfo.isEmpty &&
      url.path.toLowerCase().endsWith('.ts');

  Future<File?> start(
    Uri url, {
    Duration maxDuration = const Duration(minutes: 60),
    int maxBytes = 1024 * 1024 * 1024,
    Directory? directory,
  }) {
    if (_active) {
      throw StateError('Recording already in progress');
    }
    if (!supports(url)) {
      throw ArgumentError('Only direct .ts streams are supported');
    }
    if (maxBytes < 188 || maxDuration <= Duration.zero) {
      throw ArgumentError('Invalid recording limits');
    }
    _active = true;
    _cancelled = false;
    _task = _record(url, maxDuration, maxBytes, directory);
    return _task!;
  }

  Future<File?> _record(
      Uri url, Duration maxDuration, int maxBytes, Directory? directory) async {
    File? file;
    IOSink? sink;
    Timer? deadline;
    try {
      _client.connectionTimeout = const Duration(seconds: 12);
      _client.autoUncompress = false;
      final request = await _client.getUrl(url);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('Recording source refused request');
      }
      final type = response.headers.contentType?.mimeType.toLowerCase();
      if (type != null && type.contains('mpegurl')) {
        throw const FormatException('HLS manifest cannot be recorded as TS');
      }
      final output = directory ?? await getApplicationDocumentsDirectory();
      await output.create(recursive: true);
      final label = DateTime.now().toUtc().microsecondsSinceEpoch;
      file = RecordingRecovery.temporaryFor(
          File('${output.path}${Platform.pathSeparator}SanSeth-$label.ts'));
      sink = file.openWrite();
      var received = 0;
      deadline = Timer(maxDuration, () {
        _cancelled = true;
        _client.close(force: true);
      });
      try {
        await for (final chunk in response) {
          if (_cancelled) {
            break;
          }
          received += chunk.length;
          if (received > maxBytes) {
            throw const FileSystemException('Recording storage quota reached');
          }
          sink.add(chunk);
        }
      } catch (_) {
        if (!_cancelled) {
          rethrow;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (received == 0) {
        throw const FormatException('Empty stream');
      }
      return RecordingRecovery.finalize(file);
    } catch (_) {
      if (sink != null) {
        await sink.close().catchError((Object _) {});
      }
      // Preserve any complete TS packets for explicit recovery after a crash.
      // The .part suffix keeps incomplete files out of normal library lists.
      rethrow;
    } finally {
      deadline?.cancel();
      _client.close(force: true);
      _active = false;
    }
  }

  void stop() {
    _cancelled = true;
    _client.close(force: true);
  }
}
