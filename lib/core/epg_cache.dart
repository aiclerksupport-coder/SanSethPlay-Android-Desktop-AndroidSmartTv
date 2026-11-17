import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'epg_repository.dart';

/// One authenticated, encrypted last-known-good XMLTV snapshot per source.
/// A failed refresh never destroys the previous successful snapshot.
class EpgCache {
  EpgCache({FlutterSecureStorage? storage, Database? database})
      : _storage = storage ?? const FlutterSecureStorage(),
        _testDatabase = database;

  final FlutterSecureStorage _storage;
  final Database? _testDatabase;
  Future<Database>? _database;
  Future<SecretKey>? _key;
  Future<void> _writes = Future<void>.value();
  static const _keyName = 'sanseth_epg_aes256_v1';
  static const maxPrograms = 50000;
  static const maxPayloadBytes = 24 * 1024 * 1024;

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
      path.join(directory.path, 'sanseth_epg_v1.sqlite'),
      version: 1,
      onCreate: (db, _) async => db.execute('CREATE TABLE epg_snapshots ('
          'source TEXT PRIMARY KEY, saved_at INTEGER NOT NULL, payload BLOB NOT NULL)'),
    );
  }

  Future<Database> get _db => _database ??= _openDb();

  Future<SecretKey> _openKey() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final random = Random.secure();
      encoded =
          base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
      await _storage.write(key: _keyName, value: encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) {
      throw const FormatException('EPG cache key invalid');
    }
    return SecretKey(bytes);
  }

  Future<SecretKey> get _secret => _key ??= _openKey();

  Future<Map<String, List<EpgProgram>>> load(Uri source) async {
    try {
      final rows = await (await _db).query('epg_snapshots',
          columns: ['payload'],
          where: 'source = ?',
          whereArgs: [source.toString()],
          limit: 1);
      if (rows.isEmpty) {
        return const {};
      }
      final blob = rows.single['payload'];
      if (blob is! List<int> || blob.length > maxPayloadBytes) {
        return const {};
      }
      final box =
          SecretBox.fromConcatenation(blob, nonceLength: 12, macLength: 16);
      final clear =
          await AesGcm.with256bits().decrypt(box, secretKey: await _secret);
      return compute(decodeEpgSnapshot, clear);
    } catch (_) {
      // Lost OS encryption key or damaged DB must not prevent online recovery.
      return const {};
    }
  }

  Future<bool> save(Uri source, Map<String, List<EpgProgram>> programs) async {
    if (programs.isEmpty) {
      return false;
    }
    final clear = await compute(encodeEpgSnapshot, programs);
    if (clear.isEmpty || clear.length > maxPayloadBytes - 28) {
      return false;
    }
    final box =
        await AesGcm.with256bits().encrypt(clear, secretKey: await _secret);
    final blob = box.concatenation();
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.insert(
            'epg_snapshots',
            {
              'source': source.toString(),
              'saved_at': DateTime.now().millisecondsSinceEpoch,
              'payload': blob,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
    });
    _writes = operation;
    await operation;
    return true;
  }
}

/// Isolate-safe snapshot codec, bounded by both count and compressed size.
List<int> encodeEpgSnapshot(Map<String, List<EpgProgram>> programs) {
  var count = 0;
  final entries = <List<Object?>>[];
  for (final group in programs.entries) {
    for (final item in group.value) {
      if (++count > EpgCache.maxPrograms) {
        return const [];
      }
      entries.add([
        group.key,
        item.start.millisecondsSinceEpoch,
        item.stop.millisecondsSinceEpoch,
        item.title,
        item.description
      ]);
    }
  }
  return gzip.encode(utf8.encode(jsonEncode({'v': 1, 'items': entries})));
}

Map<String, List<EpgProgram>> decodeEpgSnapshot(List<int> compressed) {
  if (compressed.isEmpty || compressed.length > EpgCache.maxPayloadBytes) {
    return const {};
  }
  try {
    final decoded = gzip.decode(compressed);
    if (decoded.length > EpgCache.maxPayloadBytes * 4) {
      return const {};
    }
    final value = jsonDecode(utf8.decode(decoded));
    if (value is! Map || value['v'] != 1 || value['items'] is! List) {
      return const {};
    }
    final items = value['items'] as List;
    if (items.length > EpgCache.maxPrograms) {
      return const {};
    }
    final output = <String, List<EpgProgram>>{};
    for (final entry in items) {
      if (entry is! List ||
          entry.length != 5 ||
          entry[0] is! String ||
          entry[1] is! int ||
          entry[2] is! int ||
          entry[3] is! String ||
          entry[4] is! String) {
        continue;
      }
      final start =
          DateTime.fromMillisecondsSinceEpoch(entry[1] as int, isUtc: true);
      final stop =
          DateTime.fromMillisecondsSinceEpoch(entry[2] as int, isUtc: true);
      if (!stop.isAfter(start)) {
        continue;
      }
      final id = entry[0] as String;
      (output[id] ??= []).add(EpgProgram(
          channelId: id,
          start: start,
          stop: stop,
          title: entry[3] as String,
          description: entry[4] as String));
    }
    for (final list in output.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return output;
  } catch (_) {
    return const {};
  }
}
