import 'package:flutter/material.dart';

class LiquidPalette {
  static const Color ink = Color(0xFF050608);
  static const Color background = Color(0xFF07090C);
  static const Color surface = Color(0xFF111318);
  static const Color surfaceRaised = Color(0xFF181B22);
  static const Color surfaceSoft = Color(0xFF232834);
  static const Color deepCyan = Color(0xFF103722);
  static const Color aqua = Color(0xFF1ED760);
  static const Color mint = Color(0xFF7BF2A5);
  static const Color coral = Color(0xFFF4A259);
  static const Color moon = Color(0xFFB9C4D2);
  static const Color softWhite = Color(0xFFF7F9FC);
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
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
      bodySmall: textTheme.bodySmall?.copyWith(height: 1.35),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: LiquidPalette.moon.withValues(alpha: 0.54),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    sliderTheme: const SliderThemeData(
      overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      activeTrackColor: LiquidPalette.aqua,
      inactiveTrackColor: Color(0x33232A36),
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
