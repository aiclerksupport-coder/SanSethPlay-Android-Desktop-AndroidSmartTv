import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/app/mobile_landscape_policy.dart';

void main() {
  test('active Android phone in landscape uses immersive player', () {
    expect(
        shouldUseMobileLandscapePlayer(
          isAndroid: true,
          size: const Size(800, 360),
          hasChannel: true,
        ),
        isTrue);
  });
  test('portrait, no channel and explicit exit keep normal navigation', () {
    for (final size in [const Size(360, 800), const Size(800, 360)]) {
      expect(
          shouldUseMobileLandscapePlayer(
            isAndroid: true,
            size: size,
            hasChannel: false,
          ),
          isFalse);
    }
    expect(
        shouldUseMobileLandscapePlayer(
          isAndroid: true,
          size: const Size(360, 800),
          hasChannel: true,
        ),
        isFalse);
    expect(
        shouldUseMobileLandscapePlayer(
          isAndroid: true,
          size: const Size(800, 360),
          hasChannel: true,
          disabledByUser: true,
        ),
        isFalse);
  });
  test('desktop and wide Android TV never use phone immersive policy', () {
    expect(
        shouldUseMobileLandscapePlayer(
          isAndroid: false,
          size: const Size(900, 400),
          hasChannel: true,
        ),
        isFalse);
    expect(
        shouldUseMobileLandscapePlayer(
          isAndroid: true,
          size: const Size(1920, 1080),
          hasChannel: true,
        ),
        isFalse);
  });
}
