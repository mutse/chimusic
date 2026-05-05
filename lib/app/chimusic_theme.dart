import 'package:flutter/material.dart';

class LiquidPalette {
  static const Color ink = Color(0xFF07111E);
  static const Color surface = Color(0xFF0C1726);
  static const Color deepCyan = Color(0xFF0E3A4C);
  static const Color aqua = Color(0xFF4CC9D9);
  static const Color mint = Color(0xFF9FE7D7);
  static const Color coral = Color(0xFFFF8D78);
  static const Color moon = Color(0xFFDCEBFF);
  static const Color softWhite = Color(0xFFF4FBFF);
}

ThemeData buildChiMusicTheme() {
  const scheme = ColorScheme.dark(
    primary: LiquidPalette.aqua,
    secondary: LiquidPalette.mint,
    tertiary: LiquidPalette.coral,
    surface: LiquidPalette.surface,
    onPrimary: LiquidPalette.ink,
    onSecondary: LiquidPalette.ink,
    onSurface: LiquidPalette.softWhite,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: LiquidPalette.softWhite,
    displayColor: LiquidPalette.softWhite,
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: Colors.white.withValues(alpha: 0.08),
    iconTheme: const IconThemeData(color: LiquidPalette.softWhite),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: LiquidPalette.softWhite,
    ),
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.4),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.54),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    sliderTheme: const SliderThemeData(
      overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      trackHeight: 4,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
