import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/app/sanseth_app.dart';

void main() {
  testWidgets('SanSeth Play app uses the real root widget', (tester) async {
    await tester.pumpWidget(const SanSethApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
