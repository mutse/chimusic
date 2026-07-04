import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/app_details_sheet.dart';
import '../screens/collection_detail_page.dart';
import '../screens/now_playing_sheet.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';
import '../widgets/local_music_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(controller: controller),
              const SizedBox(height: 24),
              if (controller.statusMessage != null) ...[
                StatusBanner(
                  message: controller.statusMessage!,
                  onDismiss: controller.clearStatusMessage,
                ),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                _HomeOnboarding(controller: controller)
              else
                _HomeContent(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final greeting = _buildGreeting();

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.deepCyan.withValues(alpha: 0.80),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      LiquidPalette.aqua.withValues(alpha: 0.92),
                      LiquidPalette.mint.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.multitrack_audio_rounded,
                  color: LiquidPalette.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.hasMusic
                          ? 'Your local stage is live. Resume sessions, surface recent imports, and keep playback flowing from the same glass control surface.'
                          : 'Import music to build a local-first player with history, resume, and immersive playback.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.search_rounded,
                onTap: controller.openSearch,
                size: 48,
                iconSize: 22,
              ),
              const SizedBox(width: 10),
              GlassIconButton(
                icon: Icons.settings_rounded,
                onTap: () {
                  AppDetailsSheet.show(context);
                },
                size: 48,
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useFourColumnMetrics = constraints.maxWidth >= 960;

              return GridView.count(
                crossAxisCount: useFourColumnMetrics ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: useFourColumnMetrics ? 1.55 : 1.18,
                children: [
                  MetricGlassCard(
                    value: '${controller.importedTrackCount}',
                    label: 'Tracks',
                    icon: Icons.music_note_rounded,
                    onTap: () =>
                        controller.openLibraryFilter(LibraryFilter.tracks),
                    accent: const [Color(0xFF153C2A), Color(0xFF1ED760)],
                  ),
                  MetricGlassCard(
                    value: '${controller.playbackHistoryCount}',
                    label: 'Resume Ready',
                    icon: Icons.history_rounded,
                    onTap: () =>
                        controller.openLibraryFilter(LibraryFilter.tracks),
                    accent: const [Color(0xFF1B2948), Color(0xFF4B7BFF)],
                  ),
                  MetricGlassCard(
                    value: '${controller.totalPlayCount}',
                    label: 'Total Plays',
                    icon: Icons.auto_graph_rounded,
                    onTap: () => controller.selectTab(MusicTab.library),
                    accent: const [Color(0xFF31231A), Color(0xFFF4A259)],
                  ),
                  MetricGlassCard(
                    value: '${controller.albumCount}',
                    label: 'Albums',
                    icon: Icons.album_rounded,
                    onTap: () =>
                        controller.openLibraryFilter(LibraryFilter.albums),
                    accent: const [Color(0xFF4B1212), Color(0xFFE53935)],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _buildGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

class _HomeOnboarding extends StatelessWidget {
  const _HomeOnboarding({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final wide = isWideWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _OnboardingHero(controller: controller)),
              const SizedBox(width: 18),
              const Expanded(flex: 2, child: _OnboardingFeatureStack()),
            ],
          )
        else ...[
          _OnboardingHero(controller: controller),
          const SizedBox(height: 18),
          const _OnboardingFeatureStack(),
        ],
      ],
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        LiquidPalette.deepCyan.withValues(alpha: 0.86),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              GlassPill(label: 'Home'),
              GlassPill(label: 'Resume'),
              GlassPill(label: 'History'),
              GlassPill(label: 'Waveform'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Turn local files into a full music app experience.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Import once, then keep a persistent stage for playback, session history, resume points, and dynamic artwork-driven browsing built from your own files.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 24),
          ImportMusicActions(controller: controller),
        ],
      ),
    );
  }
}

class _OnboardingFeatureStack extends StatelessWidget {
  const _OnboardingFeatureStack();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FeatureCard(
          icon: Icons.play_circle_fill_rounded,
          title: 'Continue Listening',
          body:
              'Resume from the exact position where you stopped, without rebuilding the queue.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.graphic_eq_rounded,
          title: 'Immersive Stage',
          body:
              'Artwork, waveform, playback controls, and history stay visually connected.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.history_toggle_off_rounded,
          title: 'Persistent History',
          body:
              'Recent sessions, most played tracks, and saved progress survive app restarts.',
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.72),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final wide = isWideWidth(context);
    final stageTrack =
        controller.currentTrack ??
        (controller.continueListeningTracks.isEmpty
            ? null
            : controller.continueListeningTracks.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stageTrack != null && wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _PlaybackStage(track: stageTrack)),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: _SessionInsightCard(controller: controller),
              ),
            ],
          )
        else ...[
          if (stageTrack != null) _PlaybackStage(track: stageTrack),
          if (stageTrack != null) const SizedBox(height: 18),
          _SessionInsightCard(controller: controller),
        ],
        const SizedBox(height: 30),
        _HomeTrackSection(
          title: 'Continue Listening',
          subtitle:
              'Resume the exact track or queue state that still has momentum.',
          tracks: controller.continueListeningTracks,
          emptyMessage:
              'Play a track once and ChiMusic will keep the stage warm here.',
          trailingBuilder: (track) {
            final entry = controller.playbackHistoryEntryForTrack(track.id);
            if (entry != null && entry.lastPosition > Duration.zero) {
              return GlassPill(label: formatDuration(entry.lastPosition));
            }
            return GlassPill(label: formatDuration(track.duration));
          },
          onTrackTap: (track) => _playFromHistory(controller, track),
        ),
        const SizedBox(height: 30),
        _HomeTrackSection(
          title: 'Fresh Imports',
          subtitle:
              'The latest additions land here first, ready for immediate playback.',
          tracks: controller.recentImportedTracks
              .take(6)
              .toList(growable: false),
          emptyMessage:
              'Import files or a folder to start shaping your library.',
          trailingBuilder: (track) =>
              GlassPill(label: formatRelativePlayTime(track.importedAt)),
          onTrackTap: (track) {
            controller.playTrack(
              track,
              collection: controller.collectionForTrack(track),
            );
          },
        ),
        const SizedBox(height: 30),
        _HomeTrackSection(
          title: 'Most Played',
          subtitle:
              'These tracks keep pulling you back in across saved sessions.',
          tracks: controller.mostPlayedTracks.take(6).toList(growable: false),
          emptyMessage:
              'Once you build some history, the most-played lane appears here.',
          trailingBuilder: (track) {
            final entry = controller.playbackHistoryEntryForTrack(track.id);
            return GlassPill(
              label:
                  '${entry?.playCount ?? 0} play${entry?.playCount == 1 ? '' : 's'}',
            );
          },
          onTrackTap: (track) => _playFromHistory(controller, track),
        ),
        const SizedBox(height: 30),
        _RecentSessionsSection(controller: controller),
      ],
    );
  }
}

class _PlaybackStage extends StatelessWidget {
  const _PlaybackStage({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final collection =
        controller.currentCollection ?? controller.collectionForTrack(track);
    final historyEntry = controller.playbackHistoryEntryForTrack(track.id);
    final isCurrent = controller.currentTrack?.id == track.id;
    final progress = isCurrent
        ? controller.playbackProgress
        : controller.playbackHistoryProgressForTrack(track);

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        track.palette.first.withValues(alpha: 0.34),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: isCurrent ? 'Live Stage' : 'Continue Listening'),
              GlassPill(label: track.typeLabel),
              GlassPill(label: track.availability.label),
              if (collection != null) GlassPill(label: collection.kind.label),
              if (historyEntry != null)
                GlassPill(
                  label:
                      '${historyEntry.playCount} play${historyEntry.playCount == 1 ? '' : 's'}',
                ),
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
                  size: 240,
                  showTitle: true,
                  icon: Icons.music_note_rounded,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _PlaybackStageCopy(
                    track: track,
                    collection: collection,
                    historyEntry: historyEntry,
                    isCurrent: isCurrent,
                  ),
                ),
              ],
            )
          else ...[
            Center(
              child: ArtworkCover(
                title: track.album,
                palette: track.palette,
                artworkUri: track.artworkUri,
                size: 220,
                showTitle: true,
                icon: Icons.music_note_rounded,
              ),
            ),
            const SizedBox(height: 20),
            _PlaybackStageCopy(
              track: track,
              collection: collection,
              historyEntry: historyEntry,
              isCurrent: isCurrent,
            ),
          ],
          const SizedBox(height: 22),
          WaveformProgressBar(
            progress: progress,
            palette: track.palette,
            waveform: controller.waveformForTrack(track),
            onSeek: isCurrent && track.isAvailable
                ? (value) {
                    controller.seekToFraction(value);
                  }
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                isCurrent
                    ? formatDuration(controller.position, placeholder: '00:00')
                    : formatDuration(
                        historyEntry?.lastPosition,
                        placeholder: '00:00',
                      ),
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
          if (!track.isAvailable) ...[
            const SizedBox(height: 18),
            _UnavailableTrackCard(track: track),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () {
                    if (!track.isAvailable) {
                      controller.relinkTrack(track);
                      return;
                    }
                    if (isCurrent) {
                      Navigator.of(context).push(NowPlayingSheet.route());
                      return;
                    }
                    _playFromHistory(controller, track);
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.96),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.22),
                  withShadow: false,
                  child: Text(
                    !track.isAvailable
                        ? 'Re-link File'
                        : isCurrent
                        ? 'Open Stage'
                        : historyEntry != null &&
                              historyEntry.lastPosition > Duration.zero
                        ? 'Resume'
                        : 'Play Now',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: LiquidPalette.ink),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: controller.isTrackLiked(track.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onTap: () => controller.toggleLikedTrack(track.id),
                selected: controller.isTrackLiked(track.id),
                size: 54,
                iconSize: 24,
              ),
              if (collection != null) ...[
                const SizedBox(width: 12),
                GlassIconButton(
                  icon: Icons.queue_music_rounded,
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(CollectionDetailPage.route(collection));
                  },
                  size: 54,
                  iconSize: 24,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaybackStageCopy extends StatelessWidget {
  const _PlaybackStageCopy({
    required this.track,
    required this.collection,
    required this.historyEntry,
    required this.isCurrent,
  });

  final Track track;
  final MusicCollection? collection;
  final PlaybackHistoryEntry? historyEntry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
        const SizedBox(height: 18),
        Text(
          isCurrent
              ? 'Your current playback state stays live across Home, mini player, and the full-screen stage.'
              : (historyEntry?.lastPosition ?? Duration.zero) > Duration.zero
              ? 'Resume from ${formatDuration(historyEntry?.lastPosition)} inside ${collection?.title ?? track.album}.'
              : 'Jump back into this track from ${collection?.title ?? track.album}.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (historyEntry != null)
              GlassPill(
                label:
                    'Last played ${formatRelativePlayTime(historyEntry!.lastPlayedAt)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _SessionInsightCard extends StatelessWidget {
  const _SessionInsightCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final recentGroups = controller.recentSessionGroups;
    final lastSession = recentGroups.isEmpty ? null : recentGroups.first;

    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.surface.withValues(alpha: 0.95),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Signals',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _InsightRow(
            label: 'Resume lane',
            value: controller.resumeTracks.isEmpty
                ? 'No saved positions yet.'
                : '${controller.resumeTracks.length} track${controller.resumeTracks.length == 1 ? '' : 's'} can resume from a saved position.',
            icon: Icons.play_circle_outline_rounded,
          ),
          const SizedBox(height: 12),
          _InsightRow(
            label: 'Playback history',
            value: controller.playbackEvents.isEmpty
                ? 'Recent sessions appear after the first play.'
                : '${controller.playbackEvents.length} session event${controller.playbackEvents.length == 1 ? '' : 's'} stored locally.',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 12),
          _InsightRow(
            label: 'Local storage',
            value:
                'History, likes, saved collections, and queue state stay on this device.',
            icon: Icons.storage_rounded,
          ),
          if (lastSession != null) ...[
            const SizedBox(height: 14),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(24),
              tintColors: [
                LiquidPalette.surfaceSoft.withValues(alpha: 0.72),
                LiquidPalette.surface.withValues(alpha: 0.92),
              ],
              withShadow: false,
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Latest listening burst: ${_formatHistoryDay(lastSession.day)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  GlassPill(
                    label:
                        '${lastSession.events.length} session${lastSession.events.length == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeTrackSection extends StatelessWidget {
  const _HomeTrackSection({
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.emptyMessage,
    required this.trailingBuilder,
    required this.onTrackTap,
  });

  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String emptyMessage;
  final Widget Function(Track track) trailingBuilder;
  final ValueChanged<Track> onTrackTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: tracks.isEmpty
          ? _EmptySectionCopy(message: emptyMessage)
          : Column(
              children: [
                for (var index = 0; index < tracks.length; index++) ...[
                  TrackRow(
                    track: tracks[index],
                    onTap: () => onTrackTap(tracks[index]),
                    trailing: trailingBuilder(tracks[index]),
                  ),
                  if (index != tracks.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final groups = controller.recentSessionGroups
        .take(4)
        .toList(growable: false);
    final tracksById = {
      for (final track in controller.importedTracks) track.id: track,
    };

    return SectionCard(
      title: 'Recent Sessions',
      subtitle:
          'A day-grouped timeline of what actually entered playback, not just what was queued.',
      child: groups.isEmpty
          ? const _EmptySectionCopy(
              message:
                  'Recent session groups will appear after playback begins.',
            )
          : Column(
              children: [
                for (
                  var groupIndex = 0;
                  groupIndex < groups.length;
                  groupIndex++
                ) ...[
                  _HistoryDayCard(
                    day: groups[groupIndex].day,
                    events: groups[groupIndex].events,
                    tracksById: tracksById,
                  ),
                  if (groupIndex != groups.length - 1)
                    const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _HistoryDayCard extends StatelessWidget {
  const _HistoryDayCard({
    required this.day,
    required this.events,
    required this.tracksById,
  });

  final DateTime day;
  final List<PlaybackEvent> events;
  final Map<String, Track> tracksById;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.70),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatHistoryDay(day),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              GlassPill(
                label:
                    '${events.length} session${events.length == 1 ? '' : 's'}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < events.length && index < 4; index++) ...[
            Builder(
              builder: (context) {
                final event = events[index];
                final track = tracksById[event.trackId];
                if (track == null) {
                  return const SizedBox.shrink();
                }
                final listened = event.maxPosition > Duration.zero
                    ? formatDuration(event.maxPosition)
                    : formatDuration(track.duration);
                return TrackRow(
                  track: track,
                  onTap: () => _playFromHistory(controller, track),
                  trailing: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GlassPill(label: listened),
                      GlassPill(
                        label: _playbackEndReasonLabel(event.endReason),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (index != events.length - 1 && index != 3)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _UnavailableTrackCard extends StatelessWidget {
  const _UnavailableTrackCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      tintColors: const [Color(0xFF3F241A), Color(0xFF5B3323)],
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
            'Keep the history, then re-link this track to a new local file or remove it from the library.',
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

class _EmptySectionCopy extends StatelessWidget {
  const _EmptySectionCopy({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.66),
      ),
    );
  }
}

void _playFromHistory(MusicAppController controller, Track track) {
  final collection = controller.collectionForTrack(track);
  final entry = controller.playbackHistoryEntryForTrack(track.id);
  if (entry != null && entry.lastPosition > Duration.zero) {
    controller.resumeTrack(track, collection: collection);
    return;
  }

  controller.playTrack(track, collection: collection);
}

String _formatHistoryDay(DateTime day) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfDay = DateTime(day.year, day.month, day.day);
  final difference = startOfToday.difference(startOfDay).inDays;

  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }

  const monthLabels = <String>[
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
  return '${monthLabels[day.month - 1]} ${day.day}';
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
