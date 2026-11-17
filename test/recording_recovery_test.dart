import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/recording_recovery.dart';

void main() {
  test('finalize only when TS complete and name app owned', () async {
    final dir = await Directory.systemTemp.createTemp('sanseth_recovery_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/SanSeth-123.ts.part');
    await file.writeAsBytes(List<int>.filled(188, 0)..[0] = 0x47);
    final completed = await RecordingRecovery.finalize(file);
    expect(completed.path.endsWith('.ts'), isTrue);
    expect(await completed.length(), 188);
  });
  test('recover truncates torn tail, never publishes malformed bytes',
      () async {
    final dir = await Directory.systemTemp.createTemp('sanseth_recovery_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/SanSeth-HLS-123.ts.part');
    final packet = List<int>.filled(188, 0);
    packet[0] = 0x47;
    await file.writeAsBytes([...packet, 99]);
    final output = await RecordingRecovery.recover(file);
    expect(output, isNotNull);
    expect(await output!.length(), 188);
  });
  test('rejects late TS corruption without truncating source', () async {
    final dir = await Directory.systemTemp.createTemp('sanseth_late_ts_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/SanSeth-HLS-987.ts.part');
    final packet = List<int>.filled(188, 0)..[0] = 0x47;
    final data = <int>[];
    for (var i = 0; i < 4200; i++) {
      data.addAll(packet);
    }
    // Past the former 4096-packet sample limit.
    data[4199 * 188] = 0;
    data.addAll([0x11, 0x22]);
    await file.writeAsBytes(data);
    final result = await RecordingRecovery.recover(file);
    expect(result, isNull);
    expect(await file.exists(), isTrue);
    expect(await file.length(), data.length);
    expect(await File(file.path.replaceFirst('.part', '')).exists(), isFalse);
  });

  test('rejects non-app paths', () async {
    final dir = await Directory.systemTemp.createTemp('sanseth_recovery_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/private.ts.part');
    await file.writeAsBytes([0x47]);
    expect(await RecordingRecovery.recover(file), isNull);
  });
}
