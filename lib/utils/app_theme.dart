import 'package:flutter/material.dart';

/// پالت برند Jahan Bit / جهان بیت — استخراج‌شده از new_logo_bit و new_logo_bit_2
///
/// از لوگو اصلی: سرمه‌ای عمیق گرادیان (#001028) + آبی میانی (#0A68A4 / #087EC6)
/// از لوگو آیکون: فیروزه‌ای روشن (#2AC4F8) + آبی سلطنتی (#183880)
class AppTheme {
  const AppTheme._();

  /// سرمه‌ای اصلی لوگو (حالت روشن / AppBar)
  static const Color primary = Color(0xFF0B1E3B);

  /// فیروزه‌ای روشن لوگو — اکشن‌ها در دارک‌مود
  static const Color primaryDark = Color(0xFF2AC4F8);

  /// آبی روشن/فیروزه‌ای برند (اکسنت)
  static const Color accent = Color(0xFF38C8F8);

  /// آبی سلطنتی نیمه‌تیره (سطوح ثانویه / secondary)
  static const Color navyMid = Color(0xFF183880);

  /// نقره‌ای متالیک لبه لوگو
  static const Color silver = Color(0xFF8A9098);

  /// پس‌زمینه روشن با ته‌مایه آبی خنک
  static const Color cableWhite = Color(0xFFF0F4F8);

  /// سفید خالص
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// پس‌زمینه دارک — نزدیک به صفحهٔ سیاه لوگو با ته‌نوردهی سرمه‌ای
  static const Color darkScaffold = Color(0xFF08111F);

  /// سطح کارت / هدر در دارک
  static const Color darkSurface = Color(0xFF12233A);

  static const Color primaryTint = Color(0x330B1E3B);
  static const Color primaryTintDark = Color(0x332AC4F8);

  static const Color successSurfaceLight = Color(0xFFE6F4FC);
  static const Color successSurfaceDark = Color(0xFF15324A);
  static const Color successBorderLight = Color(0xFF8EB8D4);
  static const Color successBorderDark = Color(0xFF3A7AA0);
  static const Color successForegroundLight = Color(0xFF0B1E3B);
  static const Color successForegroundDark = Color(0xFFB8DCF0);

  /// رنگ اکشن (دکمه / انتخاب) — در دارک فیروزه‌ای خوانا
  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primary;

  /// رنگ هدر/AppBar — در دارک سطح یکدست، نه فیروزه‌ای روشن
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
      onPrimary: isDark ? primary : pureWhite,
      onSecondary: pureWhite,
      onSurface: isDark ? cableWhite : const Color(0xFF0A1628),
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: isDark ? primary : pureWhite,
      disabledBackgroundColor: silver.withValues(alpha: isDark ? 0.35 : 0.4),
      disabledForegroundColor: (isDark ? primary : pureWhite).withValues(
        alpha: 0.7,
      ),
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
        foregroundColor: isDark ? primary : pureWhite,
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
          color: isDark ? cableWhite : const Color(0xFF0A1628),
        ),
        side: BorderSide(color: silver.withValues(alpha: 0.4)),
      ),
    );
  }
}
