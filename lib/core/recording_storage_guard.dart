import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Defensive Android preflight; cannot guarantee that storage stays free.
/// Platforms without a verified native bridge return null (unknown) rather
/// than inventing a free-space figure.
class RecordingStorageGuard {
  const RecordingStorageGuard();
  static const MethodChannel _channel = MethodChannel('sanseth_play/storage');
  static const int minimumFreeBytes = 256 * 1024 * 1024;

  Future<int?> availableBytes() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('availableBytes');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> canStart() async {
    final free = await availableBytes();
    return free == null || free >= minimumFreeBytes;
  }
}
