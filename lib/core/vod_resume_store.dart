import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores bounded VOD position only. Credential-bearing stream URLs are NEVER
/// written to preferences. A completed title clears its saved position.
class VodResumeStore {
  static const prefix = 'sanseth.vod.resume.v1.';
  static const maxPosition = Duration(hours: 24);

  static String keyFor(Uri url) =>
      '$prefix${sha256.convert(utf8.encode(url.toString()))}';

  static Duration? validResume(int millis, Duration duration) {
    if (duration < const Duration(minutes: 5) ||
        millis < const Duration(seconds: 30).inMilliseconds ||
        millis > maxPosition.inMilliseconds ||
        millis >= duration.inMilliseconds * 0.95) {
      return null;
    }
    return Duration(milliseconds: millis);
  }

  Future<Duration?> read(Uri url, Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    return validResume(prefs.getInt(keyFor(url)) ?? 0, duration);
  }

  Future<void> write(Uri url, Duration position, Duration duration) async {
    if (duration < const Duration(minutes: 5)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(url);
    if (validResume(position.inMilliseconds, duration) == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, position.inMilliseconds);
    }
  }
}
