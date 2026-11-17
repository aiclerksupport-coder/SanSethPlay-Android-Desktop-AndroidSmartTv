import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';

/// OS-native splash (Android 12 uses the system icon) transitions to the
/// original, uncropped full brand image on all three supported targets.
class BrandLaunchScreen extends StatefulWidget {
  const BrandLaunchScreen({super.key});
  @override
  State<BrandLaunchScreen> createState() => _BrandLaunchScreenState();
}

class _BrandLaunchScreenState extends State<BrandLaunchScreen> {
  Timer? _timer;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1350), () {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const HomeScreen();
    }
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
          child: Semantics(
        label: 'SanSeth Play',
        child: Image.asset(
          portrait
              ? 'assets/branding/splash_portrait_1080x1920.png'
              : 'assets/branding/splash_landscape_1920x1080.png',
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
        ),
      )),
    );
  }
}
