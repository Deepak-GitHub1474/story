import 'package:flutter/widgets.dart';

class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.danger,
    required this.success,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentText;
  final Color danger;
  final Color success;

  static const midnight = AppColors(
    bg: Color(0xFF0B0D12),
    surface: Color(0xFF13161D),
    surfaceRaised: Color(0xFF1B1F28),
    border: Color(0xFF262B36),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFFA3AAB8),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFF9B8CFF),
    accentText: Color(0xFF0B0D12),
    danger: Color(0xFFFF8A8A),
    success: Color(0xFF7BD88F),
  );

  static const paper = AppColors(
    bg: Color(0xFFFBFAF7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF3F1EC),
    border: Color(0xFFE2DFD8),
    textPrimary: Color(0xFF1B1A17),
    textSecondary: Color(0xFF57544D),
    textMuted: Color(0xFF8A867D),
    accent: Color(0xFF5B4BD6),
    accentText: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    success: Color(0xFF2E7D45),
  );
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

class AppTypeScale {
  const AppTypeScale._();

  static const double display = 32;
  static const double title = 24;
  static const double heading = 19;
  static const double body = 16;
  static const double reading = 17;
  static const double label = 14;
  static const double caption = 12;
}

class AppSizes {
  const AppSizes._();

  static const double controlHeight = 52;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double maxContentWidth = 560;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Curve easeOut = Curves.easeOutCubic;
}
