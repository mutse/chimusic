import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';

class NowPlayingSheet extends StatelessWidget {
  const NowPlayingSheet({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const NowPlayingSheet(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    final collection =
        controller.currentCollection ?? controller.collectionForTrack(track);
    final desktop = isWideWidth(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: desktop ? 860 : 680,
                      maxHeight: MediaQuery.sizeOf(context).height - 32,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(42),
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: Column(
                              key: ValueKey(track.id),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Now Playing',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          collection?.title ?? 'Current Queue',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.66,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    GlassIconButton(
                                      icon: Icons.close_rounded,
                                      onTap: () => Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                if (desktop)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ArtworkCover(
                                        title: track.album,
                                        palette: track.palette,
                                        size: 320,
                                        showTitle: true,
                                      ),
                                      const SizedBox(width: 28),
                                      Expanded(
                                        child: _NowPlayingDetails(
                                          track: track,
                                          collection: collection,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  Center(
                                    child: ArtworkCover(
                                      title: track.album,
                                      palette: track.palette,
                                      size: 280,
                                      showTitle: true,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _NowPlayingDetails(
                                    track: track,
                                    collection: collection,
                                  ),
                                ],
                                const SizedBox(height: 24),
                                _ProgressSection(track: track),
                                const SizedBox(height: 24),
                                _TransportControls(track: track),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    GlassPill(
                                      label: track.moodTag,
                                      leading: const Icon(
                                        Icons.wb_twilight_rounded,
                                        size: 16,
                                      ),
                                    ),
                                    if (collection != null)
                                      GlassPill(
                                        label: collection.kind.label,
                                        leading: const Icon(
                                          Icons.album_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    GlassPill(
                                      label: controller.isTrackLiked(track.id)
                                          ? 'Liked'
                                          : 'Tap heart to save',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                GlassPanel(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Up Next',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      for (final queuedTrack
                                          in controller.upNext) ...[
                                        TrackRow(
                                          track: queuedTrack,
                                          onTap: () => controller.playTrack(
                                            queuedTrack,
                                            collection: controller
                                                .collectionForTrack(
                                                  queuedTrack,
                                                ),
                                          ),
                                          trailing: Text(
                                            formatDuration(
                                              queuedTrack.duration,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.66),
                                                ),
                                          ),
                                        ),
                                        if (queuedTrack !=
                                            controller.upNext.last)
                                          const SizedBox(height: 12),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingDetails extends StatelessWidget {
  const _NowPlayingDetails({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          track.artist,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          collection?.description ??
              'A polished queue built around your current mood.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
        if (track.lyricLine != null) ...[
          const SizedBox(height: 18),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(24),
            tintColors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.05),
            ],
            withShadow: false,
            child: Text(
              '"${track.lyricLine}"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final progress = controller.playbackProgress.clamp(0.0, 1.0);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white.withValues(alpha: 0.92),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: LiquidPalette.softWhite,
            overlayColor: LiquidPalette.aqua.withValues(alpha: 0.18),
          ),
          child: Slider(value: progress, onChanged: controller.seekToFraction),
        ),
        Row(
          children: [
            Text(
              formatDuration(controller.position),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
              ),
            ),
            const Spacer(),
            Text(
              formatDuration(track.duration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassIconButton(
          icon: controller.isTrackLiked(track.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          onTap: () => controller.toggleLikedTrack(track.id),
          selected: controller.isTrackLiked(track.id),
          size: 54,
          iconSize: 24,
        ),
        const SizedBox(width: 14),
        GlassIconButton(
          icon: Icons.skip_previous_rounded,
          onTap: controller.skipPrevious,
          size: 60,
          iconSize: 30,
        ),
        const SizedBox(width: 14),
        GlassIconButton(
          icon: controller.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: controller.togglePlayPause,
          selected: true,
          size: 76,
          iconSize: 40,
        ),
        const SizedBox(width: 14),
        GlassIconButton(
          icon: Icons.skip_next_rounded,
          onTap: controller.skipNext,
          size: 60,
          iconSize: 30,
        ),
        const SizedBox(width: 14),
        GlassIconButton(
          icon: Icons.speaker_group_rounded,
          onTap: () {},
          size: 54,
          iconSize: 24,
        ),
      ],
    );
  }
}
