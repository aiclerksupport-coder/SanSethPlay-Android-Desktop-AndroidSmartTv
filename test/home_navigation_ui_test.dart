import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(800, 480),
    const Size(1920, 1080),
  ]) {
    testWidgets('playlist and filters are discoverable at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SanSethApp());
      await tester.pump(const Duration(milliseconds: 1450));
      await tester.pump();
      expect(find.text('CHANNELS'), findsOneWidget);
      expect(find.text('Playlists (0)'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
