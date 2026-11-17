import 'package:flutter/widgets.dart';

/// Only phones with an active video enter immersive landscape automatically.
/// Desktop windows and Android TV stay in their normal responsive layouts.
bool shouldUseMobileLandscapePlayer({
  required bool isAndroid,
  required Size size,
  required bool hasChannel,
  bool disabledByUser = false,
}) {
  return isAndroid &&
      hasChannel &&
      !disabledByUser &&
      size.width > size.height &&
      size.shortestSide < 600;
}
