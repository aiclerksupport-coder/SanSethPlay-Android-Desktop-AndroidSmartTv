import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/app/tv_guide_dialog.dart';
import 'package:sanseth_play/core/channel.dart';
import 'package:sanseth_play/core/epg_repository.dart';

void main() {
  testWidgets('EPG renders channel rows without overflow in mobile layout',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime.now().toUtc();
    final channel = StreamChannel(
      name: 'Example TV',
      url: Uri.parse('https://example.org/live.m3u8'),
      tvgId: 'example.tv',
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TvGuideDialog(
      channels: [channel],
      programs: {
        'example.tv': [
          EpgProgram(
              channelId: 'example.tv',
              title: 'Current News',
              start: now.subtract(const Duration(minutes: 5)),
              stop: now.add(const Duration(minutes: 55)))
        ],
      },
      onPlay: (_) {},
    ))));
    await tester.pump();
    expect(find.text('Example TV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
