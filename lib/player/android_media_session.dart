import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Android MediaSession transport integration. No-op on Windows; TV & phone
/// share the same Dart player controls and native callback channel.
class AndroidMediaSession {
  AndroidMediaSession(this.onCommand);
  final void Function(String command, Object? arguments) onCommand;
  static const MethodChannel _channel =
      MethodChannel('sanseth_play/android_media_session');
  bool _attached = false;

  void attach() {
    if (!Platform.isAndroid || _attached) {
      return;
    }
    _attached = true;
    _channel.setMethodCallHandler((call) async {
      if (_attached) {
        onCommand(call.method, call.arguments);
      }
    });
  }

  Future<void> update(
      {required String title,
      required bool playing,
      required bool live,
      required Duration duration,
      required Duration position}) async {
    if (!_attached) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('update', <String, Object>{
        'title': title,
        'playing': playing,
        'live': live,
        'durationMs': duration.inMilliseconds,
        'positionMs': position.inMilliseconds,
      });
    } on MissingPluginException {
      // Flutter widget tests and apps with older native runners remain usable.
    } on PlatformException {
      // System media controls must never interrupt video playback.
    }
  }

  Future<void> dispose() async {
    if (!_attached) {
      return;
    }
    _attached = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<bool>('deactivate');
    } on PlatformException {
      // Best effort cleanup.
    } on MissingPluginException {
      // Older app runner.
    }
  }
}
