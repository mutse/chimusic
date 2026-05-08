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
                                label:
                                    '${controller.importedTrackCount} tracks',
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
                          _LikedSongsCard(controller: controller),
                          const SizedBox(height: 18),
                          _ImportedAudioCard(controller: controller),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _LibrarySummary(controller: controller),
                const SizedBox(height: 18),
                _LikedSongsCard(controller: controller),
                const SizedBox(height: 18),
                _ImportedAudioCard(controller: controller),
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
                      'Import audio files or folders to populate saved collections, liked tracks, and playback-ready queues.',
                  controller: controller,
                )
              else ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Filters',
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
                    title: 'Pinned Collections',
                    child: SizedBox(
                      height: 286,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.pinnedCollections.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) => _PinnedCollectionCard(
                          collection: controller.pinnedCollections[index],
                        ),
                      ),
                    ),
                  ),
                ],
                if (controller.filteredLibraryCollections.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: controller.libraryFilter == LibraryFilter.favorites
                        ? 'Saved Collections'
                        : 'Collections',
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
                  onTap: () =>
                      controller.openLibraryFilter(LibraryFilter.tracks),
                  accent: const [Color(0xFF153C2A), Color(0xFF1ED760)],
                ),
                MetricGlassCard(
                  value: '${controller.collectionCount}',
                  label: 'Folders',
                  icon: Icons.folder_rounded,
                  onTap: () =>
                      controller.openLibraryFilter(LibraryFilter.folders),
                  accent: const [Color(0xFF3A280F), Color(0xFFF4A259)],
                ),
                MetricGlassCard(
                  value: '${controller.artistCount}',
                  label: 'Artists',
                  icon: Icons.person_rounded,
                  accent: const [Color(0xFF10233E), Color(0xFF4B7BFF)],
                ),
                MetricGlassCard(
                  value: '${controller.savedCollectionCount}',
                  label: 'Saved',
                  icon: Icons.bookmark_rounded,
                  onTap: () =>
                      controller.openLibraryFilter(LibraryFilter.favorites),
                  accent: const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () {
                    controller.playImportedTracks();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.95),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.24),
                  withShadow: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: LiquidPalette.ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Play Imported',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: LiquidPalette.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.favorite_rounded,
                onTap: () =>
                    controller.openLibraryFilter(LibraryFilter.favorites),
                size: 52,
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ImportMusicActions(controller: controller),
        ],
      ),
    );
  }
}

class _LikedSongsCard extends StatelessWidget {
  const _LikedSongsCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        const Color(0xFF3B1E3A).withValues(alpha: 0.78),
        const Color(0xFF8B5CF6).withValues(alpha: 0.18),
      ],
      borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.favorite_rounded),
          ),
          const SizedBox(height: 18),
          Text(
            'Liked Songs',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.likedTracksCount} tracks',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: controller.likedTracksCount == 0
                      ? null
                      : () {
                          controller.playFavoriteTracks();
                        },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.95),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.24),
                  withShadow: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: LiquidPalette.ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Play Likes',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: LiquidPalette.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.arrow_forward_rounded,
                onTap: () =>
                    controller.openLibraryFilter(LibraryFilter.favorites),
                size: 52,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportedAudioCard extends StatelessWidget {
  const _ImportedAudioCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        const Color(0xFF10233E).withValues(alpha: 0.76),
        const Color(0xFF4B7BFF).withValues(alpha: 0.16),
      ],
      borderColor: const Color(0xFF4B7BFF).withValues(alpha: 0.10),
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.audio_file_rounded),
          ),
          const SizedBox(height: 18),
          Text(
            'Imported Audio',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.importedTrackCount} tracks • ${controller.albumCount} albums',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () {
                    controller.playImportedTracks();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.95),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.24),
                  withShadow: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: LiquidPalette.ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Play All',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: LiquidPalette.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.library_music_rounded,
                onTap: () => controller.openLibraryFilter(LibraryFilter.tracks),
                size: 52,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinnedCollectionCard extends StatelessWidget {
  const _PinnedCollectionCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return SizedBox(
      width: 228,
      child: GlassPanel(
        onTap: () =>
            Navigator.of(context).push(CollectionDetailPage.route(collection)),
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              size: 144,
              showTitle: true,
              icon: Icons.folder_special_rounded,
            ),
            const SizedBox(height: 14),
            Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              collection.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.64),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatRuntime(collection.totalDuration),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
                ),
                Icon(
                  controller.isCollectionSaved(collection.id)
                      ? Icons.bookmark_rounded
                      : Icons.folder_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.60),
                ),
              ],
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
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(CollectionDetailPage.route(collection)),
            child: ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              size: 88,
              showTitle: true,
              icon: Icons.folder_rounded,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(CollectionDetailPage.route(collection)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${collection.kind.label} • ${collection.tracks.length} tracks • ${formatRuntime(collection.totalDuration)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collection.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.56),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              GlassIconButton(
                icon: Icons.play_arrow_rounded,
                onTap: () => controller.playCollection(collection),
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(height: 8),
              GlassIconButton(
                icon: controller.isCollectionSaved(collection.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: () => controller.toggleSavedCollection(collection.id),
                selected: controller.isCollectionSaved(collection.id),
                size: 48,
                iconSize: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryTrackActions extends StatelessWidget {
  const _LibraryTrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          formatDuration(track.duration),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 6),
        GlassIconButton(
          icon: controller.isTrackLiked(track.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          onTap: () => controller.toggleLikedTrack(track.id),
          selected: controller.isTrackLiked(track.id),
          size: 38,
          iconSize: 16,
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
    return GlassPanel(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}
