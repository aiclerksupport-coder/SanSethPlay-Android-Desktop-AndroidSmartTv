import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bounded playback history. Never persists stream URLs or access tokens.
/// Identifiers refer only to streams still present in an imported playlist.
class RecentChannelStore {
  static const storageKey = 'recent_stream_hashes_v1';
  static const maxEntries = 40;

  static String identifier(Uri url) =>
      sha256.convert(utf8.encode(url.toString())).toString();

  static List<String> normalize(Iterable<String> input) {
    final unique = <String>{};
    for (final item in input) {
      if (RegExp(r'^[a-f0-9]{64}$').hasMatch(item)) {
        unique.add(item);
        if (unique.length == maxEntries) {
          break;
        }
      }
    }
    return unique.toList(growable: false);
  }

  static List<String> record(List<String> current, Uri channel) =>
      normalize([identifier(channel), ...current]);

  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return normalize(preferences.getStringList(storageKey) ?? const []);
  }

  Future<void> save(List<String> identifiers) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setStringList(storageKey, normalize(identifiers))) {
      throw StateError('Recent history could not be saved');
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(storageKey)) {
      throw StateError('Recent history could not be cleared');
    }
  }
}
