import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                controller.hasMusic
                    ? 'Resume your queue, jump into saved folders, and keep your local music moving.'
                    : 'Build your own streaming-style home feed from local audio files.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
        if (isWideWidth(context))
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(
                label: '${controller.importedTrackCount} tracks',
                leading: const Icon(Icons.graphic_eq_rounded, size: 16),
              ),
              GlassPill(
                label: '${controller.collectionCount} folders',
                leading: const Icon(Icons.folder_rounded, size: 16),
              ),
            ],
          ),
      ],
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
      padding: const EdgeInsets.all(26),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        LiquidPalette.deepCyan.withValues(alpha: 0.98),
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
              GlassPill(label: 'Search'),
              GlassPill(label: 'Library'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Turn local files into a full music app experience.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Import audio once and ChiMusic will build a richer Home feed, live Search suggestions, and a Library that feels closer to a real streaming product.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All imported music stays on this device, and you can clear the in-app library at any time without deleting the original files.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.54),
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
          body: 'Recent plays and fresh imports surface automatically on Home.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.travel_explore_rounded,
          title: 'Search Discovery',
          body:
              'Browse artists, albums, folders, and quick suggestions from your own library.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.bookmark_rounded,
          title: 'Saved Library',
          body:
              'Pin folders, like tracks, and keep your best collections within reach.',
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
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LiquidPalette.aqua.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: LiquidPalette.mint),
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
                    color: Colors.white.withValues(alpha: 0.66),
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
    final featured = controller.featuredCollection;
    final wide = isWideWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured != null)
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _FeaturedCollectionHero(collection: featured),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 2,
                  child: _SessionSnapshot(controller: controller),
                ),
              ],
            )
          else ...[
            _FeaturedCollectionHero(collection: featured),
            const SizedBox(height: 18),
            _SessionSnapshot(controller: controller),
          ],
        const SizedBox(height: 30),
        const SectionHeader(
          title: 'Quick Access',
          subtitle: 'Jump into the areas you are most likely to use next',
        ),
        const SizedBox(height: 16),
        _QuickAccessGrid(controller: controller),
        const SizedBox(height: 30),
        SectionHeader(
          title: 'Continue Listening',
          subtitle: controller.recentPlayedTracks.isEmpty
              ? 'Fresh imports ready for their first play'
              : 'Pick up where you left off across your local queue',
        ),
        const SizedBox(height: 16),
        _ListeningGrid(controller: controller),
        const SizedBox(height: 30),
        const SectionHeader(
          title: 'Made For This Library',
          subtitle:
              'Pinned folders, recent mixes, and collections worth keeping close',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 286,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.spotlightCollections.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => _CollectionCard(
              collection: controller.spotlightCollections[index],
            ),
          ),
        ),
        const SizedBox(height: 30),
        const SectionHeader(
          title: 'Fresh Finds',
          subtitle:
              'Your strongest signals right now: liked songs, recents, and newly imported tracks',
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            for (
              var index = 0;
              index < controller.spotlightTracks.length;
              index++
            ) ...[
              TrackRow(
                track: controller.spotlightTracks[index],
                onTap: () {
                  controller.playTrack(
                    controller.spotlightTracks[index],
                    collection: controller.collectionForTrack(
                      controller.spotlightTracks[index],
                    ),
                  );
                },
                trailing: _TrackActions(
                  track: controller.spotlightTracks[index],
                ),
              ),
              if (index != controller.spotlightTracks.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _FeaturedCollectionHero extends StatelessWidget {
  const _FeaturedCollectionHero({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      padding: const EdgeInsets.all(26),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        collection.palette.first.withValues(alpha: 0.38),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.95),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: collection.kind.label),
              GlassPill(label: '${collection.tracks.length} tracks'),
              GlassPill(label: formatRuntime(collection.totalDuration)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtworkCover(
                title: collection.title,
                palette: collection.palette,
                size: isWideWidth(context) ? 184 : 142,
                showTitle: true,
                icon: Icons.graphic_eq_rounded,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      collection.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GlassPanel(
                            onTap: () => controller.playCollection(collection),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            tintColors: [
                              LiquidPalette.aqua.withValues(alpha: 0.95),
                              LiquidPalette.mint.withValues(alpha: 0.72),
                            ],
                            borderColor: LiquidPalette.mint.withValues(
                              alpha: 0.30,
                            ),
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
                                  'Play Collection',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: LiquidPalette.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GlassIconButton(
                          icon: controller.isCollectionSaved(collection.id)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          selected: controller.isCollectionSaved(collection.id),
                          onTap: () =>
                              controller.toggleSavedCollection(collection.id),
                          size: 56,
                          iconSize: 24,
                        ),
                        const SizedBox(width: 12),
                        GlassIconButton(
                          icon: Icons.arrow_forward_rounded,
                          onTap: () => Navigator.of(
                            context,
                          ).push(CollectionDetailPage.route(collection)),
                          size: 56,
                          iconSize: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionSnapshot extends StatelessWidget {
  const _SessionSnapshot({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Snapshot',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Keep building this local catalog. New imports immediately feed Home, Search, and Library.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 18),
          const _SnapshotStatRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Imported Tracks',
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.importedTrackCount}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          const _SnapshotStatRow(
            icon: Icons.favorite_rounded,
            title: 'Liked Songs',
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.likedTracksCount}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          ImportMusicActions(controller: controller),
        ],
      ),
    );
  }
}

class _SnapshotStatRow extends StatelessWidget {
  const _SnapshotStatRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.74)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.54),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAccessItem>[
      _QuickAccessItem(
        title: 'Liked Songs',
        subtitle: '${controller.likedTracksCount} saved favorites',
        icon: Icons.favorite_rounded,
        accent: const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
        onTap: () => controller.openLibraryFilter(LibraryFilter.favorites),
      ),
      _QuickAccessItem(
        title: 'Folders',
        subtitle: '${controller.collectionCount} collection views',
        icon: Icons.folder_copy_rounded,
        accent: const [Color(0xFF153C2A), Color(0xFF1ED760)],
        onTap: () => controller.openLibraryFilter(LibraryFilter.folders),
      ),
      _QuickAccessItem(
        title: 'Search',
        subtitle: 'Find artists, albums, or file types',
        icon: Icons.search_rounded,
        accent: const [Color(0xFF10233E), Color(0xFF4B7BFF)],
        onTap: controller.openSearch,
      ),
      _QuickAccessItem(
        title: 'Play All',
        subtitle: '${controller.importedTrackCount} tracks in one queue',
        icon: Icons.play_circle_fill_rounded,
        accent: const [Color(0xFF3A280F), Color(0xFFF4A259)],
        onTap: () {
          controller.togglePlayPause();
        },
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final item in items)
          SizedBox(
            width: isWideWidth(context) ? 280 : double.infinity,
            child: _QuickAccessCard(item: item),
          ),
      ],
    );
  }
}

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> accent;
  final VoidCallback onTap;
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.item});

  final _QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: item.onTap,
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        item.accent.first.withValues(alpha: 0.92),
        item.accent.last.withValues(alpha: 0.36),
      ],
      borderColor: item.accent.last.withValues(alpha: 0.24),
      withShadow: false,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
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

class _ListeningGrid extends StatelessWidget {
  const _ListeningGrid({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final track in controller.continueListeningTracks)
          SizedBox(
            width: isWideWidth(context) ? 350 : double.infinity,
            child: _ListeningCard(track: track),
          ),
      ],
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final collection = controller.collectionForTrack(track);

    return GlassPanel(
      onTap: () => controller.playTrack(track, collection: collection),
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(24),
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            size: 74,
            borderRadius: BorderRadius.circular(20),
            showTitle: true,
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  collection?.title ?? track.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GlassIconButton(
            icon: controller.isTrackLiked(track.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            selected: controller.isTrackLiked(track.id),
            onTap: () => controller.toggleLikedTrack(track.id),
            size: 46,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

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
              icon: Icons.queue_music_rounded,
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
                  color: Colors.white.withValues(alpha: 0.66),
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
            const Spacer(),
            Text(
              formatRuntime(collection.totalDuration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackActions extends StatelessWidget {
  const _TrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatDuration(track.duration),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.56),
          ),
        ),
        const SizedBox(width: 10),
        GlassIconButton(
          icon: controller.isTrackLiked(track.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          selected: controller.isTrackLiked(track.id),
          onTap: () => controller.toggleLikedTrack(track.id),
          size: 40,
          iconSize: 18,
        ),
      ],
    );
  }
}
