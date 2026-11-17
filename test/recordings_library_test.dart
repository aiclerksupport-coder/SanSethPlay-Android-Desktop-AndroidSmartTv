import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/recordings_library.dart';

void main() {
  test('Only app-owned recording filenames are recognized', () {
    expect(RecordingsLibrary.isRecordingName('SanSeth-123.ts'), isTrue);
    expect(RecordingsLibrary.isRecordingName('SanSeth-HLS-987.ts'), isTrue);
    expect(RecordingsLibrary.isRecordingName('../SanSeth-123.ts'), isFalse);
    expect(RecordingsLibrary.isRecordingName('other.ts'), isFalse);
  });

  test('Lists own recordings and refuses to delete unrelated paths', () async {
    final directory = await Directory.systemTemp.createTemp('sanseth-rec-test');
    try {
      final own = File('${directory.path}/SanSeth-123.ts');
      await own.writeAsBytes([0x47, 0, 0]);
      await File('${directory.path}/unrelated.ts').writeAsBytes([1]);
      final library = const RecordingsLibrary();
      final list = await library.list(directory: directory);
      expect(list.length, 1);
      expect(list.single.name, 'SanSeth-123.ts');
      final other = Directory('${directory.path}/sub');
      await other.create();
      final foreign = File('${other.path}/SanSeth-456.ts');
      await foreign.writeAsBytes([1]);
      expect(
          await library.delete(
              RecordedVideo(file: foreign, bytes: 1, modified: DateTime.now()),
              directory: directory),
          isFalse);
      expect(await library.delete(list.single, directory: directory), isTrue);
      expect(await own.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
