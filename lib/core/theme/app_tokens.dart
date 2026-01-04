import 'package:flutter/material.dart';

class AppColors {
  // ===========================================================================
  // 1. PRIMITIVES (The Raw Palette)
  // ===========================================================================
  static const Color _tealPrimary = Color(0xFF009688); // Brand Color
  static const Color _darkSurface = Color(0xFF121212); // True Black
  static const Color _darkCard = Color(0xFF1E1E24);
  static const Color _lightBackground = Color(0xFFF5F9FA);
  static const Color _white = Colors.white;
  static const Color _black = Colors.black;
  static const Color _greyHint = Color(0xFF9E9E9E);
  static const Color _inputFillDark = Color(0xFF2C2C2C);
  static const Color _inputFillLight = Color(0xFFFFFFFF); // Clean white inputs for light mode

  // ===========================================================================
  // 2. SEMANTIC TOKENS (The "Meaning" of the color)
  // ===========================================================================

  // LIGHT MODE TOKENS
  static const Color lightPrimary = _tealPrimary;
  static const Color lightBackground = _lightBackground;
  static const Color lightSurface = _white;
  static const Color lightInputFill = _inputFillLight;
  static const Color lightTextPrimary = _black;
  static const Color lightTextSecondary = _greyHint;
  static const Color lightIcon = _black;

  // DARK MODE TOKENS
  static const Color darkPrimary = _tealPrimary; // Keeping brand identity
  static const Color darkBackground = _darkSurface;
  static const Color darkSurface = _darkCard;
  static const Color darkInputFill = _inputFillDark;
  static const Color darkTextPrimary = _white;
  static const Color darkTextSecondary = _greyHint;
  static const Color darkIcon = _white;
}

class AppSpacings {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
}
