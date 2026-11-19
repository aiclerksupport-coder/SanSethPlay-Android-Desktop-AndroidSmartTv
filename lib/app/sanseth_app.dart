import 'package:flutter/material.dart';
import 'brand_launch_screen.dart';

class SanSethApp extends StatelessWidget {
  const SanSethApp({super.key});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF5C75C);
    return MaterialApp(
      title: 'SanSeth Play',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF041225),
        colorScheme:
            ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark)
                .copyWith(
                    surface: const Color(0xFF102640),
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
          backgroundColor: const Color(0xFF102640),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFC9A25C), width: 1.2),
              borderRadius: BorderRadius.circular(30)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF102640),
          modalBackgroundColor: Color(0xFF102640),
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Color(0xFFC9A25C)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        ),
        dividerColor: const Color(0xFF476689),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF102640),
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
          color: const Color(0xFF102A45),
          elevation: 5,
          shadowColor: const Color(0x440F315A),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF44648D)),
              borderRadius: BorderRadius.circular(22)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF081A2E),
          indicatorColor: const Color(0x55F5C75C),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFFF5C75C)
                  : const Color(0xFFDBE5F3))),
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontWeight: FontWeight.w600, color: Color(0xFFEDF2FC))),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF102640),
          selectedColor: const Color(0xFFF5C75C),
          side: const BorderSide(color: Color(0xFF476689)),
          labelStyle: const TextStyle(fontSize: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
          fillColor: const Color(0xFF193450),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF44648D))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF44648D))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0xFFF5C75C), width: 1.6)),
        ),
      ),
      home: const BrandLaunchScreen(),
    );
  }
}
