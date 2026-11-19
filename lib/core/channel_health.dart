import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conservative, per-device channel observations. An HTTP status is NOT proof
/// that video decodes; only the active player can confirm actual playback.
/// Unknown, geo-restricted and transient failures remain visible.
enum ChannelHealth {
  unknown,
  reachable,
  playing,
  unavailable,
  temporarilyUnavailable
}

class ChannelHealthRecord {
  const ChannelHealthRecord(this.health, this.checkedAt, this.failures);
  final ChannelHealth health;
  final DateTime checkedAt;
  final int failures;
}

class ChannelHealthStore extends ChangeNotifier {
  ChannelHealthStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _storageKey = 'sanseth.channel.health.v1';
  static const _unavailableLifetime = Duration(minutes: 5);
  static const _playingLifetime = Duration(hours: 2);
  static const _temporaryFailureLifetime = Duration(minutes: 2);
  final DateTime Function() _now;
  final Map<String, ChannelHealthRecord> _records = {};
  Timer? _saveTimer;
  bool _disposed = false;
  bool _hasConfirmedUnavailable = false;
  bool get hasConfirmedUnavailable => _hasConfirmedUnavailable;

  /// Full URL is an in-memory key. Disk only contains a hash for failed links;
  /// provider tokens and credentials are never written to health telemetry.
  static String _key(Uri url) {
    // Two independent 32-bit hashes keep computation cheap for 50k entries
    // while keeping the stored key free of URLs and bearer query tokens.
    var a = 0x811c9dc5;
    var b = 5381;
    for (final unit in utf8.encode(url.toString())) {
      a = ((a ^ unit) * 0x01000193) & 0xffffffff;
      b = ((b * 33) ^ unit) & 0xffffffff;
    }
    return '${a.toRadixString(16).padLeft(8, '0')}'
        '${b.toRadixString(16).padLeft(8, '0')}';
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.length > 250000) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      final now = _now();
      for (final entry in data.entries) {
        if (entry.value is! int) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(entry.value as int);
        if (!_records.containsKey(entry.key) &&
            now.difference(date) >= Duration.zero &&
            now.difference(date) < _unavailableLifetime) {
          _records[entry.key] =
              ChannelHealthRecord(ChannelHealth.unavailable, date, 2);
        }
      }
      _hasConfirmedUnavailable = _records.values
          .any((record) => record.health == ChannelHealth.unavailable);
    } catch (_) {
      // Telemetry is optional; never prevent the playlist from loading.
    }
    if (!_disposed) notifyListeners();
  }

  ChannelHealth status(Uri url) {
    final record = _records[_key(url)];
    if (record == null) return ChannelHealth.unknown;
    final elapsed = _now().difference(record.checkedAt);
    if (elapsed.isNegative) return ChannelHealth.unknown;
    if (record.health == ChannelHealth.unavailable &&
        elapsed >= _unavailableLifetime) {
      return ChannelHealth.unknown;
    }
    if (record.health == ChannelHealth.playing && elapsed >= _playingLifetime) {
      return ChannelHealth.unknown;
    }
    if (record.health == ChannelHealth.temporarilyUnavailable &&
        elapsed >= _temporaryFailureLifetime) {
      return ChannelHealth.unknown;
    }
    return record.health;
  }

  bool shouldProbe(Uri url) {
    final record = _records[_key(url)];
    if (record == null) return true;
    final elapsed = _now().difference(record.checkedAt);
    if (elapsed.isNegative) return true;
    if (record.health == ChannelHealth.playing && elapsed < _playingLifetime) {
      return false;
    }
    return elapsed >=
        (record.health == ChannelHealth.temporarilyUnavailable
            ? _temporaryFailureLifetime
            : record.health == ChannelHealth.unavailable
                ? _unavailableLifetime
                : record.health == ChannelHealth.unknown && record.failures > 0
                    ? const Duration(seconds: 20)
                    : const Duration(minutes: 15));
  }

  void playing(Uri url) {
    _records[_key(url)] = ChannelHealthRecord(ChannelHealth.playing, _now(), 0);
    if (!_disposed) notifyListeners();
    _scheduleSave();
  }

  void probeResult(Uri url,
      {required bool reachable, required bool definitiveMissing}) {
    if (!reachable && !definitiveMissing) return;
    final key = _key(url);
    final old = _records[key];
    // Never downgrade a recently playing stream because of an HTTP probe.
    if (old?.health == ChannelHealth.playing && !shouldProbe(url)) return;
    if (reachable) {
      _records[key] = ChannelHealthRecord(ChannelHealth.reachable, _now(), 0);
    } else {
      // A first 404/410 may be a stale CDN edge or rotating access token.
      final failures = (old?.failures ?? 0) + 1;
      _records[key] = ChannelHealthRecord(
          failures >= 2 ? ChannelHealth.unavailable : ChannelHealth.unknown,
          _now(),
          failures);
    }
    if (_records[key]?.health == ChannelHealth.unavailable) {
      _hasConfirmedUnavailable = true;
    } else if (old?.health == ChannelHealth.unavailable) {
      _hasConfirmedUnavailable = _records.values
          .any((record) => record.health == ChannelHealth.unavailable);
    }
    if (!_disposed &&
        (old?.health == ChannelHealth.unavailable ||
            _records[key]?.health == ChannelHealth.unavailable)) {
      notifyListeners();
    }
    if (old?.health == ChannelHealth.unavailable ||
        _records[key]?.health == ChannelHealth.unavailable) {
      _scheduleSave();
    }
  }

  /// Expired failures are unhidden even without a new remote request.
  void expire() {
    final now = _now();
    final expired = _records.entries
        .where((entry) => (entry.value.health == ChannelHealth.unavailable &&
                now.difference(entry.value.checkedAt) >= _unavailableLifetime ||
            entry.value.health == ChannelHealth.temporarilyUnavailable &&
                now.difference(entry.value.checkedAt) >=
                    _temporaryFailureLifetime))
        .map((entry) => entry.key)
        .toList(growable: false);
    if (expired.isEmpty) return;
    for (final key in expired) {
      _records.remove(key);
    }
    _hasConfirmedUnavailable = _records.values
        .any((record) => record.health == ChannelHealth.unavailable);
    if (!_disposed) notifyListeners();
    _scheduleSave();
  }

  /// Exhausted decoder retries are advisory, not proof of a permanently dead
  /// channel. A user can always choose it again; no auto-hide here.
  void playbackFailed(Uri url) {
    final key = _key(url);
    if (_records[key]?.health == ChannelHealth.playing) return;
    _records[key] = ChannelHealthRecord(ChannelHealth.unknown, _now(), 0);
    if (!_disposed) notifyListeners();
  }

  /// Decoder exhausted its retries. Hide only temporarily from filtered
  /// lists; never erase a playlist entry or persist this ambiguous failure.
  /// A user can immediately recover it using Show all channels.
  void playbackExhausted(Uri url) {
    final key = _key(url);
    // A stream that worked earlier may fail now; this remains a short,
    // reversible UI observation, not a permanent link classification.
    _records[key] =
        ChannelHealthRecord(ChannelHealth.temporarilyUnavailable, _now(), 0);
    if (!_disposed) notifyListeners();
  }

  void _scheduleSave() {
    if (_disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 4), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    try {
      final items = _records.entries
          .where((entry) =>
              entry.value.health == ChannelHealth.unavailable &&
              _now().difference(entry.value.checkedAt) < _unavailableLifetime)
          .take(3000);
      final encoded = jsonEncode({
        for (final e in items) e.key: e.value.checkedAt.millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, encoded);
    } catch (_) {/* Health cache never blocks playback. */}
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }
}

/// Lightweight best-effort reachability only. Do not decode media here,
/// consume full segments, or open a second decoder next to the real player.
class ChannelProbe {
  const ChannelProbe();

  Future<({bool reachable, bool definitiveMissing})> check(Uri url) async {
    if (url.scheme != 'https' && url.scheme != 'http') {
      return (reachable: false, definitiveMissing: false);
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..idleTimeout = const Duration(seconds: 2)
      ..maxConnectionsPerHost = 1;
    try {
      final request =
          await client.getUrl(url).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
      request.followRedirects = true;
      request.maxRedirects = 3;
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      final status = response.statusCode;
      // Stop after headers: 2xx does not mean video decodes. Do not buffer an
      // entire stream in memory or compete with the active decoder.
      if (status == HttpStatus.ok || status == HttpStatus.partialContent) {
        return (reachable: true, definitiveMissing: false);
      }
      // 401/403/429/5xx/timeouts might be transient or device-specific.
      return (
        reachable: false,
        definitiveMissing:
            status == HttpStatus.notFound || status == HttpStatus.gone
      );
    } catch (_) {
      return (reachable: false, definitiveMissing: false);
    } finally {
      client.close(force: true);
    }
  }
}

/// Limited, low-priority checks. No automatic 50k parallel requests.
/// The UI stays responsive and existing playback always takes priority.
class ChannelHealthScanner {
  ChannelHealthScanner(this.store, {ChannelProbe probe = const ChannelProbe()})
      : _probe = probe;
  final ChannelHealthStore store;
  final ChannelProbe _probe;
  final List<Uri> _pending = [];
  final Set<String> _queued = {};
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;
  Uri? activePlayback;

  void enqueue(Iterable<Uri> urls) {
    if (_disposed) return;
    for (final url in urls) {
      if (_pending.length >= 120 ||
          !store.shouldProbe(url) ||
          url == activePlayback ||
          !_queued.add(url.toString())) {
        continue;
      }
      _pending.add(url);
    }
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    if (_busy || _disposed || _pending.isEmpty) return;
    final url = _pending.removeAt(0);
    _queued.remove(url.toString());
    if (url == activePlayback || !store.shouldProbe(url)) return;
    _busy = true;
    try {
      final result = await _probe.check(url);
      if (!_disposed && url != activePlayback) {
        store.probeResult(url,
            reachable: result.reachable,
            definitiveMissing: result.definitiveMissing);
      }
    } finally {
      _busy = false;
    }
  }

  void clear() {
    _pending.clear();
    _queued.clear();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    clear();
  }
}
