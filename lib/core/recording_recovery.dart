import 'dart:io';

/// A recording is visible in the library only after its temporary file is
/// finalized. Crashed recordings stay .part and can be inspected/recovered.
class RecordingRecovery {
  const RecordingRecovery();

  static bool isPartName(String name) =>
      RegExp(r'^SanSeth-(?:HLS-)?[0-9]+\.ts\.part$').hasMatch(name);

  static File temporaryFor(File finalFile) => File('${finalFile.path}.part');

  static Future<File> finalize(File temporary) async {
    final name = temporary.uri.pathSegments.last;
    if (!isPartName(name)) {
      throw ArgumentError('Not an app recording');
    }
    // Never overwrite an already-finalized recording.
    final target = File(temporary.path.substring(0, temporary.path.length - 5));
    if (await target.exists()) {
      throw StateError('Recording already exists');
    }
    final size = await temporary.length();
    if (size < 188 || size % 188 != 0) {
      throw const FormatException('Incomplete TS transport packets');
    }
    return temporary.rename(target.path);
  }

  /// Recover only complete MPEG-TS packets from an interrupted recording.
  /// The caller must explicitly request recovery; no corrupt file is
  /// automatically advertised as a complete recording.
  static Future<File?> recover(File temporary) async {
    if (!isPartName(temporary.uri.pathSegments.last)) {
      return null;
    }
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    final length = await temporary.length();
    final packets = length ~/ 188;
    if (packets == 0) {
      return null;
    }
    // Validate the ENTIRE recoverable portion in bounded chunks. Sampling
    // only the first 4096 TS packets can publish corrupt recordings.
    // Never modify the source before the complete integrity check passes.
    final read = await temporary.open(mode: FileMode.read);
    try {
      const packetSize = 188;
      const packetsPerChunk = 1024;
      var checkedPackets = 0;
      while (checkedPackets < packets) {
        final chunkPackets = packets - checkedPackets > packetsPerChunk
            ? packetsPerChunk
            : packets - checkedPackets;
        final buffer = await read.read(chunkPackets * packetSize);
        if (buffer.length != chunkPackets * packetSize) {
          return null;
        }
        for (var i = 0; i < buffer.length; i += packetSize) {
          if (buffer[i] != 0x47) {
            return null;
          }
        }
        checkedPackets += chunkPackets;
      }
    } finally {
      await read.close();
    }
    final handle = await temporary.open(mode: FileMode.append);
    try {
      await handle.truncate(packets * 188);
    } finally {
      await handle.close();
    }
    return finalize(temporary);
  }
}
