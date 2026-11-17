import 'dart:io' show Platform, InternetAddress;
import 'package:flutter/services.dart';

/// Google Cast sender bridge: SDK discovery/session only on Android.
/// No credentials or authenticated URLs are transferred automatically.
class AndroidCast {
  const AndroidCast();
  static const MethodChannel _channel =
      MethodChannel('sanseth_play/android_cast');

  static bool isPublicCastUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    // Cast receivers are separate devices. Block private, loopback,
    // link-local and raw IP hosts instead of allowing local-network URLs.
    if (host == 'localhost' ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        InternetAddress.tryParse(host) != null) {
      return false;
    }
    const secretKeys = {
      'username',
      'password',
      'token',
      'auth',
      'key',
      'api_key',
      'signature'
    };
    if (uri.queryParameters.keys
        .any((k) => secretKeys.contains(k.toLowerCase()))) {
      return false;
    }
    return ['.m3u8', '.mp4', '.ts']
        .any((e) => uri.path.toLowerCase().endsWith(e));
  }

  Future<bool> _invoke(String name, [Map<String, Object?>? arguments]) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(name, arguments) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> available() => _invoke('available');
  Future<bool> showPicker() => _invoke('showPicker');
  Future<bool> connected() => _invoke('connected');
  Future<bool> load(Uri uri, String title) async {
    if (!isPublicCastUri(uri)) {
      return false;
    }
    return _invoke('load', {'url': uri.toString(), 'title': title});
  }

  Future<bool> disconnect() => _invoke('disconnect');
}
