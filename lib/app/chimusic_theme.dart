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

ThemeData buildChiMusicTheme({Brightness brightness = Brightness.dark}) {
  final isDark = brightness == Brightness.dark;
  final scheme = isDark
      ? const ColorScheme.dark(
          primary: LiquidPalette.aqua,
          secondary: LiquidPalette.mint,
          tertiary: LiquidPalette.coral,
          surface: LiquidPalette.surface,
          onPrimary: LiquidPalette.ink,
          onSecondary: LiquidPalette.ink,
          onSurface: LiquidPalette.softWhite,
        )
      : const ColorScheme.light(
          primary: Color(0xFFC07A92),
          secondary: Color(0xFFD3A9B4),
          tertiary: Color(0xFFB8864D),
          surface: Color(0xFFEDE7DA),
          onPrimary: Color(0xFFF8F3EA),
          onSecondary: Color(0xFF2C2018),
          onSurface: Color(0xFF2C2018),
        );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: isDark ? LiquidPalette.softWhite : const Color(0xFF2C2018),
    displayColor: isDark ? LiquidPalette.softWhite : const Color(0xFF2C2018),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0x1A2C2018),
    iconTheme: IconThemeData(
      color: isDark ? LiquidPalette.softWhite : const Color(0xFF2C2018),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: isDark
          ? LiquidPalette.softWhite
          : const Color(0xFF2C2018),
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
        color: (isDark ? LiquidPalette.moon : const Color(0xFF6B5240))
            .withValues(alpha: 0.54),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    sliderTheme: SliderThemeData(
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      activeTrackColor: isDark ? LiquidPalette.aqua : const Color(0xFFC07A92),
      inactiveTrackColor: isDark
          ? const Color(0x33232A36)
          : const Color(0x332C2018),
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
