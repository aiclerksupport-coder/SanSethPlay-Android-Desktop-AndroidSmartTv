import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'xtream_client.dart';

/// Account details are confidential: intentionally no toString overrides.
class XtreamStore {
  XtreamStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  static const key = 'sanseth.xtream.account.v1';
  final FlutterSecureStorage _storage;

  Future<XtreamAccount?> load() async {
    final raw = await _storage.read(key: key);
    if (raw == null) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return XtreamAccount(
          server: Uri.parse(map['server'] as String),
          username: map['username'] as String,
          password: map['password'] as String);
    } catch (_) {
      throw const FormatException('Saved provider account is invalid');
    }
  }

  Future<void> save(XtreamAccount account) => _storage.write(
      key: key,
      value: jsonEncode({
        'server': account.server.toString(),
        'username': account.username,
        'password': account.password
      }));

  Future<void> clear() => _storage.delete(key: key);
}
