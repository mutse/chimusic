import 'package:flutter/material.dart';

import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
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
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 24),
              if (controller.statusMessage != null) ...[
                StatusBanner(message: controller.statusMessage!),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                EmptyMusicState(
                  title: 'Import local music to begin',
                  body:
                      'Choose audio files from your device and ChiMusic will turn them into a playable local library with real queueing and playback.',
                  controller: controller,
                  icon: Icons.audio_file_rounded,
                )
              else
                _LibraryOverview(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local music',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Bring your own audio files into ChiMusic, browse them as a native library, and play them through a real queue instead of mock data.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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

class _LibraryOverview extends StatelessWidget {
  const _LibraryOverview({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final wide = isWideWidth(context);
    final featured = controller.featuredCollection as MusicCollection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _LibraryHero(collection: featured)),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _StatsPanel(controller: controller)),
            ],
          )
        else ...[
          _LibraryHero(collection: featured),
          const SizedBox(height: 18),
          _StatsPanel(controller: controller),
        ],
        const SizedBox(height: 30),
        SectionHeader(
          title: 'Recently Played',
          subtitle: controller.recentPlayedTracks.isEmpty
              ? 'Tap any imported file to start the first playback session.'
              : 'Jump back into the tracks you opened most recently.',
        ),
        const SizedBox(height: 16),
        if (controller.recentPlayedTracks.isEmpty)
          const _PlaceholderPanel(message: 'No playback history yet.')
        else
          Column(
            children: [
              for (
                var index = 0;
                index < controller.recentPlayedTracks.length;
                index++
              ) ...[
                TrackRow(
                  track: controller.recentPlayedTracks[index],
                  onTap: () {
                    controller.playTrack(
                      controller.recentPlayedTracks[index],
                      collection: controller.collectionForTrack(
                        controller.recentPlayedTracks[index],
                      ),
                    );
                  },
                  trailing: Text(
                    formatDuration(
                      controller.recentPlayedTracks[index].duration,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                ),
                if (index != controller.recentPlayedTracks.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        const SizedBox(height: 30),
        const SectionHeader(
          title: 'Latest Imports',
          subtitle: 'Freshly added files in your current local session',
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            for (
              var index = 0;
              index < controller.recentImportedTracks.length;
              index++
            ) ...[
              TrackRow(
                track: controller.recentImportedTracks[index],
                onTap: () {
                  controller.playTrack(
                    controller.recentImportedTracks[index],
                    collection: controller.collectionForTrack(
                      controller.recentImportedTracks[index],
                    ),
                  );
                },
                trailing: Text(
                  formatDuration(
                    controller.recentImportedTracks[index].duration,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ),
              if (index != controller.recentImportedTracks.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
        const SizedBox(height: 30),
        const SectionHeader(
          title: 'Folders',
          subtitle: 'Grouped from the folders your imported files came from',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 286,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.importedCollections.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final collection = controller.importedCollections[index];
              return _FolderCard(collection: collection);
            },
          ),
        ),
      ],
    );
  }
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        collection.palette.first.withValues(alpha: 0.24),
        collection.palette.last.withValues(alpha: 0.10),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: collection.kind.label),
              GlassPill(label: '${collection.tracks.length} files'),
              GlassPill(label: '${controller.collectionCount} folders'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtworkCover(
                title: collection.title,
                palette: collection.palette,
                size: isWideWidth(context) ? 184 : 140,
                showTitle: true,
                icon: Icons.queue_music_rounded,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Tracks',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A real local library built from imported files',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${controller.importedTrackCount} tracks are ready to play. Start the full queue or jump into a folder-specific detail view.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () {
                    controller.playCollection(collection);
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  tintColors: [
                    collection.palette.first.withValues(alpha: 0.54),
                    collection.palette[1].withValues(alpha: 0.22),
                  ],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'Play All',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.folder_open_rounded,
                onTap: () => Navigator.of(
                  context,
                ).push(CollectionDetailPage.route(collection)),
                size: 56,
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Import more files at any time. Folder imports are available on Android and macOS for quicker bulk loading.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 18),
          ImportMusicActions(controller: controller),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                label: 'Imported',
                value: '${controller.importedTrackCount} tracks',
              ),
              _StatChip(
                label: 'Folders',
                value: '${controller.collectionCount}',
              ),
              _StatChip(
                label: 'Favorites',
                value: '${controller.likedTracksCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return SizedBox(
      width: 220,
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
              size: 140,
              showTitle: true,
              icon: Icons.folder_rounded,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    collection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  controller.isCollectionSaved(collection.id)
                      ? Icons.bookmark_rounded
                      : Icons.folder_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        Colors.white.withValues(alpha: 0.12),
        Colors.white.withValues(alpha: 0.04),
      ],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({required this.message});

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
