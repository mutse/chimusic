import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
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
        controller.currentCollection ??
        (track == null ? null : controller.collectionForTrack(track));
    final desktop = isWideWidth(context);

    if (track == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.36),
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
                      maxWidth: desktop ? 980 : 720,
                      maxHeight: MediaQuery.sizeOf(context).height - 28,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(42),
                        tintColors: [
                          LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
                          LiquidPalette.surface.withValues(alpha: 0.96),
                        ],
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
                                                  alpha: 0.64,
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
                                const SizedBox(height: 22),
                                if (desktop)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _NowPlayingHero(
                                          track: track,
                                          collection: collection,
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        flex: 2,
                                        child: _PlaybackSideRail(
                                          track: track,
                                          collection: collection,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _NowPlayingHero(
                                    track: track,
                                    collection: collection,
                                  ),
                                  const SizedBox(height: 18),
                                  _PlaybackSideRail(
                                    track: track,
                                    collection: collection,
                                  ),
                                ],
                                const SizedBox(height: 22),
                                _ProgressSection(track: track),
                                const SizedBox(height: 22),
                                _TransportControls(
                                  track: track,
                                  collection: collection,
                                ),
                                const SizedBox(height: 24),
                                GlassPanel(
                                  padding: const EdgeInsets.all(18),
                                  borderRadius: BorderRadius.circular(30),
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
                                      const SizedBox(height: 8),
                                      Text(
                                        'Keep the queue moving or jump into another track instantly.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.64,
                                              ),
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      if (controller.upNext.isEmpty)
                                        Text(
                                          'The queue ends with the current track.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.66,
                                                ),
                                              ),
                                        )
                                      else
                                        for (final queuedTrack
                                            in controller.upNext) ...[
                                          TrackRow(
                                            track: queuedTrack,
                                            onTap: () {
                                              controller.playTrack(
                                                queuedTrack,
                                                collection:
                                                    controller
                                                        .currentCollection ??
                                                    controller
                                                        .collectionForTrack(
                                                          queuedTrack,
                                                        ),
                                              );
                                            },
                                            trailing: Text(
                                              formatDuration(
                                                queuedTrack.duration,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.66,
                                                        ),
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

class _NowPlayingHero extends StatelessWidget {
  const _NowPlayingHero({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final queueIndex = controller.queue.indexWhere(
      (item) => item.id == track.id,
    );
    final queueLabel = queueIndex < 0
        ? 'In queue'
        : 'Track ${queueIndex + 1} of ${controller.queue.length}';

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        track.palette.first.withValues(alpha: 0.36),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(
                label: track.typeLabel,
                leading: const Icon(Icons.audio_file_rounded, size: 16),
              ),
              GlassPill(label: queueLabel),
              if (collection != null) GlassPill(label: collection!.kind.label),
            ],
          ),
          const SizedBox(height: 20),
          if (isWideWidth(context))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArtworkCover(
                  title: track.album,
                  palette: track.palette,
                  size: 260,
                  showTitle: true,
                  icon: Icons.music_note_rounded,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeroTrackCopy(track: track, collection: collection),
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
                icon: Icons.music_note_rounded,
              ),
            ),
            const SizedBox(height: 20),
            _HeroTrackCopy(track: track, collection: collection),
          ],
        ],
      ),
    );
  }
}

class _HeroTrackCopy extends StatelessWidget {
  const _HeroTrackCopy({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(track.title, style: Theme.of(context).textTheme.displaySmall),
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
              'A local file from your imported library, currently playing through a live queue.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _PlaybackSideRail extends StatelessWidget {
  const _PlaybackSideRail({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Queue Context',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _RailMetric(
                label: 'Collection',
                value: collection?.title ?? 'Current Queue',
              ),
              const SizedBox(height: 12),
              _RailMetric(
                label: 'Duration',
                value: formatDuration(track.duration),
              ),
              const SizedBox(height: 12),
              _RailMetric(
                label: 'Liked',
                value: controller.isTrackLiked(track.id) ? 'Saved' : 'Not yet',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(32),
          tintColors: [
            LiquidPalette.surfaceSoft.withValues(alpha: 0.78),
            LiquidPalette.surfaceRaised.withValues(alpha: 0.92),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Source File',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                track.fileName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                track.filePath,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RailMetric extends StatelessWidget {
  const _RailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
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

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: LiquidPalette.aqua,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: LiquidPalette.softWhite,
              overlayColor: LiquidPalette.aqua.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) => controller.seekToFraction(value),
            ),
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
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 14,
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
        GlassIconButton(
          icon: Icons.skip_previous_rounded,
          onTap: () => controller.skipPrevious(),
          size: 60,
          iconSize: 30,
        ),
        GlassIconButton(
          icon: controller.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: () => controller.togglePlayPause(),
          selected: true,
          size: 76,
          iconSize: 40,
        ),
        GlassIconButton(
          icon: Icons.skip_next_rounded,
          onTap: () => controller.skipNext(),
          size: 60,
          iconSize: 30,
        ),
        if (collection != null)
          GlassIconButton(
            icon: Icons.queue_music_rounded,
            onTap: () => Navigator.of(
              context,
            ).push(CollectionDetailPage.route(collection!)),
            size: 54,
            iconSize: 24,
          ),
      ],
    );
  }
}
