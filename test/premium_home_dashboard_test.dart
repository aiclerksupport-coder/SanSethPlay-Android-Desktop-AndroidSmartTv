import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[const Size(320, 568), const Size(360, 640)]) {
    testWidgets('pinned player and dedicated channel browser at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SanSethApp());
      await tester.pump(const Duration(milliseconds: 1450));
      await tester.pump();

      expect(find.byKey(const ValueKey('pinned-player-zone')), findsOneWidget);
      expect(find.text('YOUR ENTERTAINMENT'), findsOneWidget);
      expect(find.text('CHANNELS'), findsOneWidget);
      expect(find.text('Playlists (0)'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.live_tv_outlined).last);
      await tester.pump();
      expect(find.byKey(const ValueKey('pinned-player-zone')), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(
          find.text('Active Playlist: No playlist selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
