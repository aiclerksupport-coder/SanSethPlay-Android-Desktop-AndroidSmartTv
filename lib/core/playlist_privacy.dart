import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class PlaylistPrivacy {
  const PlaylistPrivacy({this.hidden = false, this.locked = false});
  final bool hidden;
  final bool locked;
  bool get protected => hidden || locked;
  Map<String, bool> toJson() => {'hidden': hidden, 'locked': locked};
  static PlaylistPrivacy fromJson(Object? source) {
    if (source is! Map) return const PlaylistPrivacy();
    return PlaylistPrivacy(
        hidden: source['hidden'] == true, locked: source['locked'] == true);
  }
}

/// Stored in OS-backed secure storage; never store plaintext PINs or recovery codes.
/// This protects the UI from casual access, not against a compromised device.
class PlaylistPrivacyStore {
  PlaylistPrivacyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _privacyKey = 'sanseth.playlist.privacy.v1';
  static const _pinKey = 'sanseth.playlist.owner.pin.v1';
  static const _recoveryKey = 'sanseth.playlist.owner.recovery.v1';
  final _random = Random.secure();

  Future<Map<String, PlaylistPrivacy>> load() async {
    final raw = await _storage.read(key: _privacyKey);
    if (raw == null || raw.isEmpty) return {};
    final value = jsonDecode(raw);
    if (value is! Map) throw const FormatException('Invalid privacy records');
    return value.map((key, entry) =>
        MapEntry(key.toString(), PlaylistPrivacy.fromJson(entry)));
  }

  Future<void> save(Map<String, PlaylistPrivacy> entries) => _storage.write(
        key: _privacyKey,
        value: jsonEncode(
            entries.map((key, value) => MapEntry(key, value.toJson()))),
      );

  String _salt() => List.generate(16, (_) => _random.nextInt(256))
      .map((v) => v.toRadixString(16).padLeft(2, '0'))
      .join();
  static String deriveHash(List<String> parts) {
    // This CPU work runs on a separate isolate, never the UI thread.
    List<int> current = utf8.encode('${parts[1]}:${parts[0]}');
    for (var i = 0; i < 12000; i++) {
      current = sha256.convert(current).bytes;
    }
    return base64Encode(current);
  }

  Future<void> _writeVerifier(String key, String value) async {
    final salt = _salt();
    final digest = await compute(deriveHash, [value, salt]);
    await _storage.write(key: key, value: '$salt:$digest');
  }

  Future<bool> _verify(String key, String supplied) async {
    final saved = await _storage.read(key: key);
    if (saved == null) return false;
    final divider = saved.indexOf(':');
    if (divider <= 0) return false;
    final expected = saved.substring(divider + 1);
    final actual =
        await compute(deriveHash, [supplied, saved.substring(0, divider)]);
    if (expected.length != actual.length) return false;
    var mismatch = 0;
    for (var i = 0; i < expected.length; i++) {
      mismatch |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return mismatch == 0;
  }

  static bool isAcceptablePin(String pin) {
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return false;
    if ('01234567890123456789'.contains(pin) ||
        '98765432109876543210'.contains(pin)) {
      return false;
    }
    return true;
  }

  Future<bool> get hasPin async => await _storage.read(key: _pinKey) != null;
  Future<void> setPin(String pin) async {
    if (!isAcceptablePin(pin)) {
      throw const FormatException('Choose a non-trivial 6–12 digit PIN');
    }
    await _writeVerifier(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) => _verify(_pinKey, pin);
  Future<bool> verifyRecovery(String code) =>
      _verify(_recoveryKey, code.trim().toUpperCase());
  Future<String> makeRecoveryCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code =
        List.generate(20, (_) => alphabet[_random.nextInt(alphabet.length)])
            .join();
    await _writeVerifier(_recoveryKey, code);
    return code;
  }

  Future<void> clearPlaylist(String id) async {
    final entries = await load();
    entries.remove(id);
    await save(entries);
  }
}
