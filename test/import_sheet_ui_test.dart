import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import choices are visible without keyboard autofocus',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SanSethApp());
    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();
    expect(find.text('CHANNELS'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).last);
    await tester.pump();
    expect(find.text('Import M3U URL'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('M3U / GitHub playlist URL'), findsOneWidget);
    expect(find.text('Direct live stream'), findsWidgets);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
