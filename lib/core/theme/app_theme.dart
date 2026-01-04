import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryColor = Color(0xFF009688); // Medical Teal Brand Color

  // Brand Colors
  static const Color secondaryColor = Color(0xFF00796B);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E24);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color successColor = Color(0xFF00E676);

  // Fixes the "Invisible Text" bug by defining explicit colors for both modes
  static InputDecorationTheme _inputTheme(Color fillColor, Color textColor) => InputDecorationTheme(
    filled: true,
    fillColor: fillColor,
    hintStyle: TextStyle(color: textColor.withAlpha(128)),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
  );

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F9FA),
    primaryColor: primaryColor,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
    inputDecorationTheme: _inputTheme(Colors.white, Colors.black87),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F9FA), 
      elevation: 0, 
      iconTheme: IconThemeData(color: Colors.black),
      centerTitle: true,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F9FA),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Soft Dark (Better than black)
    primaryColor: primaryColor,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    // Dark mode inputs: Lighter grey fill, White text - fixes invisible text
    inputDecorationTheme: _inputTheme(const Color(0xFF2C2C2C), Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212), 
      elevation: 0, 
      iconTheme: IconThemeData(color: Colors.white),
      centerTitle: true,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(77),
    ),
  );
}
