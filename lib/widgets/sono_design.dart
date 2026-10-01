import 'package:flutter/material.dart';

import '../models/music_models.dart';
import 'immersive_player.dart';

/// Deep-ocean / warm-vinyl mobile design tokens.
///
/// Mirrors the `:root` / `[data-theme=light]` palette in
/// `docs/music-player-mobile.html` and the private `_DesktopPalette` in
/// `macos_player_shell.dart` — keep the values in sync. Colors are mutable
/// statics flipped by [syncWith] so the whole mobile shell re-resolves on a
/// theme toggle (called at the top of `MobilePlayerShell.build`).
class SonoPalette {
  SonoPalette._();

  static Brightness brightness = Brightness.dark;

  static Color bg0 = const Color(0xFF070D12);
  static Color bg1 = const Color(0xFF0B1720);
  static Color bg2 = const Color(0xFF11232C);
  static Color bg3 = const Color(0xFF1B3039);
  static Color bg4 = const Color(0xFF30454D);
  static Color accent = const Color(0xFFAFEAE3);
  static Color accentSoft = const Color(0xFFC4F6EE);
  static Color accent3 = const Color(0xFFDCF9F4);
  static Color textPrimary = const Color(0xFFF3F8F8);
  static Color textMuted = const Color(0xFFB8C9CE);
  static Color textFaint = const Color(0xFF92A7AE);
  static Color textGhost = const Color(0xFF66828B);
  static Color border = const Color(0x0DFFFFFF);
  static Color borderStrong = const Color(0x17FFFFFF);
  static Color red = const Color(0xFFE05555);
  static Color cardPlayInk = const Color(0xFF092326);
  static Color miniBg = const Color(0xF50B1720);
  static Color sheetBg = const Color(0xFF0B1720);

  static bool get isLight => brightness == Brightness.light;

  /// 12% accent tint, used for active chips/nav/row highlights.
  static Color get accentTint => accent.withValues(alpha: 0.12);

  static void syncWith(Brightness value) {
    brightness = value;
    if (value == Brightness.light) {
      bg0 = const Color(0xFFF3EDE1);
      bg1 = const Color(0xFFEDE7DA);
      bg2 = const Color(0xFFE6DFCF);
      bg3 = const Color(0xFFDDD5C4);
      bg4 = const Color(0xFFCEC5B3);
      accent = const Color(0xFFA64927);
      accentSoft = const Color(0xFFB85C39);
      accent3 = const Color(0xFFC57B52);
      textPrimary = const Color(0xFF2C2018);
      textMuted = const Color(0xFF6B5240);
      textFaint = const Color(0xFF826B58);
      textGhost = const Color(0xFFBBA898);
      border = const Color(0x0F2C2018);
      borderStrong = const Color(0x1C2C2018);
      red = const Color(0xFFC94444);
      cardPlayInk = const Color(0xFFFFFFFF);
      miniBg = const Color(0xF5EDE7DA);
      sheetBg = const Color(0xFFEDE7DA);
      return;
    }

    bg0 = const Color(0xFF070D12);
    bg1 = const Color(0xFF0B1720);
    bg2 = const Color(0xFF11232C);
    bg3 = const Color(0xFF1B3039);
    bg4 = const Color(0xFF30454D);
    accent = const Color(0xFFAFEAE3);
    accentSoft = const Color(0xFFC4F6EE);
    accent3 = const Color(0xFFDCF9F4);
    textPrimary = const Color(0xFFF3F8F8);
    textMuted = const Color(0xFFB8C9CE);
    textFaint = const Color(0xFF92A7AE);
    textGhost = const Color(0xFF66828B);
    border = const Color(0x0DFFFFFF);
    borderStrong = const Color(0x17FFFFFF);
    red = const Color(0xFFE05555);
    cardPlayInk = const Color(0xFF092326);
    miniBg = const Color(0xF50B1720);
    sheetBg = const Color(0xFF0B1720);
  }
}

/// Weight-driven typography for the SŌNO mobile shell.
///
/// Matches the desktop shell: no bundled fonts — the serif/mono feel of the
/// HTML is approximated with the system font and weights/letter-spacing.
/// Getters read [SonoPalette], so they re-resolve after [SonoPalette.syncWith].
class SonoText {
  SonoText._();

  static TextStyle get pageTitle => TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w300,
    height: 1.05,
    color: SonoPalette.textPrimary,
  );

  static TextStyle get npTitle => TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w300,
    height: 1.15,
    color: SonoPalette.textPrimary,
  );

  static TextStyle get section => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: SonoPalette.textPrimary,
  );

  static TextStyle get stat => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w300,
    height: 1.0,
    color: SonoPalette.accentSoft,
  );

  static TextStyle get title => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: SonoPalette.textPrimary,
  );

  static TextStyle get body => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SonoPalette.textPrimary,
  );

  static TextStyle get small => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: SonoPalette.textMuted,
  );

  static TextStyle get mono => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.6,
    color: SonoPalette.textMuted,
  );

  static TextStyle get overline => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
    color: SonoPalette.textFaint,
  );
}

/// Shared album art uses embedded covers with the bundled ocean fallback.
class SonoArtwork extends StatelessWidget {
  const SonoArtwork({
    super.key,
    required this.track,
    required this.size,
    this.radius,
    this.showInitials = true,
  });
  final Track track;
  final double size;
  final BorderRadius? radius;
  final bool showInitials;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: radius ?? BorderRadius.circular(size * 0.12),
    child: SizedBox.square(
      dimension: size,
      child: PlayerArtwork(track: track),
    ),
  );
}
