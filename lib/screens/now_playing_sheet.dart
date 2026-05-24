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
                                const SizedBox(height: 24),
                                _LyricsSection(track: track),
                                const SizedBox(height: 24),
                                _CreditsSection(track: track),
                                const SizedBox(height: 24),
                                _SimilarSection(track: track),
                                const SizedBox(height: 24),
                                _QueueSection(track: track),
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
    final historyEntry = controller.playbackHistoryEntryForTrack(track.id);
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
              if (historyEntry != null)
                GlassPill(
                  label:
                      '${historyEntry.playCount} play${historyEntry.playCount == 1 ? '' : 's'}',
                ),
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
                  child: _HeroCopy(track: track, collection: collection),
                ),
              ],
            )
          else ...[
            Center(
              child: ArtworkCover(
                title: track.album,
                palette: track.palette,
                size: 240,
                showTitle: true,
                icon: Icons.music_note_rounded,
              ),
            ),
            const SizedBox(height: 20),
            _HeroCopy(track: track, collection: collection),
          ],
          const SizedBox(height: 22),
          _ProgressCluster(track: track),
          const SizedBox(height: 18),
          _TransportCluster(track: track),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(track.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          '${track.artist} • ${track.album}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (track.genre case final genre?) GlassPill(label: genre),
            if (track.year case final year?) GlassPill(label: '$year'),
            if (track.bitrate case final bitrate?)
              GlassPill(label: '${bitrate}kbps'),
            GlassPill(
              label: controller.isTrackLiked(track.id) ? 'Liked' : 'Like',
              onTap: () => controller.toggleLikedTrack(track.id),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          collection?.description ??
              controller.recommendationReasonForTrack(track),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
      ],
    );
  }
}

class _ProgressCluster extends StatelessWidget {
  const _ProgressCluster({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: controller.playbackProgress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              LiquidPalette.aqua.withValues(alpha: 0.92),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              formatDuration(controller.position, placeholder: '00:00'),
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

class _TransportCluster extends StatelessWidget {
  const _TransportCluster({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassIconButton(
          icon: Icons.skip_previous_rounded,
          onTap: () {
            controller.skipPrevious();
          },
          size: 54,
          iconSize: 28,
        ),
        const SizedBox(width: 14),
        GlassPanel(
          onTap: () {
            controller.togglePlayPause();
          },
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(999),
          tintColors: [
            LiquidPalette.aqua.withValues(alpha: 0.96),
            LiquidPalette.mint.withValues(alpha: 0.74),
          ],
          borderColor: LiquidPalette.mint.withValues(alpha: 0.22),
          withShadow: false,
          child: Icon(
            controller.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            size: 30,
            color: LiquidPalette.ink,
          ),
        ),
        const SizedBox(width: 14),
        GlassIconButton(
          icon: Icons.skip_next_rounded,
          onTap: () {
            controller.skipNext();
          },
          size: 54,
          iconSize: 28,
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
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(30),
          tintColors: [
            LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
            LiquidPalette.surface.withValues(alpha: 0.95),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendation Context',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                controller.recommendationReasonForTrack(track),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GlassPill(label: controller.membershipTier.label),
                  GlassPill(label: controller.syncState.phase.name),
                  if (collection?.reason case final reason?)
                    GlassPill(label: reason),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(30),
          tintColors: [
            LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
            LiquidPalette.surface.withValues(alpha: 0.95),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Up Next', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Jump instantly or let the queue keep moving.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 14),
              if (controller.upNext.isEmpty)
                Text(
                  'The queue ends with the current track.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                )
              else
                for (final queuedTrack in controller.upNext) ...[
                  TrackRow(
                    track: queuedTrack,
                    onTap: () {
                      controller.playTrack(
                        queuedTrack,
                        collection:
                            controller.currentCollection ??
                            controller.collectionForTrack(queuedTrack),
                      );
                    },
                    trailing: Text(
                      formatDuration(queuedTrack.duration),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                  ),
                  if (queuedTrack != controller.upNext.last)
                    const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LyricsSection extends StatelessWidget {
  const _LyricsSection({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final lyrics = controller.lyricsStateForTrack(track);

    if (lyrics.status == LyricsStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadLyricsForTrack(track);
      });
    }

    return SectionCard(
      title: 'Lyrics',
      subtitle:
          'Graceful offline fallback keeps playback independent of metadata.',
      child: switch (lyrics.status) {
        LyricsStatus.loading => const Text('Loading synced lyrics…'),
        LyricsStatus.available => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lyrics.lines) ...[
              Text(line, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 10),
            ],
          ],
        ),
        LyricsStatus.unavailable => Text(
          'No synced lyric lines are available for this track yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        LyricsStatus.error => Text(
          lyrics.errorMessage ?? 'Lyrics could not be loaded.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        LyricsStatus.idle => Text(
          'Lyrics are ready to load.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      },
    );
  }
}

class _CreditsSection extends StatelessWidget {
  const _CreditsSection({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Credits & Metadata',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          GlassPill(label: track.artist),
          GlassPill(label: track.album),
          if (track.genre case final genre?) GlassPill(label: genre),
          if (track.year case final year?) GlassPill(label: '$year'),
          if (track.bitrate case final bitrate?)
            GlassPill(label: '${bitrate}kbps'),
          for (final credit in track.credits) GlassPill(label: credit),
        ],
      ),
    );
  }
}

class _SimilarSection extends StatelessWidget {
  const _SimilarSection({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final similar = controller.similarTracksFor(track);

    return SectionCard(
      title: 'Similar Recommendations',
      subtitle:
          'Matches are generated from artist overlap, enriched genre, likes, and recent behavior.',
      child: similar.isEmpty
          ? Text(
              'Import or play more music to grow the similarity graph.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < similar.length; index++) ...[
                  TrackRow(
                    track: similar[index],
                    onTap: () {
                      controller.playTrack(
                        similar[index],
                        collection: controller.collectionForTrack(
                          similar[index],
                        ),
                      );
                    },
                    trailing: GlassPill(
                      label: controller.recommendationReasonForTrack(
                        similar[index],
                      ),
                    ),
                  ),
                  if (index != similar.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _QueueSection extends StatelessWidget {
  const _QueueSection({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final queue = controller.queue;

    return SectionCard(
      title: 'Queue',
      subtitle:
          'See the full playback order and jump anywhere without leaving the player.',
      child: Column(
        children: [
          for (var index = 0; index < queue.length; index++) ...[
            TrackRow(
              track: queue[index],
              onTap: () {
                controller.playTrack(
                  queue[index],
                  collection: controller.currentCollection,
                );
              },
              trailing: GlassPill(
                label: queue[index].id == track.id
                    ? 'Current'
                    : '#${index + 1}',
                selected: queue[index].id == track.id,
              ),
            ),
            if (index != queue.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
