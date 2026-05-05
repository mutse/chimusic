import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';

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
                'Saved collections, downloaded listening, and quick re-entry points into the queue.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 22),
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
                  children: const [
                    Expanded(flex: 2, child: _LikedSongsCard()),
                    SizedBox(width: 14),
                    Expanded(child: _DownloadCard()),
                  ],
                )
              else ...[
                const _LikedSongsCard(),
                const SizedBox(height: 14),
                const _DownloadCard(),
              ],
              const SizedBox(height: 28),
              SectionHeader(
                title: 'Saved Collections',
                subtitle:
                    '${controller.filteredLibraryCollections.length} visible • ${controller.savedCollections.length} total saved',
              ),
              const SizedBox(height: 16),
              if (controller.filteredLibraryCollections.isEmpty)
                GlassPanel(
                  child: Text(
                    'No collections match the current filter yet.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                )
              else
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
          ),
        ),
      ),
    );
  }
}

class _LikedSongsCard extends StatelessWidget {
  const _LikedSongsCard();

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      padding: const EdgeInsets.all(22),
      tintColors: [
        LiquidPalette.aqua.withValues(alpha: 0.30),
        LiquidPalette.deepCyan.withValues(alpha: 0.12),
      ],
      child: Row(
        children: [
          ArtworkCover(
            title: 'Liked Songs',
            palette: const [
              Color(0xFF86F0FF),
              Color(0xFF376EFF),
              Color(0xFF101C4A),
            ],
            size: 110,
            showTitle: true,
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liked Songs',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.likedTracksCount} saved tracks ready to play from any screen.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  onTap: controller.togglePlayPause,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  tintColors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  withShadow: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        controller.isPlaying
                            ? 'Pause current'
                            : 'Resume current',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
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

class _DownloadCard extends StatelessWidget {
  const _DownloadCard();

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPill(
            label: 'Offline Ready',
            leading: Icon(
              Icons.download_done_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${controller.downloadedCollectionCount} downloaded collections',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'For the MVP these are local mock states, but the flow is already shaped for real offline status.',
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
                    '${collection.kind.label} • ${collection.tracks.length} tracks',
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
