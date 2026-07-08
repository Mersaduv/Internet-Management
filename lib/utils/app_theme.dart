import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF2D615A);
  static const Color primaryDark = Color(0xFF3C766F);
  static const Color primaryTint = Color(0x332D615A);

  static const Color successSurfaceLight = Color(0xFFE5EFED);
  static const Color successSurfaceDark = Color(0xFF173732);
  static const Color successBorderLight = Color(0xFF9CBDB7);
  static const Color successBorderDark = Color(0xFF5A938A);
  static const Color successForegroundLight = Color(0xFF2D615A);
  static const Color successForegroundDark = Color(0xFFA9D0C9);

  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primary;

  static Color successSurfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? successSurfaceDark : successSurfaceLight;

  static Color successBorderFor(Brightness brightness) =>
      brightness == Brightness.dark ? successBorderDark : successBorderLight;

  static Color successForegroundFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? successForegroundDark
      : successForegroundLight;

  static ThemeData buildTheme({
    required Brightness brightness,
    String? fontFamily,
    TextTheme? textTheme,
  }) {
    final primaryColor = primaryFor(brightness);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    ).copyWith(primary: primaryColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0E1715)
          : const Color(0xFFF4F8F7),
      fontFamily: fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
      ),
    );
  }
}
