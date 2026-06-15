import 'dart:ui';
import 'package:flutter/material.dart';

/// Custom color palette as ThemeExtension for light/dark support.
@immutable
class SwaapColors extends ThemeExtension<SwaapColors> {
  final Color bg;
  final Color surface;
  final Color cardBg;
  final Color cardBlur;
  final Color accent;
  final Color green;
  final Color orange;
  final Color red;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color outerBg;

  const SwaapColors({
    required this.bg, required this.surface, required this.cardBg, required this.cardBlur,
    required this.accent, required this.green, required this.orange, required this.red,
    required this.textPrimary, required this.textSecondary, required this.border, required this.outerBg,
  });

  static const dark = SwaapColors(
    bg: Color(0xFF0F1117), surface: Color(0xFF181A24), cardBg: Color(0xFF1A1D2E),
    cardBlur: Color(0xB31A1D2E),
    accent: Color(0xFF6C8EFF), green: Color(0xFF34D399), orange: Color(0xFFFBBF24),
    red: Color(0xFFEF4444), textPrimary: Color(0xFFEEF0F6), textSecondary: Color(0xFF8B8FA3),
    border: Color(0xFF2A2D3E), outerBg: Color(0xFF08090D),
  );

  static const light = SwaapColors(
    bg: Color(0xFFF2F4F8), surface: Color(0xFFFFFFFF), cardBg: Color(0xFFFFFFFF),
    cardBlur: Color(0xDDFFFFFF),
    accent: Color(0xFF4A6CF7), green: Color(0xFF059669), orange: Color(0xFFD97706),
    red: Color(0xFFDC2626), textPrimary: Color(0xFF111827), textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE2E5EB), outerBg: Color(0xFFDFE3EA),
  );

  /// Shorthand: `final c = SwaapColors.of(context);`
  static SwaapColors of(BuildContext context) => Theme.of(context).extension<SwaapColors>()!;

  LinearGradient get accentGradient => LinearGradient(colors: [accent, accent.withValues(alpha: 0.8)]);
  LinearGradient get greenGradient => LinearGradient(colors: [green, green.withValues(alpha: 0.8)]);

  @override
  SwaapColors copyWith({Color? bg, Color? surface, Color? cardBg, Color? cardBlur,
    Color? accent, Color? green, Color? orange, Color? red,
    Color? textPrimary, Color? textSecondary, Color? border, Color? outerBg}) =>
      SwaapColors(
        bg: bg ?? this.bg, surface: surface ?? this.surface, cardBg: cardBg ?? this.cardBg,
        cardBlur: cardBlur ?? this.cardBlur, accent: accent ?? this.accent, green: green ?? this.green,
        orange: orange ?? this.orange, red: red ?? this.red, textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary, border: border ?? this.border, outerBg: outerBg ?? this.outerBg,
      );

  @override
  SwaapColors lerp(SwaapColors? other, double t) {
    if (other == null) return this;
    return SwaapColors(
      bg: Color.lerp(bg, other.bg, t)!, surface: Color.lerp(surface, other.surface, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!, cardBlur: Color.lerp(cardBlur, other.cardBlur, t)!,
      accent: Color.lerp(accent, other.accent, t)!, green: Color.lerp(green, other.green, t)!,
      orange: Color.lerp(orange, other.orange, t)!, red: Color.lerp(red, other.red, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!, textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!, outerBg: Color.lerp(outerBg, other.outerBg, t)!,
    );
  }
}

// Keep backward compat - old constant references
class AppColors {
  AppColors._();
  static const Color bg = Color(0xFF0F1117);
  static const Color surface = Color(0xFF181A24);
  static const Color cardBg = Color(0xFF1A1D2E);
  static const Color accent = Color(0xFF6C8EFF);
  static const Color green = Color(0xFF34D399);
  static const Color orange = Color(0xFFFBBF24);
  static const Color red = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFEEF0F6);
  static const Color textSecondary = Color(0xFF8B8FA3);
  static const Color border = Color(0xFF2A2D3E);
}
