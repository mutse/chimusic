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
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              GlassPill(
                                label:
                                    '${controller.savedCollectionCount} saved',
                              ),
                              GlassPill(
                                label: '${controller.likedTracksCount} liked',
                              ),
                              GlassPill(
                                label: '${controller.albumCount} albums',
                              ),
                              GlassPill(
                                label: '${controller.playlistCount} playlists',
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
                      child: Column(
                        children: [
                          _AiStatusCard(controller: controller),
                          const SizedBox(height: 18),
                          _SyncStatusCard(controller: controller),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _LibrarySummary(controller: controller),
                const SizedBox(height: 18),
                _AiStatusCard(controller: controller),
                const SizedBox(height: 18),
                _SyncStatusCard(controller: controller),
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
                      'Import audio files or folders to populate albums, artists, playlists, favorites, and playback-ready queues.',
                  controller: controller,
                )
              else ...[
                SectionCard(
                  title: 'Filters',
                  subtitle:
                      'Switch between tracks, albums, artists, playlists, folders, and favorites without leaving the library.',
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
                ),
                if (controller.pinnedCollections.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: 'Quick Access',
                    subtitle:
                        'Pinned and frequently useful library entry points stay near the top.',
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final collection in controller.pinnedCollections)
                          _QuickCollectionCard(collection: collection),
                      ],
                    ),
                  ),
                ],
                if (controller.filteredLibraryCollections.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: _libraryCollectionTitle(controller.libraryFilter),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < controller.filteredLibraryCollections.length;
                          index++
                        ) ...[
                          _LibraryCollectionRow(
                            collection:
                                controller.filteredLibraryCollections[index],
                          ),
                          if (index !=
                              controller.filteredLibraryCollections.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
                if (controller.playbackHistoryTracks.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: 'Playback History',
                    subtitle:
                        'Every play is saved locally with last position and replay count.',
                    trailing: GlassPill(
                      label:
                          '${controller.playbackHistoryCount} track${controller.playbackHistoryCount == 1 ? '' : 's'}',
                    ),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < controller.playbackHistoryTracks.length;
                          index++
                        ) ...[
                          TrackRow(
                            track: controller.playbackHistoryTracks[index],
                            onTap: () {
                              controller.playTrack(
                                controller.playbackHistoryTracks[index],
                                collection: controller.collectionForTrack(
                                  controller.playbackHistoryTracks[index],
                                ),
                              );
                            },
                            trailing: _PlaybackHistoryTrackActions(
                              track: controller.playbackHistoryTracks[index],
                            ),
                          ),
                          if (index !=
                              controller.playbackHistoryTracks.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
                if (controller.filteredLibraryTracks.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: controller.libraryFilter == LibraryFilter.favorites
                        ? 'Liked Tracks'
                        : 'Tracks',
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < controller.filteredLibraryTracks.length;
                          index++
                        ) ...[
                          TrackRow(
                            track: controller.filteredLibraryTracks[index],
                            onTap: () {
                              controller.playTrack(
                                controller.filteredLibraryTracks[index],
                                collection: controller.collectionForTrack(
                                  controller.filteredLibraryTracks[index],
                                ),
                              );
                            },
                            trailing: _LibraryTrackActions(
                              track: controller.filteredLibraryTracks[index],
                            ),
                          ),
                          if (index !=
                              controller.filteredLibraryTracks.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
                if (controller.filteredLibraryCollections.isEmpty &&
                    controller.filteredLibraryTracks.isEmpty) ...[
                  const SizedBox(height: 30),
                  const _LibraryPlaceholder(
                    message:
                        'Nothing matches the current filter yet. Try another filter or import more files.',
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _libraryCollectionTitle(LibraryFilter filter) {
    return switch (filter) {
      LibraryFilter.albums => 'Albums',
      LibraryFilter.artists => 'Artists',
      LibraryFilter.playlists => 'Playlists',
      LibraryFilter.folders => 'Folders',
      LibraryFilter.favorites => 'Saved Collections',
      LibraryFilter.all => 'Collections',
      LibraryFilter.tracks => 'Collections',
    };
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

class _AiStatusCard extends StatelessWidget {
  const _AiStatusCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(30),
      tintColors: const [Color(0xFF182F48), Color(0xFF214C76)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Layer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            controller.hasPro
                ? 'Unlimited AI search and smart organization are active.'
                : '${controller.aiSearchTrialsRemaining} free AI searches remain before the Pro paywall appears.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.syncState;
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(30),
      tintColors: const [Color(0xFF173440), Color(0xFF215262)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cloud Sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (state.lastSyncedAt != null) ...[
            const SizedBox(height: 10),
            GlassPill(
              label: 'Updated ${formatRelativePlayTime(state.lastSyncedAt!)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickCollectionCard extends StatelessWidget {
  const _QuickCollectionCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isWideWidth(context) ? 250 : double.infinity,
      child: GlassPanel(
        onTap: () {
          Navigator.of(context).push(CollectionDetailPage.route(collection));
        },
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
              size: 96,
              showTitle: true,
              icon: Icons.queue_music_rounded,
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

class _LibraryCollectionRow extends StatelessWidget {
  const _LibraryCollectionRow({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    return GlassPanel(
      onTap: () {
        Navigator.of(context).push(CollectionDetailPage.route(collection));
      },
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

class _PlaybackHistoryTrackActions extends StatelessWidget {
  const _PlaybackHistoryTrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GlassPill(label: '${entry?.playCount ?? 1} plays'),
        GlassPill(
          label: formatRelativePlayTime(entry?.lastPlayedAt ?? DateTime.now()),
        ),
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
