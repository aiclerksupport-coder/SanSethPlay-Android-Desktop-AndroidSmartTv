import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/player/remote_commands.dart';

void main() {
  test('keyboard transport and TV media keys map to the player', () {
    expect(playerRemoteCommandFor(LogicalKeyboardKey.space),
        PlayerRemoteCommand.playPause);
    expect(playerRemoteCommandFor(LogicalKeyboardKey.mediaTrackNext),
        PlayerRemoteCommand.next);
    expect(playerRemoteCommandFor(LogicalKeyboardKey.mediaTrackPrevious),
        PlayerRemoteCommand.previous);
    expect(playerRemoteCommandFor(LogicalKeyboardKey.arrowLeft),
        PlayerRemoteCommand.seekBackward);
    expect(playerRemoteCommandFor(LogicalKeyboardKey.arrowRight),
        PlayerRemoteCommand.seekForward);
  });

  test('unrelated keys are left to normal Flutter focus handling', () {
    expect(playerRemoteCommandFor(LogicalKeyboardKey.keyA), isNull);
    expect(playerRemoteCommandFor(LogicalKeyboardKey.tab), isNull);
    expect(playerRemoteCommandFor(LogicalKeyboardKey.enter), isNull);
  });
}
