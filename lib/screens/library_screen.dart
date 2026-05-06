import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
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
              Text(
                'Your Library',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage saved folders, liked tracks, and the full collection built from your local file imports.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
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
                      child: _LikedSongsCard(controller: controller),
                    ),
                  ],
                )
              else ...[
                _LibrarySummary(controller: controller),
                const SizedBox(height: 18),
                _LikedSongsCard(controller: controller),
              ],
              const SizedBox(height: 18),
              if (controller.statusMessage != null) ...[
                StatusBanner(message: controller.statusMessage!),
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
                const SectionHeader(
                  title: 'Filters',
                  subtitle:
                      'Shape the library view around the content you want to manage right now',
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                if (controller.pinnedCollections.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const SectionHeader(
                    title: 'Pinned Collections',
                    subtitle:
                        'Saved folders and strong recent mixes that deserve one-tap access',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
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
                ],
                if (controller.filteredLibraryCollections.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionHeader(
                    title: controller.libraryFilter == LibraryFilter.favorites
                        ? 'Saved Collections'
                        : 'Collections',
                    subtitle:
                        'Open, save, and play folder-based queues from your imported library',
                  ),
                  const SizedBox(height: 16),
                  Column(
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
                ],
                if (controller.filteredLibraryTracks.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionHeader(
                    title: controller.libraryFilter == LibraryFilter.favorites
                        ? 'Liked Tracks'
                        : 'Tracks',
                    subtitle:
                        'Play, like, and revisit the files that define your current local catalog',
                  ),
                  const SizedBox(height: 16),
                  Column(
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
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.surface.withValues(alpha: 0.95),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: '${controller.importedTrackCount} tracks'),
              GlassPill(label: '${controller.collectionCount} folders'),
              GlassPill(label: '${controller.pinnedCollections.length} pinned'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Built from your own files',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'The library now behaves more like a real product surface: saved collections, filters, sorting, and playback entry points all live together.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
            ),
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
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        const Color(0xFF3B1E3A).withValues(alpha: 0.96),
        const Color(0xFF8B5CF6).withValues(alpha: 0.42),
      ],
      borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
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
            '${controller.likedTracksCount} tracks are currently favorited in this session.',
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
                    collection.description,
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
