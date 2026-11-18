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
        scaffoldBackgroundColor: const Color(0xFF061121),
        colorScheme:
            ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark)
                .copyWith(
                    surface: const Color(0xFF10213A),
                    onSurface: const Color(0xFFF7F8FC),
                    primary: gold,
                    onPrimary: const Color(0xFF121A27)),
        dialogTheme: DialogThemeData(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
          titleTextStyle: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF7F8FC)),
          backgroundColor: const Color(0xFF10213A),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFC9A25C), width: 1.2),
              borderRadius: BorderRadius.circular(30)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF10213A),
          modalBackgroundColor: Color(0xFF10213A),
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Color(0xFFC9A25C)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        ),
        dividerColor: const Color(0xFF355675),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF10213A),
          elevation: 16,
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFC9A25C), width: 1.1),
              borderRadius: BorderRadius.circular(26)),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF11243D),
          elevation: 5,
          shadowColor: const Color(0x550A7CC4),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF315678)),
              borderRadius: BorderRadius.circular(22)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: const StadiumBorder(),
            elevation: 3,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 15),
            shape: const StadiumBorder(),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF162A45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF315678))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF315678))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0xFFF4C65B), width: 1.6)),
        ),
      ),
      home: const BrandLaunchScreen(),
    );
  }
}
