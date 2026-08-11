import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({required this.colors});

  final AppColors colors;

  static const midnight = AppTheme(colors: AppColors.midnight);
  static const paper = AppTheme(colors: AppColors.paper);

  @override
  AppTheme copyWith({AppColors? colors}) => AppTheme(colors: colors ?? this.colors);

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppTheme>()!.colors;
}

ThemeData buildTheme(AppColors colors, Brightness brightness) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: colors.bg,
    extensions: [AppTheme(colors: colors)],
    colorScheme: base.colorScheme.copyWith(
      primary: colors.accent,
      onPrimary: colors.accentText,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
      ),
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colors.textPrimary,
        fontSize: AppTypeScale.heading,
        fontWeight: FontWeight.w500,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary),
    ),
  );
}

ThemeData get midnightTheme => buildTheme(AppColors.midnight, Brightness.dark);

ThemeData get paperTheme => buildTheme(AppColors.paper, Brightness.light);
