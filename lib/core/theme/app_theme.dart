import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

class AppTheme {
  
  // ===========================================================================
  // SHARED INPUT DECORATION THEME (The Core Fix Control Center)
  // ===========================================================================
  static InputDecorationTheme _inputTheme({
    required Color fillColor,
    required Color textColor,
    required Color primaryColor,
  }) => InputDecorationTheme(
    filled: true,
    fillColor: fillColor,
    // Text Styles
    hintStyle: TextStyle(color: textColor.withAlpha(128)),
    labelStyle: TextStyle(color: textColor.withAlpha(179)), // Visible Label
    floatingLabelStyle: TextStyle(color: primaryColor), // Brand color when focused
    // Icon Colors
    prefixIconColor: textColor.withAlpha(179),
    suffixIconColor: textColor.withAlpha(179),
    // Borders & Spacing
    contentPadding: const EdgeInsets.all(AppSpacings.m),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m), borderSide: BorderSide(color: primaryColor, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m), borderSide: const BorderSide(color: Colors.redAccent)),
  );

  // ===========================================================================
  // 1. LIGHT THEME
  // ===========================================================================
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.lightPrimary,
    
    // Typography
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: AppColors.lightTextPrimary,
      displayColor: AppColors.lightTextPrimary,
    ),

    // Input Fields (Global Fix)
    inputDecorationTheme: _inputTheme(
      fillColor: AppColors.lightInputFill, 
      textColor: AppColors.lightTextPrimary,
      primaryColor: AppColors.lightPrimary,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground, 
      elevation: 0, 
      iconTheme: IconThemeData(color: AppColors.lightIcon),
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.lightTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: AppColors.lightSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.l, vertical: AppSpacings.m),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
    ),

    // Color Scheme (Material 3)
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.lightPrimary,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
    ),
  );

  // ===========================================================================
  // 2. DARK THEME
  // ===========================================================================
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.darkPrimary,

    // Typography
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.darkTextPrimary,
      displayColor: AppColors.darkTextPrimary,
    ),

    // Input Fields (Global Fix)
    inputDecorationTheme: _inputTheme(
      fillColor: AppColors.darkInputFill, 
      textColor: AppColors.darkTextPrimary,
      primaryColor: AppColors.darkPrimary,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground, 
      elevation: 0, 
      iconTheme: IconThemeData(color: AppColors.darkIcon),
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.darkTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.l, vertical: AppSpacings.m),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(77),
    ),

    // Color Scheme (Material 3)
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
    ),
  );
}
