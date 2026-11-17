import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup and Add Playlist dialog never auto-open keyboard',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SanSethApp());
    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();

    expect(find.text('CHANNELS'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('M3U / GitHub playlist URL'), findsOneWidget);
    await tester.tap(find.text('M3U / GitHub playlist URL'));
    await tester.pump();
    expect(find.text('Add Playlist / Live Stream'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
