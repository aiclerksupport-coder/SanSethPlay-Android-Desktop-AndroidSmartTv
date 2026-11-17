import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores only one-way identifiers: playback URLs (often containing access
/// tokens) are NEVER written to SharedPreferences by favorites.
class FavoriteStore {
  static const _key = 'favorite_stream_hashes_v1';

  static String identifier(Uri stream) =>
      sha256.convert(utf8.encode(stream.toString())).toString();

  Future<Set<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key) ?? const <String>[]).toSet();
  }

  Future<void> save(Set<String> identifiers) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = identifiers.toList()..sort();
    if (!await preferences.setStringList(_key, sorted)) {
      throw StateError('Favorites were not saved');
    }
  }
}
