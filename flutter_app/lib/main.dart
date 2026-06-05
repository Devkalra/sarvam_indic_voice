// ============================================================================
//  main.dart — App entry point
//  Sets up the app theme and mounts the root widget.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

void main() {
  runApp(const IndicVoiceFoodApp());
}

class IndicVoiceFoodApp extends StatelessWidget {
  const IndicVoiceFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sarvam Indic Voice Food',
      debugShowCheckedModeBanner: false,

      // ── Global Theme ──────────────────────────────────────────────────────
      // Deep food-delivery orange/red palette with dark backgrounds.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),    // deep orange — food energy
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFFF6D3F),      // warm orange
          secondary: const Color(0xFFFFBE0B),    // saffron yellow accent
          surface: const Color(0xFF1C1C1E),      // near-black card bg
          background: const Color(0xFF121212),   // pure dark bg
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),

        // Poppins — clean, modern, reads well in English & Devanagari
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1C1C1E),
          elevation: 0,
          titleTextStyle: GoogleFonts.baloo2(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFF6D3F),
          ),
        ),
      ),

      home: const HomeScreen(),
    );
  }
}
