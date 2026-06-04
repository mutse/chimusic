import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_waveform/just_waveform.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';

bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1100;

bool usesDesktopSidebar(BuildContext context) {
  final platform = Theme.of(context).platform;
  return switch (platform) {
    TargetPlatform.macOS || TargetPlatform.windows => true,
    _ => isDesktopWidth(context),
  };
}

bool isWideWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 820;

EdgeInsets pagePadding(BuildContext context, {double bottom = 180}) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width >= 1200
      ? 36.0
      : width >= 800
      ? 28.0
      : 20.0;

  return EdgeInsets.fromLTRB(horizontal, 28, horizontal, bottom);
}

class LiquidBackdrop extends StatelessWidget {
  const LiquidBackdrop({
    super.key,
    required this.child,
    this.palette = const <Color>[
      LiquidPalette.aqua,
      LiquidPalette.deepCyan,
      LiquidPalette.surface,
    ],
    this.artworkUri,
  });

  final Widget child;
  final List<Color> palette;
  final String? artworkUri;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              palette.first.withValues(alpha: 0.22),
              LiquidPalette.background,
            ),
            Color.alphaBlend(
              palette.length > 1
                  ? palette[1].withValues(alpha: 0.14)
                  : palette.first.withValues(alpha: 0.14),
              const Color(0xFF0B0D12),
            ),
            LiquidPalette.ink,
          ],
        ),
      ),
      child: Stack(
        children: [
          if (!kIsWeb && artworkUri != null && artworkUri!.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.18,
                  child: Image.file(
                    File(artworkUri!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          const Positioned(
            top: -90,
            left: -30,
            child: _BlurOrb(
              size: 260,
              colors: [Color(0x331ED760), Color(0x001ED760)],
            ),
          ),
          const Positioned(
            top: 170,
            right: -90,
            child: _BlurOrb(
              size: 300,
              colors: [Color(0x22F4A259), Color(0x00103222)],
            ),
          ),
          const Positioned(
            bottom: -120,
            left: 140,
            child: _BlurOrb(
              size: 320,
              colors: [Color(0x1A2D7EFF), Color(0x00181B22)],
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
                    Colors.black.withValues(alpha: 0.18),
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
    this.blur = 18,
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
    final radius = borderRadius ?? BorderRadius.circular(28);
    final content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.06),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  tintColors ??
                  [
                    LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
                    LiquidPalette.surface.withValues(alpha: 0.94),
                  ],
            ),
            boxShadow: withShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
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
              LiquidPalette.aqua.withValues(alpha: 0.18),
              LiquidPalette.deepCyan.withValues(alpha: 0.86),
            ]
          : [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.58),
              LiquidPalette.surface.withValues(alpha: 0.90),
            ],
      borderColor: selected
          ? LiquidPalette.mint.withValues(alpha: 0.24)
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
                LiquidPalette.aqua.withValues(alpha: 0.88),
                LiquidPalette.mint.withValues(alpha: 0.64),
              ]
            : [
                LiquidPalette.surfaceSoft.withValues(alpha: 0.62),
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
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...?trailing == null ? null : [trailing!],
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(30),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.95),
        LiquidPalette.surface.withValues(alpha: 0.94),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle, trailing: trailing),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class MetricGlassCard extends StatelessWidget {
  const MetricGlassCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
    this.accent,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final List<Color>? accent;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors =
        accent ??
        [
          LiquidPalette.surfaceSoft.withValues(alpha: 0.62),
          LiquidPalette.surface.withValues(alpha: 0.92),
        ];

    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      tintColors: colors,
      borderColor: colors.last.withValues(alpha: 0.12),
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class ArtworkCover extends StatelessWidget {
  const ArtworkCover({
    super.key,
    required this.title,
    required this.palette,
    required this.size,
    this.artworkUri,
    this.icon = Icons.graphic_eq_rounded,
    this.showTitle = false,
    this.borderRadius,
  });

  final String title;
  final List<Color> palette;
  final double size;
  final String? artworkUri;
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
            color: palette.last.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (!kIsWeb && artworkUri != null && artworkUri!.isNotEmpty)
              Positioned.fill(
                child: Image.file(
                  File(artworkUri!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Positioned(
              left: -size * 0.16,
              top: -size * 0.16,
              child: Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
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
                  color: Colors.black.withValues(alpha: 0.08),
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
                      Colors.black.withValues(alpha: 0.12),
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

class WaveformProgressBar extends StatelessWidget {
  const WaveformProgressBar({
    super.key,
    required this.progress,
    required this.palette,
    this.waveform,
    this.height = 64,
    this.onSeek,
  });

  final double progress;
  final List<Color> palette;
  final Waveform? waveform;
  final double height;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: onSeek == null
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || box.size.width <= 0) {
                return;
              }
              final local = box.globalToLocal(details.globalPosition);
              onSeek!(local.dx / box.size.width);
            },
      onTapDown: onSeek == null
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || box.size.width <= 0) {
                return;
              }
              final local = box.globalToLocal(details.globalPosition);
              onSeek!(local.dx / box.size.width);
            },
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _WaveformProgressPainter(
          progress: clampedProgress.toDouble(),
          palette: palette,
          waveform: waveform,
        ),
      ),
    );
  }
}

class _WaveformProgressPainter extends CustomPainter {
  const _WaveformProgressPainter({
    required this.progress,
    required this.palette,
    required this.waveform,
  });

  final double progress;
  final List<Color> palette;
  final Waveform? waveform;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = waveform == null ? 56 : math.min(72, waveform!.length);
    if (barCount <= 0) {
      return;
    }

    final activeColor = palette.first.withValues(alpha: 0.96);
    final inactiveColor = Colors.white.withValues(alpha: 0.16);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          palette.first.withValues(alpha: 0.96),
          palette.length > 1
              ? palette[1].withValues(alpha: 0.74)
              : palette.first.withValues(alpha: 0.74),
        ],
      ).createShader(Offset.zero & size)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, size.width / (barCount * 3.6));
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = glowPaint.strokeWidth;

    final spacing = size.width / barCount;
    for (var index = 0; index < barCount; index++) {
      final x = (index + 0.5) * spacing;
      final heightFactor = _sampleHeight(index, barCount);
      final barHeight =
          (size.height * 0.2) + (size.height * 0.7 * heightFactor);
      final top = (size.height - barHeight) / 2;
      final bottom = top + barHeight;
      final paint = index / barCount <= progress ? glowPaint : inactivePaint;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    final progressX = size.width * progress;
    final scrubberPaint = Paint()..color = activeColor;
    canvas.drawCircle(
      Offset(progressX.clamp(0.0, size.width), size.height / 2),
      glowPaint.strokeWidth * 0.95,
      scrubberPaint,
    );
  }

  double _sampleHeight(int index, int barCount) {
    if (waveform == null || waveform!.length == 0) {
      final oscillation = math.sin(index * 0.33) * 0.32;
      final second = math.cos(index * 0.18) * 0.24;
      return (0.42 + oscillation + second).clamp(0.12, 1.0);
    }

    final waveformIndex = (index * waveform!.length / barCount).floor().clamp(
      0,
      waveform!.length - 1,
    );
    final minValue = waveform!.getPixelMin(waveformIndex).abs();
    final maxValue = waveform!.getPixelMax(waveformIndex).abs();
    final normalized = (minValue + maxValue) / 512;
    return normalized.clamp(0.12, 1.0);
  }

  @override
  bool shouldRepaint(covariant _WaveformProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.palette != palette;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(24),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.58),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            artworkUri: track.artworkUri,
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
