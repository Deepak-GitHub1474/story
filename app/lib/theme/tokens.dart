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
    required this.accentStrong,
    required this.accentText,
    required this.danger,
    required this.success,
    this.like = const Color(0xFFED4956),
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentText;
  final Color danger;
  final Color success;
  final Color like;

  static const midnight = AppColors(
    bg: Color(0xFF0B0D12),
    surface: Color(0xFF13161D),
    surfaceRaised: Color(0xFF1B1F28),
    border: Color(0xFF1F242D),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFFA3AAB8),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFF9B8CFF),
    accentStrong: Color(0xFF9B8CFF),
    accentText: Color(0xFF0B0D12),
    danger: Color(0xFFFF8A8A),
    success: Color(0xFF7BD88F),
    like: Color(0xFFFF5C7A),
  );

  static const paper = AppColors(
    bg: Color(0xFFF7F8F3),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEFF0EA),
    border: Color(0xFFEAEBE5),
    textPrimary: Color(0xFF16161A),
    textSecondary: Color(0xFF4A4A55),
    textMuted: Color(0xFF6E6E7A),
    accent: Color(0xFF6850FF),
    accentStrong: Color(0xFF6850FF),
    accentText: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    success: Color(0xFF2E7D45),
    like: Color(0xFFE23A57),
  );

  static const blush = AppColors(
    bg: Color(0xFFFFF5F7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFE9EE),
    border: Color(0xFFF6DDE4),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5B4A50),
    textMuted: Color(0xFF8C8C8C),
    accent: Color(0xFFD6416F),
    accentStrong: Color(0xFFFF6FA3),
    accentText: Color(0xFF2A0F1A),
    danger: Color(0xFFB3261E),
    success: Color(0xFF2E7D45),
    like: Color(0xFFD6416F),
  );

  static const maroon = AppColors(
    bg: Color(0xFF1A1114),
    surface: Color(0xFF241820),
    surfaceRaised: Color(0xFF2F2029),
    border: Color(0xFF3A2831),
    textPrimary: Color(0xFFF3F0EF),
    textSecondary: Color(0xFFC9BEC3),
    textMuted: Color(0xFFA3B0A4),
    accent: Color(0xFFD06A87),
    accentStrong: Color(0xFF85223E),
    accentText: Color(0xFFF1E2E5),
    danger: Color(0xFFFF8A8A),
    success: Color(0xFF7BD88F),
    like: Color(0xFFE0708D),
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

  static const double title = 24;
  static const double heading = 20;
  static const double body = 16;
  static const double reading = 16;
  static const double label = 14;
  static const double caption = 12;
  static const double micro = 10;
}

class AppInk {
  const AppInk._();

  static const Color like = Color(0xFFED4956);
}

class AppSizes {
  const AppSizes._();

  static const double controlHeight = 52;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconNav = 26;
  static const double iconAction = 26;
  static const double hairline = 0.6;
  static const double maxContentWidth = 560;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Curve easeOut = Curves.easeOutCubic;
}
