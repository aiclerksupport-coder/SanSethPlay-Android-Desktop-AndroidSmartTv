import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/app/brand_launch_screen.dart';

void main() {
  testWidgets('approved lockup displays without cropping on launch',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandLaunchScreen()));
    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.fit, BoxFit.contain);
  });
}
