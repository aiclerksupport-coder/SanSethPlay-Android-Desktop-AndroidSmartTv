import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'channel.dart';

/// Last-known-good encrypted snapshots in a transactionally updated SQLite DB.
/// Each playlist is one AES-256-GCM authenticated and gzip-compressed BLOB.
/// A separate key lives in platform secure storage, never in SQLite or logs.
/// Cache protects metadata, NOT video bytes (stream playback needs internet).
class ChannelCache {
  ChannelCache({FlutterSecureStorage? storage, Database? database})
      : _storage = storage ?? const FlutterSecureStorage(),
        _testDatabase = database;

  final FlutterSecureStorage _storage;
  final Database? _testDatabase;
  Future<Database>? _database;
  Future<SecretKey>? _key;
  Future<void> _writes = Future<void>.value();

  // The playlist parser limits this to 20k; cache preserves all parsed channels.
  static const int maxChannels = 20000;
  static const int maxEncodedBytes = 32 * 1024 * 1024;
  static const String _secretName = 'sanseth_cache_aes256_v2';
  static String _oldKey(String id) => 'sanseth_channels_v1_$id';

  Future<Database> _openDb() async {
    if (_testDatabase != null) {
      return _testDatabase;
    }
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return openDatabase(
      path.join(directory.path, 'sanseth_cache_v2.sqlite'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE channel_snapshots ('
            'playlist_id TEXT PRIMARY KEY, saved_at INTEGER NOT NULL, '
            'channel_count INTEGER NOT NULL, payload BLOB NOT NULL)');
      },
    );
  }

  Future<Database> get _db => _database ??= _openDb();

  Future<SecretKey> _openKey() async {
    var encoded = await _storage.read(key: _secretName);
    if (encoded == null) {
      final random = Random.secure();
      final fresh = List<int>.generate(32, (_) => random.nextInt(256));
      encoded = base64Encode(fresh);
      await _storage.write(key: _secretName, value: encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) {
      throw const FormatException('Cache key invalid');
    }
    return SecretKey(bytes);
  }

  Future<SecretKey> get _secret => _key ??= _openKey();

  Future<List<StreamChannel>> load(String id) async {
    try {
      final db = await _db;
      final rows = await db.query('channel_snapshots',
          columns: ['payload'],
          where: 'playlist_id = ?',
          whereArgs: [id],
          limit: 1);
      if (rows.isNotEmpty) {
        final blob = rows.first['payload'];
        if (blob is! List<int>) {
          return const [];
        }
        if (blob.length > maxEncodedBytes) {
          return const [];
        }
        final encrypted =
            SecretBox.fromConcatenation(blob, nonceLength: 12, macLength: 16);
        final clear = await AesGcm.with256bits()
            .decrypt(encrypted, secretKey: await _secret);
        final json = await compute(_expand, clear);
        return decode(json);
      }
      // Migrate previous small secure snapshot without deleting it first.
      final legacy = await _storage.read(key: _oldKey(id));
      final channels = decode(legacy);
      if (channels.isNotEmpty && await save(id, channels)) {
        await _storage.delete(key: _oldKey(id));
      }
      return channels;
    } catch (_) {
      // Cache corruption/key loss should not stop remote playlist loading.
      return const [];
    }
  }

  Future<bool> save(String id, List<StreamChannel> channels) async {
    if (channels.isEmpty || channels.length > maxChannels) {
      return false;
    }
    final raw = await compute(encode, channels);
    if (utf8.encode(raw).length > maxEncodedBytes) {
      return false;
    }
    final compressed = await compute(_compress, raw);
    if (compressed.length > maxEncodedBytes - 28) {
      return false;
    }
    final box = await AesGcm.with256bits()
        .encrypt(compressed, secretKey: await _secret);
    final blob = box.concatenation();
    // Serialize updates so older snapshots can't overwrite newer data.
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.insert(
            'channel_snapshots',
            {
              'playlist_id': id,
              'saved_at': DateTime.now().millisecondsSinceEpoch,
              'channel_count': channels.length,
              'payload': blob,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
    });
    _writes = operation;
    await operation;
    return true;
  }

  Future<void> remove(String id) async {
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final db = await _db;
      await db.delete('channel_snapshots',
          where: 'playlist_id = ?', whereArgs: [id]);
      await _storage.delete(key: _oldKey(id));
    });
    _writes = operation;
    await operation;
  }

  /// Static codec is deliberately maintained for v1 migration/tests.
  static String encode(List<StreamChannel> channels) => jsonEncode({
        'v': 1,
        'saved': DateTime.now().toUtc().toIso8601String(),
        'items': channels
            .take(maxChannels)
            .map((c) => <String, String?>{
                  'n': c.name,
                  'u': c.url.toString(),
                  'g': c.group,
                  'l': c.logo?.toString(),
                  't': c.tvgId,
                  'ct': c.catchupTemplate,
                  'cd': c.catchupDays?.toString(),
                })
            .toList(growable: false),
      });

  static List<StreamChannel> decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['v'] != 1 || data['items'] is! List) {
        return const [];
      }
      final result = <StreamChannel>[];
      for (final item in (data['items'] as List).take(maxChannels)) {
        if (item is! Map) {
          continue;
        }
        final name = item['n'];
        final url =
            Uri.tryParse(item['u'] is String ? item['u'] as String : '');
        if (name is! String || url == null || !safeChannelUrl(url)) {
          continue;
        }
        final logo =
            Uri.tryParse(item['l'] is String ? item['l'] as String : '');
        result.add(StreamChannel(
            name: name,
            url: url,
            group: item['g'] is String ? item['g'] as String : 'Uncategorized',
            tvgId: item['t'] is String ? item['t'] as String : null,
            catchupTemplate: item['ct'] is String ? item['ct'] as String : null,
            catchupDays:
                int.tryParse(item['cd'] is String ? item['cd'] as String : ''),
            logo: logo != null && safeChannelUrl(logo) ? logo : null));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}

List<int> _compress(String raw) => gzip.encode(utf8.encode(raw));
String _expand(List<int> compressed) => utf8.decode(gzip.decode(compressed));

bool safeChannelUrl(Uri uri) =>
    (uri.isScheme('https') || uri.isScheme('http')) &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;
