import 'package:flutter/material.dart';
import 'brand_launch_screen.dart';

class SanSethApp extends StatelessWidget {
  const SanSethApp({super.key});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF4C65B);
    return MaterialApp(
      title: 'SanSeth Play',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080B11),
        colorScheme:
            ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111722),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: const StadiumBorder(),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: const StadiumBorder(),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171D27),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
        ),
      ),
      home: const BrandLaunchScreen(),
    );
  }
}
