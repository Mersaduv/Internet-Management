import 'package:flutter/material.dart';

/// پالت برند Jahan Bit — دارک‌مود Cosmic از طرح‌های مرجع (theme1 / theme2)
///
/// پس‌زمینه عمیق سرمه‌ای-مشکی، کارت با گرادیان و rim-light آبی،
/// متن سفید / خاکستری‌آبی، اکسنت glow آبی، CTA پاستلی یاسی.
class AppTheme {
  const AppTheme._();

  // ─── Brand (light + shared) ─────────────────────────────────────────
  /// سرمه‌ای اصلی لوگو (حالت روشن / اکشن روشن)
  static const Color primary = Color(0xFF0B1E3B);

  /// فیروزه‌ای برند — اکسنت ثانویه
  static const Color accent = Color(0xFF38C8F8);

  /// آبی سلطنتی نیمه‌تیره
  static const Color navyMid = Color(0xFF183880);

  /// نقره‌ای متالیک
  static const Color silver = Color(0xFF8A9098);

  /// پس‌زمینه روشن
  static const Color cableWhite = Color(0xFFF0F4F8);

  static const Color pureWhite = Color(0xFFFFFFFF);

  // ─── Cosmic dark (from reference mockups) ───────────────────────────
  /// پس‌زمینه اصلی دارک — #050A18
  static const Color darkScaffold = Color(0xFF050A18);

  /// عمق پس‌زمینه / لبه پایین — #02061A
  static const Color darkScaffoldDeep = Color(0xFF02061A);

  /// سطح کارت / شیت — #0A1628
  static const Color darkSurface = Color(0xFF0A1628);

  /// سطح کارت بالاتر — شروع گرادیان #0D2547
  static const Color darkCardTop = Color(0xFF0D2547);

  /// پایان گرادیان کارت — #071328
  static const Color darkCardBottom = Color(0xFF071328);

  /// نوار پایین — #0A0F1E
  static const Color darkNavBar = Color(0xFF0A0F1E);

  /// متن ثانویه دارک — #A0AEC0
  static const Color darkTextSecondary = Color(0xFFA0AEC0);

  /// glow آبی الکتریک — #3B82F6
  static const Color darkGlow = Color(0xFF3B82F6);

  /// آبی عمیق glow مرکزی — #1D4ED8
  static const Color darkGlowDeep = Color(0xFF1D4ED8);

  /// اکشن فیروزه‌ای خوانا در دارک (آیکون / انتخاب)
  static const Color primaryDark = Color(0xFF5EB8FF);

  /// دکمه عملیاتی دارک — آبی‌سرمه‌ای ملایم (نه پاستل روشن)
  static const Color darkAction = Color(0xFF1E4A6E);

  /// متن روی دکمه عملیاتی دارک
  static const Color darkActionForeground = Color(0xFFE8F4FF);

  /// نارنجی دارک — قفل اتصال (حالت غیرفعال قفل)
  static const Color darkOrange = Color(0xFFC2410C);

  /// نارنجی عمیق‌تر برای فشار/فعال
  static const Color darkOrangeDeep = Color(0xFF9A3412);

  /// CTA پاستلی یاسی — فقط برای هایلایت‌های نادر (نه دکمه‌های اصلی)
  static const Color darkCta = Color(0xFFE9D5FF);

  /// متن روی CTA — #1E1B4B
  static const Color darkCtaForeground = Color(0xFF1E1B4B);

  /// rim-light آبی کم‌عمق روی کارت
  static const Color darkRim = Color(0xFF4A6FA5);

  /// لبه کارت روشن
  static const Color lightRim = Color(0xFFB8C5D6);

  /// سطح کارت روشن (ته‌مایه آبی خنک)
  static const Color lightCard = Color(0xFFFFFFFF);

  /// سطح کارت روشن ثانویه
  static const Color lightCardSoft = Color(0xFFF5F8FC);

  static const Color primaryTint = Color(0x330B1E3B);
  static const Color primaryTintDark = Color(0x333B82F6);

  static const Color successSurfaceLight = Color(0xFFE6F4FC);
  static const Color successSurfaceDark = Color(0xFF0F2744);
  static const Color successBorderLight = Color(0xFF8EB8D4);
  static const Color successBorderDark = Color(0xFF3A6A9A);
  static const Color successForegroundLight = Color(0xFF0B1E3B);
  static const Color successForegroundDark = Color(0xFFB8DCF0);

  /// شعاع کارت‌های مرجع (~24)
  static const double radiusCard = 24;
  static const double radiusMd = 16;
  static const double radiusSm = 12;

  /// رنگ اکشن (دکمه / انتخاب)
  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primary;

  /// پس‌زمینه دکمه عملیاتی (ذخیره / سرعت / …) — در دارک ملایم و یکدست
  static Color actionFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAction : primary;

  static Color onActionFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkActionForeground : pureWhite;

  /// هدر/AppBar — در دارک هم‌رنگ scaffold (بدون نوار تخت قدیمی)
  static Color appBarFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkScaffold : primary;

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

  /// گرادیان پس‌زمینه cosmic (دارک)
  static LinearGradient cosmicScaffoldGradient() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A1228),
      darkScaffold,
      darkScaffoldDeep,
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// گرادیان پس‌زمینه روشن مدرن
  static LinearGradient lightScaffoldGradient() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8EEF6),
      cableWhite,
      Color(0xFFF7FAFD),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// گرادیان سطح کارت دارک
  static LinearGradient cosmicCardGradient() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkCardTop, darkCardBottom],
  );

  /// گرادیان کارت روشن
  static LinearGradient lightCardGradient() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightCard, lightCardSoft],
  );

  /// بوردر نازک rim-light
  static BorderSide cosmicRim({double alpha = 0.28}) => BorderSide(
    color: darkRim.withValues(alpha: alpha),
    width: 1,
  );

  static BorderSide lightRimSide({double alpha = 0.65}) => BorderSide(
    color: lightRim.withValues(alpha: alpha),
    width: 1,
  );

  /// دکوراسیون کارت — دارک یا روشن
  static BoxDecoration cosmicCardDecoration({
    double radius = radiusCard,
    bool withGlow = false,
    Brightness brightness = Brightness.dark,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark ? cosmicCardGradient() : lightCardGradient(),
      borderRadius: BorderRadius.circular(radius),
      border: Border.fromBorderSide(
        isDark ? cosmicRim() : lightRimSide(),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? (withGlow
                    ? darkGlow.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.35))
              : primary.withValues(alpha: withGlow ? 0.10 : 0.06),
          blurRadius: isDark ? 18 : 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static ThemeData buildTheme({
    required Brightness brightness,
    String? fontFamily,
    TextTheme? textTheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = primaryFor(brightness);
    final appBarColor = appBarFor(brightness);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: isDark ? darkGlow : primary,
      brightness: brightness,
      primary: primaryColor,
      secondary: isDark ? accent : navyMid,
      tertiary: isDark ? darkCta : silver,
      surface: isDark ? darkSurface : pureWhite,
      surfaceContainerHighest: isDark ? darkScaffold : cableWhite,
      onPrimary: isDark ? darkScaffold : pureWhite,
      onSecondary: pureWhite,
      onSurface: isDark ? pureWhite : const Color(0xFF0A1628),
      onSurfaceVariant: isDark ? darkTextSecondary : silver,
      outline: isDark ? darkRim : silver,
      outlineVariant: isDark
          ? darkRim.withValues(alpha: 0.45)
          : silver.withValues(alpha: 0.5),
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: isDark ? darkAction : primaryColor,
      foregroundColor: isDark ? darkActionForeground : pureWhite,
      disabledBackgroundColor: silver.withValues(alpha: isDark ? 0.28 : 0.4),
      disabledForegroundColor: (isDark ? darkActionForeground : pureWhite)
          .withValues(alpha: 0.55),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
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
          ? darkRim.withValues(alpha: 0.35)
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
        backgroundColor: isDark ? darkAction : primaryColor,
        foregroundColor: isDark ? darkActionForeground : pureWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? darkActionForeground : primaryColor,
          side: BorderSide(color: isDark ? darkAction : primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCardBottom.withValues(alpha: 0.85) : pureWhite,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(
            color: isDark ? darkGlow : primaryColor,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(
            color: isDark
                ? darkRim.withValues(alpha: 0.55)
                : silver.withValues(alpha: 0.55),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? darkGlow : primaryColor,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? darkCardTop : primary,
        contentTextStyle: const TextStyle(color: pureWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkNavBar : pureWhite,
        selectedItemColor: isDark ? pureWhite : primaryColor,
        unselectedItemColor: isDark ? darkTextSecondary : silver,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkNavBar : pureWhite,
        indicatorColor: tintFor(brightness),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? pureWhite : primaryColor,
            );
          }
          return IconThemeData(
            color: isDark ? darkTextSecondary : silver,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? (isDark ? pureWhite : primaryColor)
                : (isDark ? darkTextSecondary : silver),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkSurface : pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? darkSurface : pureWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: isDark
              ? cosmicRim(alpha: 0.22)
              : BorderSide.none,
        ),
        elevation: isDark ? 0 : 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? darkCardBottom : cableWhite,
        selectedColor: isDark ? pureWhite : tintFor(brightness),
        labelStyle: TextStyle(
          color: isDark ? pureWhite : const Color(0xFF0A1628),
        ),
        side: BorderSide(
          color: isDark
              ? darkRim.withValues(alpha: 0.4)
              : silver.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? darkTextSecondary : primary,
        textColor: isDark ? pureWhite : const Color(0xFF0A1628),
      ),
    );
  }
}
