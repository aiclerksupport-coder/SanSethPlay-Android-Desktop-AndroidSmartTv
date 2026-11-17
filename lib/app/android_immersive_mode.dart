import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android 15+ edge-to-edge may ignore Flutter's older immersive UI mode.
/// Use the platform WindowInsetsController where available, with a fallback.
class AndroidImmersiveMode {
  static const _channel = MethodChannel('sanseth_play/android_immersive');

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final applied =
          await _channel.invokeMethod<bool>('setImmersive', enabled);
      if (applied == true) {
        return;
      }
    } on PlatformException {
      // Compatible with earlier Android runner versions.
    } on MissingPluginException {
      // Compatible with earlier Android runner versions.
    }
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }
}
