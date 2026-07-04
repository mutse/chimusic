import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/music_models.dart';

/// SŌNO mobile design tokens.
///
/// Mirrors the `:root` / `[data-theme=light]` palette in
/// `docs/music-player-mobile.html` and the private `_DesktopPalette` in
/// `macos_player_shell.dart` — keep the values in sync. Colors are mutable
/// statics flipped by [syncWith] so the whole mobile shell re-resolves on a
/// theme toggle (called at the top of `MobilePlayerShell.build`).
class SonoPalette {
  SonoPalette._();

  static Brightness brightness = Brightness.dark;

  static Color bg0 = const Color(0xFF0A0A0B);
  static Color bg1 = const Color(0xFF111113);
  static Color bg2 = const Color(0xFF181819);
  static Color bg3 = const Color(0xFF222224);
  static Color bg4 = const Color(0xFF2E2E32);
  static Color accent = const Color(0xFFC9A96E);
  static Color accentSoft = const Color(0xFFE8C98A);
  static Color accent3 = const Color(0xFFF5DFA8);
  static Color textPrimary = const Color(0xFFF0EDE8);
  static Color textMuted = const Color(0xFFB8B4AC);
  static Color textFaint = const Color(0xFF787470);
  static Color textGhost = const Color(0xFF4A4845);
  static Color border = const Color(0x0DFFFFFF);
  static Color borderStrong = const Color(0x17FFFFFF);
  static Color red = const Color(0xFFE05555);
  static Color cardPlayInk = const Color(0xFF1A1409);
  static Color miniBg = const Color(0xF5121214);
  static Color sheetBg = const Color(0xFF111113);

  static bool get isLight => brightness == Brightness.light;

  /// 12% accent tint, used for active chips/nav/row highlights.
  static Color get accentTint => accent.withValues(alpha: 0.12);

  static void syncWith(Brightness value) {
    brightness = value;
    if (value == Brightness.light) {
      bg0 = const Color(0xFFF2EDE1);
      bg1 = const Color(0xFFEDE7DA);
      bg2 = const Color(0xFFE6DFCF);
      bg3 = const Color(0xFFDDD5C4);
      bg4 = const Color(0xFFCEC5B3);
      accent = const Color(0xFFC07A92);
      accentSoft = const Color(0xFFD3A9B4);
      accent3 = const Color(0xFFE8C8D0);
      textPrimary = const Color(0xFF2C2018);
      textMuted = const Color(0xFF6B5240);
      textFaint = const Color(0xFF9A8470);
      textGhost = const Color(0xFFBBA898);
      border = const Color(0x0F2C2018);
      borderStrong = const Color(0x1C2C2018);
      red = const Color(0xFFC94444);
      cardPlayInk = const Color(0xFFFFFFFF);
      miniBg = const Color(0xF5EDE7DA);
      sheetBg = const Color(0xFFEDE7DA);
      return;
    }

    bg0 = const Color(0xFF0A0A0B);
    bg1 = const Color(0xFF111113);
    bg2 = const Color(0xFF181819);
    bg3 = const Color(0xFF222224);
    bg4 = const Color(0xFF2E2E32);
    accent = const Color(0xFFC9A96E);
    accentSoft = const Color(0xFFE8C98A);
    accent3 = const Color(0xFFF5DFA8);
    textPrimary = const Color(0xFFF0EDE8);
    textMuted = const Color(0xFFB8B4AC);
    textFaint = const Color(0xFF787470);
    textGhost = const Color(0xFF4A4845);
    border = const Color(0x0DFFFFFF);
    borderStrong = const Color(0x17FFFFFF);
    red = const Color(0xFFE05555);
    cardPlayInk = const Color(0xFF1A1409);
    miniBg = const Color(0xF5121214);
    sheetBg = const Color(0xFF111113);
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

/// Procedurally-rendered album art matching the HTML `drawArt`: a gradient over
/// the track's palette, soft blobs, concentric rings and 1–2 letter initials.
/// When the track has embedded artwork it is layered on top (real art wins).
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
  Widget build(BuildContext context) {
    final br = radius ?? BorderRadius.circular(size * 0.12);
    final hasArtwork = !kIsWeb && (track.artworkUri?.isNotEmpty ?? false);

    return ClipRRect(
      borderRadius: br,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SonoArtPainter(
                palette: track.palette,
                initials: showInitials ? _initials(track.title) : '',
                isLight: SonoPalette.isLight,
              ),
            ),
            if (hasArtwork)
              Image.file(
                File(track.artworkUri!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }

  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);

  final buffer = StringBuffer();
  if (words.length >= 2) {
    buffer.write(_firstRune(words[0]));
    buffer.write(_firstRune(words[1]));
  } else {
    for (final rune in trimmed.runes.take(2)) {
      buffer.writeCharCode(rune);
    }
  }

  final result = buffer.toString().toUpperCase();
  return result.isEmpty ? '?' : result;
}

String _firstRune(String value) =>
    value.runes.isEmpty ? '' : String.fromCharCode(value.runes.first);

class _SonoArtPainter extends CustomPainter {
  const _SonoArtPainter({
    required this.palette,
    required this.initials,
    required this.isLight,
  });

  final List<Color> palette;
  final String initials;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final sz = size.width;
    final colors = palette.isEmpty
        ? const <Color>[Color(0xFF2A2A2D), Color(0xFF1A1A1C), Color(0xFF0E0E10)]
        : palette;
    final c1 = colors.first;
    final c2 = colors.length > 1 ? colors[1] : c1;
    final c3 = colors.length > 2 ? colors[2] : c2;

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[c3, c2, c1],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRect(rect);

    final blob = Paint()..color = Colors.white.withValues(alpha: 0.09);
    for (var i = 0; i < 5; i++) {
      final cx = sz * (0.2 + math.sin(i * 1.5) * 0.6);
      final cy = sz * (0.2 + math.cos(i * 1.2) * 0.6);
      final r = sz * (0.3 + i * 0.07);
      canvas.drawCircle(Offset(cx, cy), r, blob);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, sz * 0.005)
      ..color = c1.withValues(alpha: 0.18);
    for (var r = sz * 0.15; r < sz * 0.9; r += sz * 0.12) {
      canvas.drawCircle(Offset(sz * 0.5, sz * 0.5), r, ring);
    }

    canvas.restore();

    if (initials.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: initials,
          style: TextStyle(
            fontSize: sz * 0.3,
            fontWeight: FontWeight.w300,
            height: 1.0,
            color: isLight ? const Color(0x852C2018) : const Color(0xADFFFFFF),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((sz - painter.width) / 2, (sz - painter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SonoArtPainter oldDelegate) {
    return !listEquals(oldDelegate.palette, palette) ||
        oldDelegate.initials != initials ||
        oldDelegate.isLight != isLight;
  }
}
