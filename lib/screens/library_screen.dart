import 'package:flutter/material.dart';

import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
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
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'All imported local files live here, grouped into playable folders and tracked through the real audio queue.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 20),
              ImportMusicActions(controller: controller),
              const SizedBox(height: 18),
              if (controller.statusMessage != null) ...[
                StatusBanner(message: controller.statusMessage!),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                EmptyMusicState(
                  title: 'Your library is empty',
                  body:
                      'Import audio files or a whole folder to replace the old mock catalog with real tracks from your device.',
                  controller: controller,
                )
              else ...[
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
                const SizedBox(height: 22),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _StatCard(
                          icon: Icons.music_note_rounded,
                          title: 'Imported Files',
                          body:
                              '${controller.importedTrackCount} tracks are available in this session.',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.folder_rounded,
                          title: 'Folders',
                          body:
                              '${controller.collectionCount} grouped collections were derived from your file structure.',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.favorite_rounded,
                          title: 'Favorites',
                          body:
                              '${controller.likedTracksCount} locally liked tracks are pinned for quick access.',
                        ),
                      ),
                    ],
                  )
                else ...[
                  _StatCard(
                    icon: Icons.music_note_rounded,
                    title: 'Imported Files',
                    body:
                        '${controller.importedTrackCount} tracks are available in this session.',
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    icon: Icons.folder_rounded,
                    title: 'Folders',
                    body:
                        '${controller.collectionCount} grouped collections were derived from your file structure.',
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    icon: Icons.favorite_rounded,
                    title: 'Favorites',
                    body:
                        '${controller.likedTracksCount} locally liked tracks are pinned for quick access.',
                  ),
                ],
                if (controller.filteredLibraryCollections.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionHeader(
                    title: 'Folders',
                    subtitle:
                        'Open a folder collection or play it as one queue',
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
                        ? 'Favorite Tracks'
                        : 'Tracks',
                    subtitle:
                        'Real local audio files, ready for direct playback',
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
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatDuration(
                                  controller
                                      .filteredLibraryTracks[index]
                                      .duration,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.68,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                controller
                                    .filteredLibraryTracks[index]
                                    .typeLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.50,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (index !=
                            controller.filteredLibraryTracks.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.66),
            ),
          ),
        ],
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
                    '${collection.kind.label} • ${collection.tracks.length} files',
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
                onTap: () {
                  controller.playCollection(collection);
                },
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
