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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                      color: Colors.black.withValues(alpha: 0.42),
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
                        maxWidth: desktop ? 1140 : 760,
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
                                            collection?.title ??
                                                'Current Queue',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.64),
                                                ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      GlassIconButton(
                                        icon: Icons.close_rounded,
                                        onTap: () =>
                                            Navigator.of(context).pop(),
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
                                          child: _ImmersiveHero(
                                            track: track,
                                            collection: collection,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          flex: 2,
                                          child: _TrackInspector(
                                            track: track,
                                            collection: collection,
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _ImmersiveHero(
                                      track: track,
                                      collection: collection,
                                    ),
                                    const SizedBox(height: 18),
                                    _TrackInspector(
                                      track: track,
                                      collection: collection,
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  _BottomStageTabs(track: track),
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
      ),
    );
  }
}

class _ImmersiveHero extends StatelessWidget {
  const _ImmersiveHero({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final historyEntry = controller.playbackHistoryEntryForTrack(track.id);
    final queueIndex = controller.queue.indexWhere(
      (item) => item.id == track.id,
    );

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
              GlassPill(label: track.typeLabel),
              GlassPill(
                label: queueIndex < 0
                    ? 'In queue'
                    : 'Track ${queueIndex + 1} of ${controller.queue.length}',
              ),
              GlassPill(label: track.availability.label),
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
                  artworkUri: track.artworkUri,
                  size: 280,
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
                artworkUri: track.artworkUri,
                size: 250,
                showTitle: true,
                icon: Icons.music_note_rounded,
              ),
            ),
            const SizedBox(height: 20),
            _HeroCopy(track: track, collection: collection),
          ],
          const SizedBox(height: 22),
          _ProgressCluster(track: track),
          if (!track.isAvailable) ...[
            const SizedBox(height: 18),
            _UnavailableTrackBanner(track: track),
          ],
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
            if (track.trackNumber case final trackNumber?)
              GlassPill(label: 'Track $trackNumber'),
            if (track.discNumber case final discNumber?)
              GlassPill(label: 'Disc $discNumber'),
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
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            GlassPill(
              label: controller.isTrackLiked(track.id) ? 'Liked' : 'Like',
              onTap: () => controller.toggleLikedTrack(track.id),
            ),
            if (controller.playbackHistoryEntryForTrack(track.id)
                case final entry?)
              GlassPill(
                label: 'Played ${formatRelativePlayTime(entry.lastPlayedAt)}',
              ),
          ],
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
        WaveformProgressBar(
          progress: controller.playbackProgress,
          palette: track.palette,
          waveform: controller.waveformForTrack(track),
          onSeek: track.isAvailable
              ? (value) {
                  controller.seekToFraction(value);
                }
              : null,
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

class _UnavailableTrackBanner extends StatelessWidget {
  const _UnavailableTrackBanner({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      tintColors: const [Color(0xFF40261B), Color(0xFF5D3423)],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original file is unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Keep the play history, then re-link this track to a reachable file or remove it from the library.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(
                label: 'Re-link',
                onTap: () => controller.relinkTrack(track),
              ),
              GlassPill(
                label: 'Remove',
                onTap: () => controller.removeTrackFromLibrary(track.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportCluster extends StatelessWidget {
  const _TransportCluster({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final tabController = DefaultTabController.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GlassIconButton(
          icon: Icons.skip_previous_rounded,
          onTap: () {
            controller.skipPrevious();
          },
          size: 56,
          iconSize: 28,
        ),
        GlassPanel(
          onTap: () {
            controller.togglePlayPause();
          },
          padding: const EdgeInsets.all(20),
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
            size: 34,
            color: LiquidPalette.ink,
          ),
        ),
        GlassIconButton(
          icon: Icons.skip_next_rounded,
          onTap: () {
            controller.skipNext();
          },
          size: 56,
          iconSize: 28,
        ),
        GlassIconButton(
          icon: controller.isTrackLiked(track.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          onTap: () => controller.toggleLikedTrack(track.id),
          selected: controller.isTrackLiked(track.id),
          size: 56,
          iconSize: 24,
        ),
        GlassIconButton(
          icon: Icons.queue_music_rounded,
          onTap: () {
            tabController.animateTo(0);
          },
          size: 56,
          iconSize: 24,
        ),
      ],
    );
  }
}

class _TrackInspector extends StatelessWidget {
  const _TrackInspector({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final historyEntry = controller.playbackHistoryEntryForTrack(track.id);
    final source = controller.trackSourceForTrack(track.id);

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
                'Track Context',
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
                  if (collection != null) GlassPill(label: collection!.title),
                  GlassPill(label: source?.platform ?? 'local'),
                  GlassPill(label: track.availability.label),
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
              Text(
                'Playback Stats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _InspectorRow(
                label: 'Play count',
                value: '${historyEntry?.playCount ?? 0}',
              ),
              _InspectorRow(
                label: 'Resume position',
                value: formatDuration(historyEntry?.lastPosition),
              ),
              _InspectorRow(
                label: 'Total listened',
                value: formatDuration(historyEntry?.totalListened),
              ),
              _InspectorRow(
                label: 'Imported',
                value: formatRelativePlayTime(track.importedAt),
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
              Text(
                'Source File',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                track.fileName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                source?.locator ?? track.filePath,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _BottomStageTabs extends StatelessWidget {
  const _BottomStageTabs({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final desktop = isWideWidth(context);

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(32),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
        LiquidPalette.surface.withValues(alpha: 0.94),
      ],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  LiquidPalette.aqua.withValues(alpha: 0.92),
                  LiquidPalette.mint.withValues(alpha: 0.74),
                ],
              ),
            ),
            labelColor: LiquidPalette.ink,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
            tabs: const [
              Tab(text: 'Queue'),
              Tab(text: 'Lyrics'),
              Tab(text: 'History'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: desktop ? 340 : 400,
            child: TabBarView(
              children: [
                _QueueTab(track: track),
                _LyricsTab(track: track),
                _HistoryTab(track: track),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final queue = controller.queue;

    return SingleChildScrollView(
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
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!queue[index].isAvailable)
                    const GlassPill(label: 'Unavailable'),
                  GlassPill(
                    label: queue[index].id == track.id
                        ? 'Current'
                        : '#${index + 1}',
                    selected: queue[index].id == track.id,
                  ),
                ],
              ),
            ),
            if (index != queue.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LyricsTab extends StatelessWidget {
  const _LyricsTab({required this.track});

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

    return SingleChildScrollView(
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
        LyricsStatus.unavailable => _MutedCopy(
          message: 'No synced lyric lines are available for this track yet.',
        ),
        LyricsStatus.error => _MutedCopy(
          message: lyrics.errorMessage ?? 'Lyrics could not be loaded.',
        ),
        LyricsStatus.idle => const _MutedCopy(
          message: 'Lyrics are ready to load.',
        ),
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    final events = controller.playbackEventsForTrack(track.id);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(
                label:
                    '${entry?.playCount ?? 0} play${entry?.playCount == 1 ? '' : 's'}',
              ),
              GlassPill(label: formatDuration(entry?.lastPosition)),
              GlassPill(label: formatDuration(entry?.totalListened)),
              if (entry != null)
                GlassPill(
                  label:
                      'Last played ${formatRelativePlayTime(entry.lastPlayedAt)}',
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (events.isEmpty)
            const _MutedCopy(
              message: 'This track has no saved playback events yet.',
            )
          else
            Column(
              children: [
                for (var index = 0; index < events.length; index++) ...[
                  _HistoryEventRow(event: events[index]),
                  if (index != events.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryEventRow extends StatelessWidget {
  const _HistoryEventRow({required this.event});

  final PlaybackEvent event;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.66),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: const Icon(Icons.history_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventTimestampLabel(event.startedAt),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Listened ${formatDuration(event.maxPosition)} • ${_playbackEndReasonLabel(event.endReason)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
                if (event.collectionId case final collectionId?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      collectionId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedCopy extends StatelessWidget {
  const _MutedCopy({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.68),
      ),
    );
  }
}

String _playbackEndReasonLabel(PlaybackEndReason? reason) {
  return switch (reason) {
    PlaybackEndReason.completed => 'Completed',
    PlaybackEndReason.paused => 'Paused',
    PlaybackEndReason.skipped => 'Skipped',
    PlaybackEndReason.stopped => 'Stopped',
    PlaybackEndReason.replaced => 'Replaced',
    null => 'Active',
  };
}

String _eventTimestampLabel(DateTime startedAt) {
  final monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = startedAt.hour.toString().padLeft(2, '0');
  final minute = startedAt.minute.toString().padLeft(2, '0');
  return '${monthLabels[startedAt.month - 1]} ${startedAt.day} • $hour:$minute';
}
