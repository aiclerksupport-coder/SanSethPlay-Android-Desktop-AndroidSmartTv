import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('five workspaces share one pinned player', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SanSethApp());
    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();

    final player = find.byKey(const ValueKey('pinned-player-zone'));
    expect(player, findsOneWidget);
    expect(find.text('YOUR ENTERTAINMENT'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.live_tv_outlined).last);
    await tester.pump();
    expect(player, findsOneWidget);
    expect(find.text('CHANNELS'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined).last);
    await tester.pump();
    expect(player, findsOneWidget);
    expect(find.text('TV GUIDE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.video_library_outlined).last);
    await tester.pump();
    expect(player, findsOneWidget);
    expect(find.text('MY LIBRARY'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).last);
    await tester.pump();
    expect(player, findsOneWidget);
    expect(find.text('ADD CONTENT'), findsOneWidget);
    expect(find.text('Import M3U URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
