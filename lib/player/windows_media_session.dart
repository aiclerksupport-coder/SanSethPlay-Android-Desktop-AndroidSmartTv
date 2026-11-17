import 'dart:async';
import 'dart:io' show Platform;

import 'package:smtc_windows/smtc_windows.dart';

/// Windows System Media Transport Controls. Secondary multiview panes must
/// never register here. Native key events only act on the primary player.
class WindowsMediaSession {
  WindowsMediaSession(this.onCommand);

  final void Function(String command, Object? arguments) onCommand;
  SMTCWindows? _session;
  StreamSubscription<PressedButton>? _buttons;
  static Future<void>? _initialization;

  Future<void> attach() async {
    if (!Platform.isWindows || _session != null) {
      return;
    }
    try {
      _initialization ??= SMTCWindows.initialize();
      await _initialization;
      final session = SMTCWindows(
        metadata: const MusicMetadata(title: 'SanSeth Play', artist: 'Live TV'),
      );
      _session = session;
      _buttons = session.buttonPressStream.listen((pressed) {
        switch (pressed) {
          case PressedButton.play:
            onCommand('play', null);
          case PressedButton.pause:
            onCommand('pause', null);
          case PressedButton.next:
            onCommand('next', null);
          case PressedButton.previous:
            onCommand('previous', null);
          case PressedButton.stop:
            onCommand('stop', null);
          default:
            break;
        }
      });
    } catch (_) {
      // If the Windows SMTC bridge is unavailable, continue playback normally.
      _session = null;
    }
  }

  void update({required String title, required bool playing}) {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      unawaited(session
          .updateMetadata(
            MusicMetadata(title: title, artist: 'SanSeth Play'),
          )
          .catchError((Object _) {}));
      unawaited(session
          .setPlaybackStatus(
            playing ? PlaybackStatus.playing : PlaybackStatus.paused,
          )
          .catchError((Object _) {}));
    } catch (_) {
      // Native media controls are best-effort, not a playback prerequisite.
    }
  }

  Future<void> dispose() async {
    await _buttons?.cancel();
    _buttons = null;
    final session = _session;
    _session = null;
    if (session != null) {
      try {
        await session.dispose();
      } catch (_) {}
    }
  }
}
