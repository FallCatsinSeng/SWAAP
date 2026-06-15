import 'package:flutter/material.dart';

/// App-wide color constants for SWAAP dark theme.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0F1117);
  static const Color surface = Color(0xFF181A24);
  static const Color cardBg = Color(0xFF1A1D2E);
  static const Color accent = Color(0xFF6C8EFF);
  static const Color accentSoft = Color(0xFF4A6CF7);
  static const Color green = Color(0xFF34D399);
  static const Color orange = Color(0xFFFBBF24);
  static const Color red = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFEEF0F6);
  static const Color textSecondary = Color(0xFF8B8FA3);
  static const Color border = Color(0xFF2A2D3E);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2A5E), Color(0xFF0F1117)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6C8EFF), Color(0xFF4A6CF7)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );
}
