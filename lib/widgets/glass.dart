import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';

bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1100;

bool isWideWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 820;

EdgeInsets pagePadding(BuildContext context, {double bottom = 180}) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width >= 1200
      ? 36.0
      : width >= 800
      ? 28.0
      : 20.0;

  return EdgeInsets.fromLTRB(horizontal, 24, horizontal, bottom);
}

class LiquidBackdrop extends StatelessWidget {
  const LiquidBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LiquidPalette.background,
            Color(0xFF0B0D12),
            LiquidPalette.ink,
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -100,
            left: -40,
            child: _BlurOrb(
              size: 320,
              colors: [Color(0x661ED760), Color(0x001ED760)],
            ),
          ),
          const Positioned(
            top: 160,
            right: -110,
            child: _BlurOrb(
              size: 380,
              colors: [Color(0x44F4A259), Color(0x00103222)],
            ),
          ),
          const Positioned(
            bottom: -140,
            left: 120,
            child: _BlurOrb(
              size: 420,
              colors: [Color(0x332D7EFF), Color(0x00181B22)],
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius,
    this.onTap,
    this.tintColors,
    this.borderColor,
    this.blur = 24,
    this.withShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final List<Color>? tintColors;
  final Color? borderColor;
  final double blur;
  final bool withShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(30);
    final content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.08),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  tintColors ??
                  [
                    LiquidPalette.surfaceRaised.withValues(alpha: 0.94),
                    LiquidPalette.surface.withValues(alpha: 0.92),
                  ],
            ),
            boxShadow: withShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ]
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.02),
        child: content,
      ),
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(999),
      tintColors: selected
          ? [
              LiquidPalette.aqua.withValues(alpha: 0.28),
              LiquidPalette.deepCyan.withValues(alpha: 0.94),
            ]
          : [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.78),
              LiquidPalette.surface.withValues(alpha: 0.88),
            ],
      borderColor: selected
          ? LiquidPalette.mint.withValues(alpha: 0.42)
          : Colors.white.withValues(alpha: 0.06),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...?leading == null ? null : [leading!, const SizedBox(width: 8)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? LiquidPalette.softWhite
                  : Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.size = 46,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GlassPanel(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(size / 2),
        tintColors: selected
            ? [
                LiquidPalette.aqua.withValues(alpha: 0.92),
                LiquidPalette.mint.withValues(alpha: 0.74),
              ]
            : [
                LiquidPalette.surfaceSoft.withValues(alpha: 0.82),
                LiquidPalette.surface.withValues(alpha: 0.92),
              ],
        child: Icon(icon, size: iconSize),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
        ...?trailing == null ? null : [trailing!],
      ],
    );
  }
}

class ArtworkCover extends StatelessWidget {
  const ArtworkCover({
    super.key,
    required this.title,
    required this.palette,
    required this.size,
    this.icon = Icons.graphic_eq_rounded,
    this.showTitle = false,
    this.borderRadius,
  });

  final String title;
  final List<Color> palette;
  final double size;
  final IconData icon;
  final bool showTitle;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.18);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.last.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: -size * 0.16,
              top: -size * 0.16,
              child: Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ),
            Positioned(
              right: -size * 0.18,
              bottom: -size * 0.18,
              child: Container(
                width: size * 0.68,
                height: size * 0.68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: size * 0.12,
              bottom: size * 0.12,
              right: size * 0.12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.90),
                    size: size * 0.18,
                  ),
                  if (showTitle) ...[
                    SizedBox(height: size * 0.06),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.96),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    required this.trailing,
    this.leadingSize = 56,
  });

  final Track track;
  final VoidCallback onTap;
  final Widget trailing;
  final double leadingSize;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(24),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.72),
        LiquidPalette.surface.withValues(alpha: 0.90),
      ],
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            size: leadingSize,
            borderRadius: BorderRadius.circular(leadingSize * 0.28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${track.artist} • ${track.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}
