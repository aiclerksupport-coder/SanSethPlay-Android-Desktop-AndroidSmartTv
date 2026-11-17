import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'recording_recovery.dart';

/// App-owned recordings only; never traverse user-supplied filesystem paths.
class RecordedVideo {
  const RecordedVideo(
      {required this.file, required this.bytes, required this.modified});
  final File file;
  final int bytes;
  final DateTime modified;
  String get name => file.uri.pathSegments.last;
}

class RecordingsLibrary {
  const RecordingsLibrary();

  Future<Directory> _directory() => getApplicationDocumentsDirectory();

  static bool isRecordingName(String name) =>
      RegExp(r'^SanSeth-(?:HLS-)?[0-9]+\.ts$').hasMatch(name);

  Future<List<RecordedVideo>> list({Directory? directory}) async {
    final folder = directory ?? await _directory();
    if (!await folder.exists()) {
      return const [];
    }
    final recordings = <RecordedVideo>[];
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File || !isRecordingName(entity.uri.pathSegments.last)) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (stat.type != FileSystemEntityType.file) {
          continue;
        }
        recordings.add(RecordedVideo(
            file: entity, bytes: stat.size, modified: stat.modified));
      } on FileSystemException {
        // File may have been removed by another operation.
      }
    }
    recordings.sort((a, b) => b.modified.compareTo(a.modified));
    return recordings;
  }

  Future<List<File>> interrupted({Directory? directory}) async {
    final folder = directory ?? await _directory();
    if (!await folder.exists()) {
      return const [];
    }
    final result = <File>[];
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is File &&
          RecordingRecovery.isPartName(entity.uri.pathSegments.last)) {
        result.add(entity);
      }
    }
    return result;
  }

  Future<File?> recover(File part, {Directory? directory}) async {
    final folder = directory ?? await _directory();
    if (part.parent.absolute.path != folder.absolute.path) {
      return null;
    }
    try {
      return await RecordingRecovery.recover(part);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on StateError {
      return null;
    }
  }

  /// Delete only a file discovered in our own recordings directory.
  Future<bool> delete(RecordedVideo video, {Directory? directory}) async {
    final folder = directory ?? await _directory();
    final expected = Directory(folder.absolute.path).path;
    if (!isRecordingName(video.name) ||
        video.file.parent.absolute.path != expected) {
      return false;
    }
    try {
      if (await FileSystemEntity.type(video.file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return false;
      }
      await video.file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
