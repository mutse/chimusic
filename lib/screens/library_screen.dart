import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/app_details_sheet.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';
import '../widgets/local_music_widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final wide = isWideWidth(context);

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(34),
                tintColors: [
                  LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
                  LiquidPalette.deepCyan.withValues(alpha: 0.78),
                ],
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Library',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tracks, albums, artists, imports, and persistent playback history all stay on one local surface.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.68),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              GlassPill(
                                label:
                                    '${controller.importedTrackCount} tracks',
                              ),
                              GlassPill(
                                label: '${controller.albumCount} albums',
                              ),
                              GlassPill(
                                label: '${controller.artistCount} artists',
                              ),
                              GlassPill(
                                label:
                                    '${controller.playbackEvents.length} sessions',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GlassIconButton(
                      icon: Icons.tune_rounded,
                      onTap: () => AppDetailsSheet.show(context),
                      size: 48,
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _LibrarySummary(controller: controller),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: _LibraryContextCard(controller: controller),
                    ),
                  ],
                )
              else ...[
                _LibrarySummary(controller: controller),
                const SizedBox(height: 18),
                _LibraryContextCard(controller: controller),
              ],
              const SizedBox(height: 18),
              if (controller.statusMessage != null) ...[
                StatusBanner(
                  message: controller.statusMessage!,
                  onDismiss: controller.clearStatusMessage,
                ),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                EmptyMusicState(
                  title: 'Your library is empty',
                  body:
                      'Import audio files or folders to populate tracks, albums, artists, and persistent resume history.',
                  controller: controller,
                )
              else ...[
                _LibraryViewsCard(controller: controller),
                const SizedBox(height: 30),
                _FocusedViewSection(controller: controller),
                const SizedBox(height: 30),
                _TracksSection(controller: controller),
                const SizedBox(height: 30),
                _AlbumsAndArtistsSection(controller: controller),
                const SizedBox(height: 30),
                _HistorySection(controller: controller),
                const SizedBox(height: 30),
                _RecentImportsSection(controller: controller),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.surface.withValues(alpha: 0.95),
      ],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          SizedBox(
            height: 192,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                MetricGlassCard(
                  value: '${controller.importedTrackCount}',
                  label: 'Tracks',
                  icon: Icons.music_note_rounded,
                  accent: const [Color(0xFF153C2A), Color(0xFF1ED760)],
                ),
                MetricGlassCard(
                  value: '${controller.albumCount}',
                  label: 'Albums',
                  icon: Icons.album_rounded,
                  accent: const [Color(0xFF10233E), Color(0xFF4B7BFF)],
                ),
                MetricGlassCard(
                  value: '${controller.artistCount}',
                  label: 'Artists',
                  icon: Icons.mic_external_on_rounded,
                  accent: const [Color(0xFF3A280F), Color(0xFFF4A259)],
                ),
                MetricGlassCard(
                  value: '${controller.totalPlayCount}',
                  label: 'Plays',
                  icon: Icons.play_circle_fill_rounded,
                  accent: const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryContextCard extends StatelessWidget {
  const _LibraryContextCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final unavailableCount = controller.importedTracks
        .where((track) => !track.isAvailable)
        .length;

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(30),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.surface.withValues(alpha: 0.94),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Playback Context',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _ContextRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'Resume queue',
            value: controller.resumeTracks.isEmpty
                ? 'No saved positions yet.'
                : '${controller.resumeTracks.length} track${controller.resumeTracks.length == 1 ? '' : 's'} can resume.',
          ),
          const SizedBox(height: 12),
          _ContextRow(
            icon: Icons.history_rounded,
            label: 'Recent sessions',
            value: controller.playbackEvents.isEmpty
                ? 'Playback events appear after the first play.'
                : '${controller.playbackEvents.length} local session event${controller.playbackEvents.length == 1 ? '' : 's'} stored.',
          ),
          const SizedBox(height: 12),
          _ContextRow(
            icon: Icons.link_off_rounded,
            label: 'Unavailable files',
            value: unavailableCount == 0
                ? 'All imported files are currently reachable.'
                : '$unavailableCount track${unavailableCount == 1 ? '' : 's'} need re-linking or removal.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: controller.membershipTier.label),
              GlassPill(label: controller.syncState.phase.name),
              if (controller.syncState.lastSyncedAt != null)
                GlassPill(
                  label:
                      'Updated ${formatRelativePlayTime(controller.syncState.lastSyncedAt!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryViewsCard extends StatelessWidget {
  const _LibraryViewsCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Views',
      subtitle:
          'Switch the focused lane while keeping Tracks, History, and Imports always visible below.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final filter in LibraryFilter.values)
                GlassPill(
                  label: filter.label,
                  selected: controller.libraryFilter == filter,
                  onTap: () => controller.setLibraryFilter(filter),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final sort in LibrarySort.values)
                GlassPill(
                  label: 'Sort ${sort.label}',
                  selected: controller.librarySort == sort,
                  onTap: () => controller.setLibrarySort(sort),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusedViewSection extends StatelessWidget {
  const _FocusedViewSection({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final focusedTracks = controller.filteredLibraryTracks;
    final focusedCollections = controller.filteredLibraryCollections;

    return SectionCard(
      title: 'Focused View',
      subtitle:
          'This area reacts to the selected filter, while the core library blocks stay fixed below.',
      trailing: GlassPill(label: controller.libraryFilter.label),
      child: focusedTracks.isEmpty && focusedCollections.isEmpty
          ? const _LibraryPlaceholder(
              message:
                  'Nothing matches the current filter yet. Try another view or import more files.',
            )
          : Column(
              children: [
                if (focusedCollections.isNotEmpty) ...[
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final collection in focusedCollections.take(6))
                        _CollectionPeekCard(collection: collection),
                    ],
                  ),
                  if (focusedTracks.isNotEmpty) const SizedBox(height: 18),
                ],
                if (focusedTracks.isNotEmpty)
                  Column(
                    children: [
                      for (
                        var index = 0;
                        index < focusedTracks.length && index < 6;
                        index++
                      ) ...[
                        TrackRow(
                          track: focusedTracks[index],
                          onTap: () =>
                              _openTrack(controller, focusedTracks[index]),
                          trailing: _LibraryTrackActions(
                            track: focusedTracks[index],
                          ),
                        ),
                        if (index != focusedTracks.length - 1 && index != 5)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
              ],
            ),
    );
  }
}

class _TracksSection extends StatelessWidget {
  const _TracksSection({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final tracks = _sortTracks(
      controller.importedTracks,
      controller.librarySort,
    ).take(8).toList(growable: false);

    return SectionCard(
      title: 'Tracks',
      subtitle:
          'Your local source files, ready for playback, relinking, or cleanup.',
      child: Column(
        children: [
          for (var index = 0; index < tracks.length; index++) ...[
            TrackRow(
              track: tracks[index],
              onTap: () => _openTrack(controller, tracks[index]),
              trailing: _LibraryTrackActions(track: tracks[index]),
            ),
            if (index != tracks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AlbumsAndArtistsSection extends StatelessWidget {
  const _AlbumsAndArtistsSection({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final albums = controller.albumCollections.take(4).toList(growable: false);
    final artists = controller.artistCollections
        .take(4)
        .toList(growable: false);
    final wide = isWideWidth(context);

    return SectionCard(
      title: 'Albums / Artists',
      subtitle:
          'Generated directly from imported metadata and folder structure.',
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CollectionColumn(
                    title: 'Albums',
                    collections: albums,
                    emptyMessage: 'Albums appear after import.',
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _CollectionColumn(
                    title: 'Artists',
                    collections: artists,
                    emptyMessage: 'Artists appear after import.',
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _CollectionColumn(
                  title: 'Albums',
                  collections: albums,
                  emptyMessage: 'Albums appear after import.',
                ),
                const SizedBox(height: 18),
                _CollectionColumn(
                  title: 'Artists',
                  collections: artists,
                  emptyMessage: 'Artists appear after import.',
                ),
              ],
            ),
    );
  }
}

class _CollectionColumn extends StatelessWidget {
  const _CollectionColumn({
    required this.title,
    required this.collections,
    required this.emptyMessage,
  });

  final String title;
  final List<MusicCollection> collections;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        if (collections.isEmpty)
          _LibraryPlaceholder(message: emptyMessage)
        else
          Column(
            children: [
              for (var index = 0; index < collections.length; index++) ...[
                _CollectionRow(collection: collections[index]),
                if (index != collections.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final resume = controller.resumeTracks.take(4).toList(growable: false);
    final mostPlayed = controller.mostPlayedTracks
        .take(4)
        .toList(growable: false);
    final groups = controller.recentSessionGroups
        .take(3)
        .toList(growable: false);
    final tracksById = {
      for (final track in controller.importedTracks) track.id: track,
    };

    return SectionCard(
      title: 'History',
      subtitle:
          'Recent Sessions, Resume, and Most Played all come from the same persistent playback record.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            const _LibraryPlaceholder(
              message: 'Recent sessions appear after playback starts.',
            )
          else
            Column(
              children: [
                for (var index = 0; index < groups.length; index++) ...[
                  _HistoryDayBlock(
                    day: groups[index].day,
                    events: groups[index].events,
                    tracksById: tracksById,
                  ),
                  if (index != groups.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
          const SizedBox(height: 22),
          Text('Resume', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (resume.isEmpty)
            const _LibraryPlaceholder(
              message: 'Tracks with saved positions will appear here.',
            )
          else
            Column(
              children: [
                for (var index = 0; index < resume.length; index++) ...[
                  TrackRow(
                    track: resume[index],
                    onTap: () {
                      controller.resumeTrack(
                        resume[index],
                        collection: controller.collectionForTrack(
                          resume[index],
                        ),
                      );
                    },
                    trailing: _ResumeTrackActions(track: resume[index]),
                  ),
                  if (index != resume.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          const SizedBox(height: 22),
          Text('Most Played', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (mostPlayed.isEmpty)
            const _LibraryPlaceholder(
              message: 'Most-played rankings appear after a little listening.',
            )
          else
            Column(
              children: [
                for (var index = 0; index < mostPlayed.length; index++) ...[
                  TrackRow(
                    track: mostPlayed[index],
                    onTap: () => _openTrack(controller, mostPlayed[index]),
                    trailing: _MostPlayedTrackActions(track: mostPlayed[index]),
                  ),
                  if (index != mostPlayed.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentImportsSection extends StatelessWidget {
  const _RecentImportsSection({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final tracks = controller.recentImportedTracks
        .take(6)
        .toList(growable: false);

    return SectionCard(
      title: 'Imported Recently',
      subtitle:
          'The newest local files you brought into ChiMusic, including those not played yet.',
      child: Column(
        children: [
          for (var index = 0; index < tracks.length; index++) ...[
            TrackRow(
              track: tracks[index],
              onTap: () => _openTrack(controller, tracks[index]),
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GlassPill(
                    label: formatRelativePlayTime(tracks[index].importedAt),
                  ),
                  if (!tracks[index].isAvailable)
                    const GlassPill(label: 'Unavailable'),
                ],
              ),
            ),
            if (index != tracks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CollectionPeekCard extends StatelessWidget {
  const _CollectionPeekCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isWideWidth(context) ? 250 : double.infinity,
      child: GlassPanel(
        onTap: () =>
            Navigator.of(context).push(CollectionDetailPage.route(collection)),
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(28),
        tintColors: [
          collection.palette.first.withValues(alpha: 0.24),
          LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
        ],
        withShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              artworkUri: collection.artworkUri,
              size: 96,
              showTitle: true,
              icon: collection.kind == MusicCollectionKind.folder
                  ? Icons.folder_rounded
                  : Icons.queue_music_rounded,
            ),
            const SizedBox(height: 14),
            Text(
              collection.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              collection.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return GlassPanel(
      onTap: () =>
          Navigator.of(context).push(CollectionDetailPage.route(collection)),
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
            title: collection.title,
            palette: collection.palette,
            artworkUri: collection.artworkUri,
            size: 60,
            borderRadius: BorderRadius.circular(16),
            showTitle: true,
            icon: collection.kind == MusicCollectionKind.folder
                ? Icons.folder_rounded
                : Icons.queue_music_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  collection.subtitle,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassPill(label: collection.kind.label),
              GlassPill(
                label: controller.isCollectionSaved(collection.id)
                    ? 'Saved'
                    : 'Save',
                onTap: () => controller.toggleSavedCollection(collection.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryDayBlock extends StatelessWidget {
  const _HistoryDayBlock({
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
        LiquidPalette.surfaceSoft.withValues(alpha: 0.68),
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
                label: '${events.length} event${events.length == 1 ? '' : 's'}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < events.length && index < 3; index++) ...[
            Builder(
              builder: (context) {
                final event = events[index];
                final track = tracksById[event.trackId];
                if (track == null) {
                  return const SizedBox.shrink();
                }
                return TrackRow(
                  track: track,
                  onTap: () => _openTrack(controller, track),
                  trailing: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GlassPill(
                        label: _playbackEndReasonLabel(event.endReason),
                      ),
                      GlassPill(label: formatDuration(event.maxPosition)),
                    ],
                  ),
                );
              },
            ),
            if (index != events.length - 1 && index != 2)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ResumeTrackActions extends StatelessWidget {
  const _ResumeTrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GlassPill(label: formatDuration(entry?.lastPosition)),
        GlassPill(
          label: entry == null
              ? 'Resume'
              : 'Played ${formatRelativePlayTime(entry.lastPlayedAt)}',
        ),
      ],
    );
  }
}

class _MostPlayedTrackActions extends StatelessWidget {
  const _MostPlayedTrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GlassPill(
          label:
              '${entry?.playCount ?? 0} play${entry?.playCount == 1 ? '' : 's'}',
        ),
        if (entry != null)
          GlassPill(label: formatDuration(entry.totalListened)),
      ],
    );
  }
}

class _LibraryTrackActions extends StatelessWidget {
  const _LibraryTrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    if (!track.isAvailable) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const GlassPill(label: 'Unavailable'),
          GlassPill(
            label: 'Re-link',
            onTap: () => controller.relinkTrack(track),
          ),
          GlassPill(
            label: 'Remove',
            onTap: () => controller.removeTrackFromLibrary(track.id),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (track.genre case final genre?) GlassPill(label: genre),
        GlassPill(
          label: controller.isTrackLiked(track.id) ? 'Liked' : 'Like',
          onTap: () => controller.toggleLikedTrack(track.id),
        ),
      ],
    );
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder({required this.message});

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

void _openTrack(MusicAppController controller, Track track) {
  if (!track.isAvailable) {
    controller.relinkTrack(track);
    return;
  }

  final entry = controller.playbackHistoryEntryForTrack(track.id);
  final collection = controller.collectionForTrack(track);
  if (entry != null && entry.lastPosition > Duration.zero) {
    controller.resumeTrack(track, collection: collection);
    return;
  }

  controller.playTrack(track, collection: collection);
}

List<Track> _sortTracks(List<Track> tracks, LibrarySort sort) {
  final sorted = List<Track>.from(tracks);
  switch (sort) {
    case LibrarySort.recent:
      sorted.sort((a, b) => b.importedAt.compareTo(a.importedAt));
      break;
    case LibrarySort.title:
      sorted.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      break;
    case LibrarySort.length:
      sorted.sort(
        (a, b) => (b.duration ?? Duration.zero).compareTo(
          a.duration ?? Duration.zero,
        ),
      );
      break;
  }
  return sorted;
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
