import 'package:flutter/material.dart';

/// پالت برند Abar Tawseeh ICT — برگرفته از لوگوی رسمی
/// سرمه‌ای + سفید، با آبی روشن و نقره‌ای/خاکی اطراف
class AppTheme {
  const AppTheme._();

  /// سرمه‌ای اصلی لوگو (حالت روشن)
  static const Color primary = Color(0xFF00183C);

  /// آبی برند برای اکشن‌ها در دارک‌مود
  static const Color primaryDark = Color(0xFF3D8BFF);

  /// آبی الکتریک لوگو (ICT / اکسنت)
  static const Color accent = Color(0xFF006CFC);

  /// سرمه‌ای روشن‌تر (سطوح ثانویه)
  static const Color navyMid = Color(0xFF0A2F6B);

  /// نقره‌ای/خاکی لوگو
  static const Color silver = Color(0xFF84909C);

  /// سفید کابلی متمایل به خاکی/نقره
  static const Color cableWhite = Color(0xFFF3F4F6);

  /// سفید خالص
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// پس‌زمینه دارک — نه خیلی تیره تا لوگو واضح بماند
  static const Color darkScaffold = Color(0xFF243044);

  /// سطح کارت / هدر در دارک
  static const Color darkSurface = Color(0xFF2E3A50);

  static const Color primaryTint = Color(0x3300183C);
  static const Color primaryTintDark = Color(0x333D8BFF);

  static const Color successSurfaceLight = Color(0xFFE8EEF8);
  static const Color successSurfaceDark = Color(0xFF1E2F4A);
  static const Color successBorderLight = Color(0xFF9AAEC8);
  static const Color successBorderDark = Color(0xFF5A7AA8);
  static const Color successForegroundLight = Color(0xFF00183C);
  static const Color successForegroundDark = Color(0xFFB4C8E6);

  /// رنگ اکشن (دکمه / انتخاب) — در دارک آبی خوانا
  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primary;

  /// رنگ هدر/AppBar — در دارک سطح یکدست، نه آبی روشن
  static Color appBarFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : primary;

  static Color tintFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryTintDark : primaryTint;

  static Color onAppBar(Brightness brightness) => pureWhite;

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
    final isDark = brightness == Brightness.dark;
    final primaryColor = primaryFor(brightness);
    final appBarColor = appBarFor(brightness);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primaryColor,
      secondary: isDark ? accent : navyMid,
      tertiary: silver,
      surface: isDark ? darkSurface : pureWhite,
      onPrimary: pureWhite,
      onSecondary: pureWhite,
      onSurface: isDark ? cableWhite : const Color(0xFF0F1B2E),
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: pureWhite,
      disabledBackgroundColor: silver.withValues(alpha: isDark ? 0.35 : 0.4),
      disabledForegroundColor: pureWhite.withValues(alpha: 0.7),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: isDark ? darkScaffold : cableWhite,
      canvasColor: isDark ? darkScaffold : cableWhite,
      cardColor: isDark ? darkSurface : pureWhite,
      dividerColor: isDark
          ? silver.withValues(alpha: 0.28)
          : silver.withValues(alpha: 0.35),
      fontFamily: fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: pureWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: pureWhite),
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: pureWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkScaffold.withValues(alpha: 0.55) : pureWhite,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: silver.withValues(alpha: isDark ? 0.45 : 0.55),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? navyMid : primary,
        contentTextStyle: const TextStyle(color: pureWhite),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : pureWhite,
        selectedItemColor: primaryColor,
        unselectedItemColor: silver,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : pureWhite,
        indicatorColor: tintFor(brightness),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: silver);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primaryColor : silver,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkSurface : pureWhite,
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : pureWhite,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? darkScaffold : cableWhite,
        selectedColor: tintFor(brightness),
        labelStyle: TextStyle(
          color: isDark ? cableWhite : const Color(0xFF0F1B2E),
        ),
        side: BorderSide(color: silver.withValues(alpha: 0.4)),
      ),
    );
  }
}
