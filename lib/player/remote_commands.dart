import 'package:flutter/services.dart';

/// Small, deterministic mapping. Only handles keys while the player has focus;
/// TextFields and system-level media/volume services remain platform-owned.
enum PlayerRemoteCommand {
  playPause,
  next,
  previous,
  seekForward,
  seekBackward,
  mute,
  volumeUp,
  volumeDown,
}

PlayerRemoteCommand? playerRemoteCommandFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause) {
    return PlayerRemoteCommand.playPause;
  }
  if (key == LogicalKeyboardKey.mediaTrackNext) {
    return PlayerRemoteCommand.next;
  }
  if (key == LogicalKeyboardKey.mediaTrackPrevious) {
    return PlayerRemoteCommand.previous;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return PlayerRemoteCommand.seekForward;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return PlayerRemoteCommand.seekBackward;
  }
  if (key == LogicalKeyboardKey.audioVolumeMute) {
    return PlayerRemoteCommand.mute;
  }
  if (key == LogicalKeyboardKey.audioVolumeUp) {
    return PlayerRemoteCommand.volumeUp;
  }
  if (key == LogicalKeyboardKey.audioVolumeDown) {
    return PlayerRemoteCommand.volumeDown;
  }
  return null;
}
