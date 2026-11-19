import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[const Size(320, 568), const Size(360, 640)]) {
    testWidgets('fixed player, scrollable browser and quick tune at $size',
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
      await tester.tap(find.byIcon(Icons.live_tv_outlined).last);
      await tester.pump();
      expect(find.byKey(const ValueKey('pinned-player-zone')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-channel-workspace')),
          findsOneWidget);
      expect(find.byType(CustomScrollView), findsWidgets);
      expect(
          find.text('Active Playlist: No playlist selected'), findsOneWidget);
      expect(find.text('Add a playlist'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
