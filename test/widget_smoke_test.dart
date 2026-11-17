import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  testWidgets('small mobile layout does not overflow at startup',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SanSethApp());
    // Allow the 1350 ms branded splash to transition to HomeScreen.
    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();
    expect(find.text('CHANNELS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout shows no initial error', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SanSethApp());
    // Allow the 1350 ms branded splash to transition to HomeScreen.
    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();
    expect(find.text('CHANNELS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
